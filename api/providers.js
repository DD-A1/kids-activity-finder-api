import express from "express";
import { db } from "../db/client.js";
import { authenticateToken } from "../middleware/authenticateToken.js";
import { requireRole } from "../middleware/requireRole.js";

export const providersRouter = express.Router();

providersRouter.use(authenticateToken);

const blankToNull = (value) => {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const readApplication = (body) => {
  const providerType = blankToNull(body.provider_type);
  const displayName = blankToNull(body.display_name);
  const description = blankToNull(body.description);
  const websiteUrl = blankToNull(body.website_url);
  const contactEmail = blankToNull(body.contact_email)?.toLowerCase() || null;
  const contactPhone = blankToNull(body.contact_phone);

  if (
    providerType !== "ORGANIZATION" &&
    providerType !== "INDEPENDENT_INSTRUCTOR"
  ) {
    return {
      error: "Provider type must be ORGANIZATION or INDEPENDENT_INSTRUCTOR.",
    };
  }

  if (!displayName) {
    return { error: "A display name is required." };
  }

  if (!contactEmail && !contactPhone) {
    return { error: "A public email or phone number is required." };
  }

  return {
    value: {
      providerType,
      displayName,
      description,
      websiteUrl,
      contactEmail,
      contactPhone,
    },
  };
};

providersRouter.get("/mine", async (req, res) => {
  try {
    const result = await db.query(
      `SELECT
         p.id,
         p.provider_type,
         p.display_name,
         p.description,
         p.website_url,
         p.approval_status,
         p.submitted_at,
         p.created_at,
         p.updated_at
       FROM providers p
       JOIN provider_memberships m ON m.provider_id = p.id
       WHERE m.user_id = $1
         AND m.membership_status = 'ACTIVE'
         AND m.revoked_at IS NULL
       ORDER BY p.created_at DESC`,
      [req.user.id],
    );

    return res.json({ providers: result.rows });
  } catch (error) {
    console.error("Provider list error:", error);
    return res.status(500).json({ error: "Unable to load provider applications." });
  }
});

providersRouter.post("/", async (req, res) => {
  const parsed = readApplication(req.body);
  if (parsed.error) {
    return res.status(400).json({ error: parsed.error });
  }

  const client = await db.connect();

  try {
    await client.query("BEGIN");

    const providerResult = await client.query(
      `INSERT INTO providers (
         provider_type,
         display_name,
         description,
         website_url,
         approval_status,
         contact_email,
         contact_phone
       )
       VALUES ($1, $2, $3, $4, 'PENDING', $5, $6)
       RETURNING
         id,
         provider_type,
         display_name,
         description,
         website_url,
         approval_status,
         contact_email,
         contact_phone,
         submitted_at,
         created_at,
         updated_at`,
      [
        parsed.value.providerType,
        parsed.value.displayName,
        parsed.value.description,
        parsed.value.websiteUrl,
        parsed.value.contactEmail,
        parsed.value.contactPhone,
      ],
    );

    const provider = providerResult.rows[0];

    await client.query(
      `INSERT INTO provider_memberships (
         provider_id,
         user_id,
         membership_role,
         membership_status,
         accepted_at
       )
       VALUES ($1, $2, 'OWNER', 'ACTIVE', CURRENT_TIMESTAMP)`,
      [provider.id, req.user.id],
    );

    await client.query("COMMIT");
    return res.status(201).json({ provider });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Provider application error:", error);
    return res.status(500).json({ error: "Unable to submit the provider application." });
  } finally {
    client.release();
  }
});

const rankOf = {
  parent: 0,
  provider: 1,
  moderator: 2,
  admin: 3,
  super_admin: 4,
};

export const loadRoles = async (userId) => {
  const result = await db.query(
    `SELECT role_code
     FROM user_roles
     WHERE user_id = $1
       AND revoked_at IS NULL`,
    [userId],
  );
  const roles = result.rows.map((row) => row.role_code);
  const rank = roles.reduce((highest, role) => Math.max(highest, rankOf[role] ?? 0), 0);
  return { roles, rank };
};

export const requireRank = (minimumRole) => async (req, res, next) => {
  try {
    const access = await loadRoles(req.user.id);
    if (access.rank < rankOf[minimumRole]) {
      return res.status(403).json({ error: "You do not have access to this task." });
    }
    req.access = access;
    return next();
  } catch (error) {
    console.error("Role check error:", error);
    return res.status(500).json({ error: "Unable to check access." });
  }
};

providersRouter.get("/access", async (req, res) => {
  try {
    const access = await loadRoles(req.user.id);
    return res.json({
      roles: access.roles,
      workspace: access.rank >= rankOf.moderator,
    });
  } catch (error) {
    console.error("Admin access check error:", error);
    return res.status(500).json({ error: "Unable to check admin access." });
  }
});

providersRouter.get("/pending", requireRank("admin"), async (req, res) => {
  try {
    const result = await db.query(
      `SELECT
         id,
         provider_type,
         display_name,
         description,
         website_url,
         approval_status,
         contact_email,
         contact_phone,
         submitted_at
       FROM providers
       WHERE approval_status = 'PENDING'
       ORDER BY submitted_at`,
    );

    return res.json({ providers: result.rows });
  } catch (error) {
    console.error("Pending provider list error:", error);
    return res.status(500).json({ error: "Unable to load pending applications." });
  }
});

providersRouter.patch("/:id/review", requireRank("admin"), async (req, res) => {
  const status = blankToNull(req.body.approval_status);
  if (status !== "APPROVED" && status !== "REJECTED") {
    return res.status(400).json({ error: "Status must be APPROVED or REJECTED." });
  }

  const client = await db.connect();

  try {
    await client.query("BEGIN");

    const updated = await client.query(
      `UPDATE providers
       SET approval_status = $1,
           reviewed_at = CURRENT_TIMESTAMP,
           reviewed_by_user_id = $2
       WHERE id = $3
         AND approval_status = 'PENDING'
       RETURNING id, display_name, approval_status, reviewed_at`,
      [status, req.user.id, req.params.id],
    );

    if (updated.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Pending application not found." });
    }

    if (status === "APPROVED") {
      await client.query(
        `INSERT INTO user_roles (user_id, role_code)
         SELECT m.user_id, 'provider'
         FROM provider_memberships m
         WHERE m.provider_id = $1
           AND m.membership_role = 'OWNER'
           AND m.membership_status = 'ACTIVE'
           AND m.revoked_at IS NULL
           AND NOT EXISTS (
             SELECT 1
             FROM user_roles ur
             WHERE ur.user_id = m.user_id
               AND ur.role_code = 'provider'
               AND ur.revoked_at IS NULL
           )`,
        [req.params.id],
      );
    }

    await client.query("COMMIT");
    return res.json({ provider: updated.rows[0] });
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Provider review error:", error);
    return res.status(500).json({ error: "Unable to review the application." });
  } finally {
    client.release();
  }
});

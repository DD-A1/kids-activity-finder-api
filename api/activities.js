import express from "express";
import { db } from "../db/client.js";
import { authenticateToken } from "../middleware/authenticateToken.js";
import { requireRank } from "./providers.js";

export const activitiesRouter = express.Router();
activitiesRouter.use(authenticateToken);

const establishedCategories = [
  ["SPORTS", "Sports"],
  ["EDUCATION", "Education"],
  ["ARTS_AND_CRAFTS", "Arts and Crafts"],
  ["MUSIC", "Music"],
  ["RECREATION", "Recreation"],
  ["READING_AND_LITERACY", "Reading and Literacy"],
  ["STEM_AND_TECHNOLOGY", "STEM and Technology"],
];

const ensureCategories = async () => {
  for (const [code, name] of establishedCategories) {
    await db.query(
      `INSERT INTO activity_categories (category_code, category_name, display_order)
       VALUES ($1, $2, $3)
       ON CONFLICT (category_code) DO NOTHING`,
      [code, name, establishedCategories.findIndex((item) => item[0] === code)],
    );
  }
};

activitiesRouter.get("/categories", async (req, res) => {
  try {
    await ensureCategories();
    const result = await db.query(
      `SELECT id, category_code, category_name
       FROM activity_categories
       WHERE is_active = TRUE
       ORDER BY display_order, category_name`,
    );
    return res.json({ categories: result.rows });
  } catch (error) {
    console.error("Category list error:", error);
    return res.status(500).json({ error: "Unable to load categories." });
  }
});

activitiesRouter.get("/published", async (req, res) => {
  const categoryId = req.query.category_id ? Number(req.query.category_id) : null;
  if (req.query.category_id && (!Number.isInteger(categoryId) || categoryId <= 0)) {
    return res.status(400).json({ error: "Choose a category." });
  }

  const ageMonths = req.query.age_months === undefined || req.query.age_months === ""
    ? null
    : Number(req.query.age_months);
  if (ageMonths !== null && (!Number.isInteger(ageMonths) || ageMonths < 0)) {
    return res.status(400).json({ error: "Age must be a whole number of months." });
  }

  const location = String(req.query.location || "").trim();

  try {
    const result = await db.query(
      `SELECT ${activityColumns}
       FROM activities
       WHERE publication_status = 'PUBLISHED'
         AND (
           $1::bigint IS NULL
           OR id IN (
             SELECT activity_id
             FROM activity_category_links
             WHERE category_id = $1
           )
         )
         AND (
           $2::int IS NULL
           OR (
             (minimum_age_months IS NULL OR minimum_age_months <= $2)
             AND (maximum_age_months IS NULL OR maximum_age_months >= $2)
           )
         )
         AND (
           $3 = ''
           OR id IN (
             SELECT activity_id
             FROM activity_locations
             WHERE location_notes ILIKE '%' || $3 || '%'
                OR address_line_1 ILIKE '%' || $3 || '%'
           )
         )
       ORDER BY published_at DESC NULLS LAST, created_at DESC`,
      [categoryId, ageMonths, location],
    );
    return res.json({ activities: result.rows });
  } catch (error) {
    console.error("Published activity list error:", error);
    return res.status(500).json({ error: "Unable to load published activities." });
  }
});

activitiesRouter.get("/favorites", async (req, res) => {
  try {
    const result = await db.query(
      `SELECT a.id, a.title, a.is_free, a.price_amount
       FROM activity_favorites f
       JOIN activities a ON a.id = f.activity_id
       WHERE f.user_id = $1
       ORDER BY f.created_at DESC`,
      [req.user.id],
    );
    return res.json({ favorites: result.rows });
  } catch (error) {
    console.error("Favorite list error:", error);
    return res.status(500).json({ error: "Unable to load saved activities." });
  }
});

activitiesRouter.post("/:id/favorite", async (req, res) => {
  try {
    await db.query(
      `INSERT INTO activity_favorites (user_id, activity_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, activity_id) DO NOTHING`,
      [req.user.id, req.params.id],
    );
    return res.status(201).json({ saved: true });
  } catch (error) {
    console.error("Save favorite error:", error);
    return res.status(500).json({ error: "Unable to save this activity." });
  }
});

activitiesRouter.delete("/:id/favorite", async (req, res) => {
  try {
    await db.query(
      `DELETE FROM activity_favorites
       WHERE user_id = $1 AND activity_id = $2`,
      [req.user.id, req.params.id],
    );
    return res.json({ saved: false });
  } catch (error) {
    console.error("Remove favorite error:", error);
    return res.status(500).json({ error: "Unable to remove this saved activity." });
  }
});

const activityColumns = `
  id,
  provider_id,
  title,
  short_description,
  description,
  activity_format,
  minimum_age_months,
  maximum_age_months,
  is_free,
  price_amount,
  currency_code,
  registration_url,
  publication_status,
  created_at
`;

const clean = (value) => {
  const text = String(value || "").trim();
  return text ? text : null;
};

const readActivity = (body) => {
  const title = clean(body.title);
  const activityFormat = String(body.activity_format || "").trim();
  const providerId = Number(body.provider_id);
  const isFree = body.is_free !== false && body.is_free !== "false";

  if (!Number.isInteger(providerId) || providerId <= 0) {
    return { error: "Choose an approved provider." };
  }
  if (!title) return { error: "Title is required." };
  if (!Number.isInteger(Number(body.category_id))) {
    return { error: "Choose a category." };
  }
  if (!["IN_PERSON", "ONLINE", "HYBRID"].includes(activityFormat)) {
    return { error: "Choose in person, online, or hybrid." };
  }

  const readAge = (raw, label) => {
    if (raw === null || raw === undefined || raw === "") return null;
    const months = Number(raw);
    if (!Number.isInteger(months) || months < 0) {
      return { error: `${label} must be a whole number of months, or left blank.` };
    }
    return months;
  };

  const minimumAge = readAge(body.minimum_age_months, "Minimum age");
  const maximumAge = readAge(body.maximum_age_months, "Maximum age");
  if (minimumAge && minimumAge.error) return minimumAge;
  if (maximumAge && maximumAge.error) return maximumAge;
  if (minimumAge !== null && maximumAge !== null && maximumAge < minimumAge) {
    return { error: "Maximum age must be at least the minimum age." };
  }

  let priceAmount = null;
  if (!isFree) {
    priceAmount = Number(body.price_amount);
    if (!Number.isFinite(priceAmount) || priceAmount < 0) {
      return { error: "Enter a price of 0 or more, or mark the activity as free." };
    }
  }

  return {
    value: {
      providerId,
      title,
      shortDescription: clean(body.short_description),
      description: clean(body.description),
      activityFormat,
      minimumAge,
      maximumAge,
      isFree,
      priceAmount,
      registrationUrl: clean(body.registration_url),
      categoryId: Number(body.category_id),
    },
  };
};

activitiesRouter.get("/mine", async (req, res) => {
  try {
    const result = await db.query(
      `SELECT ${activityColumns}
       FROM activities
       WHERE created_by_user_id = $1
       ORDER BY created_at DESC`,
      [req.user.id],
    );
    return res.json({ activities: result.rows });
  } catch (error) {
    console.error("Activity list error:", error);
    return res.status(500).json({ error: "Unable to load activities." });
  }
});

activitiesRouter.post("/", async (req, res) => {
  const parsed = readActivity(req.body);
  if (parsed.error) return res.status(400).json({ error: parsed.error });

  const { value } = parsed;

  try {
    const owner = await db.query(
      `SELECT 1
       FROM providers p
       JOIN provider_memberships m ON m.provider_id = p.id
       WHERE p.id = $1
         AND p.approval_status = 'APPROVED'
         AND m.user_id = $2
         AND m.membership_role = 'OWNER'
         AND m.membership_status = 'ACTIVE'`,
      [value.providerId, req.user.id],
    );

    if (owner.rowCount === 0) {
      return res.status(403).json({
        error: "Only an approved provider can submit an activity.",
      });
    }

    const result = await db.query(
      `INSERT INTO activities (
         provider_id,
         created_by_user_id,
         title,
         short_description,
         description,
         activity_format,
         minimum_age_months,
         maximum_age_months,
         is_free,
         price_amount,
         registration_url,
         publication_status
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'PENDING_REVIEW')
       RETURNING ${activityColumns}`,
      [
        value.providerId,
        req.user.id,
        value.title,
        value.shortDescription,
        value.description,
        value.activityFormat,
        value.minimumAge,
        value.maximumAge,
        value.isFree,
        value.priceAmount,
        value.registrationUrl,
      ],
    );

    await db.query(
      `INSERT INTO activity_category_links (activity_id, category_id, is_primary)
       VALUES ($1, $2, TRUE)`,
      [result.rows[0].id, value.categoryId],
    );

    return res.status(201).json({ activity: result.rows[0] });
  } catch (error) {
    console.error("Activity submit error:", error);
    return res.status(500).json({ error: "Unable to submit the activity." });
  }
});

activitiesRouter.patch("/:id/category", async (req, res) => {
  const categoryId = Number(req.body.category_id);
  if (!Number.isInteger(categoryId) || categoryId <= 0) {
    return res.status(400).json({ error: "Choose a category." });
  }

  try {
    const owned = await db.query(
      `SELECT 1
       FROM activities a
       JOIN provider_memberships m ON m.provider_id = a.provider_id
       WHERE a.id = $1
         AND m.user_id = $2
         AND m.membership_role = 'OWNER'
         AND m.membership_status = 'ACTIVE'`,
      [req.params.id, req.user.id],
    );
    if (owned.rowCount === 0) {
      return res.status(403).json({ error: "Only the provider owner can set the category." });
    }

    await db.query(`DELETE FROM activity_category_links WHERE activity_id = $1`, [req.params.id]);
    await db.query(
      `INSERT INTO activity_category_links (activity_id, category_id, is_primary)
       VALUES ($1, $2, TRUE)`,
      [req.params.id, categoryId],
    );
    return res.json({ category_id: categoryId });
  } catch (error) {
    console.error("Activity category error:", error);
    return res.status(500).json({ error: "Unable to set the category." });
  }
});

activitiesRouter.get("/pending", requireRank("moderator"), async (req, res) => {
  try {
    const result = await db.query(
      `SELECT ${activityColumns}
       FROM activities
       WHERE publication_status = 'PENDING_REVIEW'
       ORDER BY created_at`,
    );
    return res.json({ activities: result.rows });
  } catch (error) {
    console.error("Pending activity list error:", error);
    return res.status(500).json({ error: "Unable to load activities waiting for review." });
  }
});

activitiesRouter.patch("/:id/review", requireRank("moderator"), async (req, res) => {
  const status = String(req.body.publication_status || "").trim();
  if (status !== "PUBLISHED" && status !== "REJECTED") {
    return res.status(400).json({ error: "Status must be PUBLISHED or REJECTED." });
  }

  try {
    const publishedAt = status === "PUBLISHED" ? new Date() : null;
    const result = await db.query(
      `UPDATE activities
       SET publication_status = $1::varchar,
           published_at = $2::timestamptz
       WHERE id = $3::bigint
         AND publication_status = 'PENDING_REVIEW'
       RETURNING ${activityColumns}`,
      [status, publishedAt, req.params.id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Activity waiting for review was not found." });
    }
    return res.json({ activity: result.rows[0] });
  } catch (error) {
    console.error("Activity review error:", error);
    return res.status(500).json({
      error: error.message || "Unable to review the activity.",
    });
  }
});

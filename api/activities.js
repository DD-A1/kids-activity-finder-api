import express from "express";
import { db } from "../db/client.js";
import { authenticateToken } from "../middleware/authenticateToken.js";

export const activitiesRouter = express.Router();
activitiesRouter.use(authenticateToken);

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

    return res.status(201).json({ activity: result.rows[0] });
  } catch (error) {
    console.error("Activity submit error:", error);
    return res.status(500).json({ error: "Unable to submit the activity." });
  }
});

import express from "express";
import { db } from "../db/client.js";
import { authenticateToken } from "../middleware/authenticateToken.js";
import { requireRole } from "../middleware/requireRole.js";

export const householdRouter = express.Router();

householdRouter.use(authenticateToken, requireRole("parent"));

const profileColumns = `
  id,
  user_id,
  household_children_count,
  created_at,
  updated_at
`;

const readCount = (body) => {
  const raw = body.household_children_count;

  if (raw === null || raw === undefined || raw === "") {
    return { value: null };
  }

  const count = Number(raw);
  if (!Number.isInteger(count) || count < 0) {
    return {
      error: "Household children count must be a whole number, or left blank.",
    };
  }

  return { value: count };
};

householdRouter.get("/", async (req, res) => {
  try {
    const result = await db.query(
      `SELECT ${profileColumns}
       FROM parent_profiles
       WHERE user_id = $1`,
      [req.user.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Household profile not found." });
    }

    return res.json({ household: result.rows[0] });
  } catch (error) {
    console.error("Household read error:", error);
    return res.status(500).json({ error: "Unable to load the household profile." });
  }
});

householdRouter.patch("/", async (req, res) => {
  const parsed = readCount(req.body);
  if (parsed.error) {
    return res.status(400).json({ error: parsed.error });
  }

  try {
    const result = await db.query(
      `UPDATE parent_profiles
       SET household_children_count = $1
       WHERE user_id = $2
       RETURNING ${profileColumns}`,
      [parsed.value, req.user.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Household profile not found." });
    }

    return res.json({ household: result.rows[0] });
  } catch (error) {
    console.error("Household update error:", error);
    return res.status(500).json({ error: "Unable to save the household profile." });
  }
});

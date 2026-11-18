import express from "express";
import { db } from "../db/client.js";
import { authenticateToken } from "../middleware/authenticateToken.js";
import { requireRole } from "../middleware/requireRole.js";

export const childrenRouter = express.Router();

childrenRouter.use(authenticateToken, requireRole("parent"));

const childColumns = `
  id,
  parent_user_id,
  first_name,
  nickname,
  display_name,
  date_of_birth,
  created_at,
  updated_at
`;

const blankToNull = (value) => {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const readChildInput = (body) => {
  const firstName = blankToNull(body.first_name);
  const nickname = blankToNull(body.nickname);
  const displayName = blankToNull(body.display_name);
  const dateOfBirth =
    typeof body.date_of_birth === "string" ? body.date_of_birth.trim() : "";

  if (!displayName) {
    return { error: "A display name is required." };
  }

  if (!firstName && !nickname) {
    return { error: "A first name or a nickname is required." };
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateOfBirth)) {
    return { error: "Date of birth must be a YYYY-MM-DD date." };
  }

  const parsedDate = new Date(`${dateOfBirth}T00:00:00Z`);
  if (Number.isNaN(parsedDate.getTime())) {
    return { error: "Date of birth must be a real date." };
  }

  const today = new Date();
  const todayText = today.toISOString().slice(0, 10);
  if (dateOfBirth > todayText) {
    return { error: "Date of birth cannot be in the future." };
  }

  return {
    value: {
      firstName,
      nickname,
      displayName,
      dateOfBirth,
    },
  };
};

const findOwnedChild = async (childId, parentUserId) => {
  const result = await db.query(
    `SELECT ${childColumns}
     FROM child_profiles
     WHERE id = $1
       AND parent_user_id = $2`,
    [childId, parentUserId],
  );

  return result.rows[0] || null;
};

childrenRouter.get("/", async (req, res) => {
  try {
    const result = await db.query(
      `SELECT ${childColumns}
       FROM child_profiles
       WHERE parent_user_id = $1
       ORDER BY created_at DESC, id DESC`,
      [req.user.id],
    );

    return res.status(200).json({
      children: result.rows,
    });
  } catch (error) {
    console.error("List children error:", error);

    return res.status(500).json({
      error: "Unable to load child profiles.",
    });
  }
});

childrenRouter.post("/", async (req, res) => {
  const input = readChildInput(req.body || {});

  if (input.error) {
    return res.status(400).json({
      error: input.error,
    });
  }

  try {
    const result = await db.query(
      `INSERT INTO child_profiles (
         parent_user_id,
         first_name,
         nickname,
         display_name,
         date_of_birth
       )
       VALUES ($1, $2, $3, $4, $5)
       RETURNING ${childColumns}`,
      [
        req.user.id,
        input.value.firstName,
        input.value.nickname,
        input.value.displayName,
        input.value.dateOfBirth,
      ],
    );

    return res.status(201).json({
      message: "Child profile created.",
      child: result.rows[0],
    });
  } catch (error) {
    console.error("Create child error:", error);

    return res.status(500).json({
      error: "Unable to create the child profile.",
    });
  }
});

childrenRouter.patch("/:id", async (req, res) => {
  const childId = Number(req.params.id);

  if (!Number.isInteger(childId)) {
    return res.status(400).json({
      error: "Child id must be a number.",
    });
  }

  const input = readChildInput(req.body || {});

  if (input.error) {
    return res.status(400).json({
      error: input.error,
    });
  }

  try {
    const result = await db.query(
      `UPDATE child_profiles
       SET first_name = $1,
           nickname = $2,
           display_name = $3,
           date_of_birth = $4
       WHERE id = $5
         AND parent_user_id = $6
       RETURNING ${childColumns}`,
      [
        input.value.firstName,
        input.value.nickname,
        input.value.displayName,
        input.value.dateOfBirth,
        childId,
        req.user.id,
      ],
    );

    const child = result.rows[0];

    if (!child) {
      return res.status(404).json({
        error: "Child profile not found.",
      });
    }

    return res.status(200).json({
      message: "Child profile updated.",
      child,
    });
  } catch (error) {
    console.error("Update child error:", error);

    return res.status(500).json({
      error: "Unable to update the child profile.",
    });
  }
});

childrenRouter.delete("/:id", async (req, res) => {
  const childId = Number(req.params.id);

  if (!Number.isInteger(childId)) {
    return res.status(400).json({
      error: "Child id must be a number.",
    });
  }

  try {
    const existing = await findOwnedChild(childId, req.user.id);

    if (!existing) {
      return res.status(404).json({
        error: "Child profile not found.",
      });
    }

    await db.query(
      `DELETE FROM child_profiles
       WHERE id = $1
         AND parent_user_id = $2`,
      [childId, req.user.id],
    );

    return res.status(200).json({
      message: "Child profile deleted.",
    });
  } catch (error) {
    console.error("Delete child error:", error);

    return res.status(500).json({
      error: "Unable to delete the child profile.",
    });
  }
});

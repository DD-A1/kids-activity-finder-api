import { db } from "../db/client.js";

export const requireRole = (roleCode) => async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT id
       FROM user_roles
       WHERE user_id = $1
         AND role_code = $2
         AND revoked_at IS NULL`,
      [req.user.id, roleCode],
    );

    if (result.rowCount === 0) {
      return res.status(403).json({
        error: "You do not have permission to do that.",
      });
    }

    next();
  } catch (error) {
    console.error("Role check error:", error);

    return res.status(500).json({
      error: "Unable to check permissions.",
    });
  }
};

import jwt from "jsonwebtoken";
import { db } from "../db/client.js";

export const authenticateToken = async (req, res, next) => {
  // Get the Authorization header
  const authHeader = req.headers.authorization;

  // Check for a Bearer token
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({
      error: "Authentication required.",
    });
  }

  try {
    // Verify the token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Find the user associated with the token
    const userResult = await db.query(
      `SELECT id, email, account_status
       FROM users
       WHERE id = $1`,
      [decoded.userId],
    );

    const user = userResult.rows[0];

    if (!user || user.account_status !== "active") {
      return res.status(401).json({
        error: "Invalid or inactive account.",
      });
    }

    // Attach user to the request
    req.user = user;

    next();
  } catch (error) {
    return res.status(401).json({
      error: "Invalid or expired token.",
    });
  }
};

import express from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { db } from "../db/client.js";
import { authenticateToken } from "../middleware/authenticateToken.js";

export const authorizationRouter = express.Router();

// POST /api/auth/register
authorizationRouter.post("/register", async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      error: "Email and password are required.",
    });
  }

  if (typeof email !== "string" || typeof password !== "string") {
    return res.status(400).json({
      error: "Email and password must be valid text.",
    });
  }

  const normalizedEmail = email.trim().toLowerCase();

  if (!normalizedEmail || password.length < 8) {
    return res.status(400).json({
      error:
        "A valid email and password of at least 8 characters are required.",
    });
  }

  const client = await db.connect();

  try {
    await client.query("BEGIN");

    const passwordHash = await bcrypt.hash(password, 12);

    const userResult = await client.query(
      `INSERT INTO users (email, password_hash, account_status)
       VALUES ($1, $2, 'active')
       RETURNING id, email, account_status`,
      [normalizedEmail, passwordHash],
    );

    const user = userResult.rows[0];

    await client.query(
      `INSERT INTO parent_profiles (user_id)
       VALUES ($1)`,
      [user.id],
    );

    await client.query(
      `INSERT INTO user_roles (user_id, role_code)
       VALUES ($1, 'parent')`,
      [user.id],
    );

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });

    await client.query("COMMIT");

    return res.status(201).json({
      message: "Account created successfully.",
      user,
      token,
    });
  } catch (error) {
    await client.query("ROLLBACK");

    if (error.code === "23505") {
      return res.status(409).json({
        error: "An account with this email already exists.",
      });
    }

    console.error("Registration error:", error);

    return res.status(500).json({
      error: error.message,
      code: error.code,
      detail: error.detail,
    });
  } finally {
    client.release();
  }
});

// POST /api/auth/login
authorizationRouter.post("/login", async (req, res) => {
  const { email, password } = req.body;

  // Check required fields
  if (!email || !password) {
    return res.status(400).json({
      error: "Email and password are required.",
    });
  }

  if (typeof email !== "string" || typeof password !== "string") {
    return res.status(400).json({
      error: "Email and password must be valid text.",
    });
  }

  // Normalize email
  const normalizedEmail = email.trim().toLowerCase();

  try {
    // Find user by email
    const userResult = await db.query(
      `SELECT id, email, password_hash, account_status
       FROM users
       WHERE email = $1`,
      [normalizedEmail],
    );

    const user = userResult.rows[0];

    // Check whether account exists
    if (!user) {
      return res.status(401).json({
        error: "Invalid email or password.",
      });
    }

    // Check account status
    if (user.account_status !== "active") {
      return res.status(403).json({
        error: "This account is not active.",
      });
    }

    // Compare submitted password with stored hash
    const passwordMatches = await bcrypt.compare(password, user.password_hash);

    if (!passwordMatches) {
      return res.status(401).json({
        error: "Invalid email or password.",
      });
    }

    // Create JWT token
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });

    // Return successful login
    return res.status(200).json({
      message: "Login successful.",
      user: {
        id: user.id,
        email: user.email,
        account_status: user.account_status,
      },
      token,
    });
  } catch (error) {
    console.error("Login error:", error);

    return res.status(500).json({
      error: "Unable to log in.",
    });
  }
});

// GET /api/auth/me
authorizationRouter.get("/me", authenticateToken, (req, res) => {
  return res.status(200).json({
    user: req.user,
  });
});

import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { db } from "./db/client.js";
import { authorizationRouter } from "./api/authorization.js";
import { childrenRouter } from "./api/children.js";
import { householdRouter } from "./api/household.js";
import { providersRouter } from "./api/providers.js";
import { activitiesRouter } from "./api/activities.js";


dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(
  cors({
    origin: "http://localhost:5173",
  }),
);

app.use(express.json());
app.use("/api/auth", authorizationRouter);
app.use("/api/children", childrenRouter);
app.use("/api/household", householdRouter); 
app.use("/api/providers", providersRouter);
app.use("/api/activities", activitiesRouter);

// Health check route
app.get("/api/health", (req, res) => {
  res.status(200).json({
    status: "success",
    message: "Kids Activity Finder API is running!",
  });
});

// Database connection test
app.get("/api/db-test", async (req, res) => {
  try {
    const result = await db.query("SELECT NOW()");

    res.status(200).json({
      status: "success",
      message: "Database connection successful!",
      time: result.rows[0].now,
    });
  } catch (error) {
    console.error("Database connection error:", error);

    res.status(500).json({
      status: "error",
      message: "Database connection failed.",
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});

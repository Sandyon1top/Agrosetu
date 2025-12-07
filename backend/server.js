const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
require("dotenv").config();

const app = express();

// ====== CORS MIDDLEWARE ======
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept");
  
  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }
  
  next();
});

// ====== BODY PARSER ======
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ====== MONGODB CONNECTION ======
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log("✅ MongoDB Connected"))
  .catch((err) => console.log("❌ MongoDB Error:", err));

// ====== USER SCHEMA ======
const UserSchema = new mongoose.Schema({
  name: String,
  email: { type: String, unique: true },
  password: String,
});

const User = mongoose.model("users", UserSchema);

// ====== ROUTES ======

// Home route
app.get("/", (req, res) => {
  res.json({
    message: "Agrosetu Backend API",
    status: "running",
    timestamp: new Date().toISOString(),
    endpoints: [
      "GET  /health - Server health check",
      "GET  /test - CORS test endpoint", 
      "POST /signup - User registration",
      "POST /login - User login"
    ]
  });
});

// Health check
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    database: mongoose.connection.readyState === 1 ? "connected" : "disconnected",
    timestamp: new Date().toISOString()
  });
});

// Test endpoint
app.get("/test", (req, res) => {
  res.json({
    status: "ok",
    message: "Backend is accessible!",
    clientIP: req.ip,
    origin: req.headers.origin || "direct",
    timestamp: new Date().toISOString()
  });
});

// Signup endpoint
app.post("/signup", async (req, res) => {
  console.log("📝 Signup request for:", req.body.email);
  
  try {
    const { name, email, password } = req.body;
    
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.json({ 
        status: "error", 
        message: "Email already registered" 
      });
    }
    
    const hashedPassword = await bcrypt.hash(password, 10);
    
    const user = await User.create({
      name,
      email,
      password: hashedPassword
    });
    
    res.json({
      status: "ok",
      message: "Registration successful",
      user: {
        id: user._id,
        name: user.name,
        email: user.email
      }
    });
    
  } catch (error) {
    console.error("Signup error:", error);
    res.status(5001).json({
      status: "error",
      message: "Registration failed"
    });
  }
});

// Login endpoint
app.post("/login", async (req, res) => {
  console.log("🔑 Login request for:", req.body.email);
  
  try {
    const { email, password } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.json({
        status: "error",
        message: "User not found"
      });
    }
    
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.json({
        status: "error", 
        message: "Invalid password"
      });
    }
    
    const token = jwt.sign(
      { userId: user._id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );
    
    res.json({
      status: "ok",
      message: "Login successful",
      token: token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email
      }
    });
    
  } catch (error) {
    console.error("Login error:", error);
    res.status(5001).json({
      status: "error",
      message: "Login failed"
    });
  }
});

// ====== START SERVER ======
const PORT = process.env.PORT || 5001;
const HOST = '0.0.0.0'; // Bind to all network interfaces

app.listen(PORT, HOST, () => {
  console.log("=".repeat(50));
  console.log(`🚀 Server running on PORT: ${PORT}`);
  console.log(`🌐 Accessible on:`);
  console.log(`   http://localhost:${PORT}`);
  console.log(`   http://127.0.0.1:${PORT}`);
  console.log(`   http://${HOST}:${PORT}`);
  console.log("=".repeat(50));
  console.log("\n📋 Available endpoints:");
  console.log(`   GET  http://localhost:${PORT}/`);
  console.log(`   GET  http://localhost:${PORT}/health`);
  console.log(`   GET  http://localhost:${PORT}/test`);
  console.log(`   POST http://localhost:${PORT}/signup`);
  console.log(`   POST http://localhost:${PORT}/login`);
  console.log("=".repeat(50));
});
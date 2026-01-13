const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const axios = require("axios");
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
  .connect(process.env.MONGO_URI || "mongodb://localhost:27017/agrosetu")
  .then(() => console.log("✅ MongoDB Connected"))
  .catch((err) => console.log("❌ MongoDB Error:", err));

// ====== USER SCHEMA ======
const UserSchema = new mongoose.Schema({
  name: String,
  email: { type: String, unique: true },
  password: String,
  resetPasswordToken: String,
  resetPasswordExpires: Date,
  createdAt: { type: Date, default: Date.now }
});

const User = mongoose.model("users", UserSchema);

// ====== WEATHER CACHE SCHEMA ======
const WeatherCacheSchema = new mongoose.Schema({
  latitude: Number,
  longitude: Number,
  data: Object,
  expiresAt: Date,
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

const WeatherCache = mongoose.model("weather_cache", WeatherCacheSchema);

// ====== EMAIL TRANSPORTER ======
const createTransporter = () => {
  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASSWORD) {
    console.log("⚠️  Email not configured. Running in demo mode.");
    return null;
  }
  
  return nodemailer.createTransport({
    host: process.env.EMAIL_HOST || "smtp.gmail.com",
    port: process.env.EMAIL_PORT || 587,
    secure: false,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASSWORD
    }
  });
};

// ====== HELPER FUNCTIONS ======
function mapWeatherCondition(openWeatherCondition) {
  const mapping = {
    'Clear': 'sunny',
    'Clouds': 'cloudy',
    'Rain': 'rainy',
    'Thunderstorm': 'storm',
    'Snow': 'snow',
    'Drizzle': 'rainy',
    'Mist': 'cloudy',
    'Fog': 'cloudy',
    'Haze': 'cloudy'
  };
  return mapping[openWeatherCondition] || 'cloudy';
}

function getFarmingTip(condition) {
  const tips = {
    'sunny': 'Good day for harvesting. Water plants in early morning.',
    'cloudy': 'Suitable for transplanting. Check for fungal diseases.',
    'rainy': 'Avoid pesticide application. Good for rice cultivation.',
    'storm': 'Secure farm structures. Harvest ripe crops if possible.',
    'snow': 'Protect sensitive crops. Check livestock shelter.',
  };
  return tips[condition] || 'Normal farming activities recommended.';
}

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
      "GET  /api/weather/current - Current weather",
      "GET  /api/weather/hourly - Hourly forecast",
      "POST /signup - User registration",
      "POST /login - User login",
      "POST /forgot-password - Request password reset"
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

// ====== WEATHER API ======

// Get current weather
app.get("/api/weather/current", async (req, res) => {
  try {
    const { lat = 27.7172, lon = 85.3240 } = req.query; // Default: Kathmandu
    
    console.log(`🌤️ Weather request for: ${lat}, ${lon}`);
    
    // Check cache first
    const cached = await WeatherCache.findOne({
      latitude: lat,
      longitude: lon,
      expiresAt: { $gt: new Date() }
    });
    
    if (cached) {
      console.log('📦 Serving from cache');
      return res.json({
        ...cached.data,
        source: 'cache',
        cachedAt: cached.updatedAt
      });
    }
    
    // Fetch from OpenWeatherMap
    const apiKey = process.env.OPENWEATHER_API_KEY;
    if (!apiKey) {
      return res.status(500).json({
        status: "error",
        message: "Weather API key not configured"
      });
    }
    
    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric`;
    console.log(`🌐 Calling: ${url.replace(apiKey, 'API_KEY')}`);
    
    const response = await axios.get(url);
    
    // Format data for AgroSetu
    const condition = mapWeatherCondition(response.data.weather[0].main);
    const weatherData = {
      condition: condition,
      temp: Math.round(response.data.main.temp),
      feelsLike: Math.round(response.data.main.feels_like),
      humidity: response.data.main.humidity,
      windSpeed: Math.round(response.data.wind.speed * 3.6), // m/s to km/h
      rainChance: response.data.rain ? (response.data.rain['1h'] || 0) : 0,
      icon: response.data.weather[0].icon,
      farmingTip: getFarmingTip(condition),
      lastUpdated: new Date(),
      location: response.data.name || 'Kathmandu'
    };
    
    // Cache for 30 minutes
    await WeatherCache.findOneAndUpdate(
      { latitude: lat, longitude: lon },
      {
        data: weatherData,
        expiresAt: new Date(Date.now() + 30 * 60 * 1000), // 30 minutes
        updatedAt: new Date()
      },
      { upsert: true, new: true }
    );
    
    console.log('✅ Weather data fetched and cached');
    res.json({
      ...weatherData,
      source: 'api'
    });
    
  } catch (error) {
    console.error('❌ Weather API error:', error.message);
    
    // Try to get any recent cache as fallback
    const anyCache = await WeatherCache.findOne({
      expiresAt: { $gt: new Date() }
    }).sort({ updatedAt: -1 });
    
    if (anyCache) {
      console.log('🔄 Using any cached weather as fallback');
      return res.json({
        ...anyCache.data,
        source: 'cache_fallback',
        cachedAt: anyCache.updatedAt,
        note: 'Weather service down, showing cached data'
      });
    }
    
    res.status(500).json({
      status: "error",
      message: "Weather service unavailable",
      suggestion: "Check OPENWEATHER_API_KEY in .env file"
    });
  }
});

// Get hourly forecast
app.get("/api/weather/hourly", async (req, res) => {
  try {
    const { lat = 27.7172, lon = 85.3240 } = req.query;
    
    const apiKey = process.env.OPENWEATHER_API_KEY;
    const url = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric`;
    
    const response = await axios.get(url);
    
    // Get next 12 hours (4 periods of 3-hour data)
    const hourly = response.data.list.slice(0, 4).map(item => {
      const date = new Date(item.dt * 1000);
      return {
        time: `${date.getHours()}:00`,
        condition: mapWeatherCondition(item.weather[0].main),
        temp: Math.round(item.main.temp),
        icon: item.weather[0].icon,
        rainChance: item.pop ? Math.round(item.pop * 100) : 0 // probability of precipitation
      };
    });
    
    res.json({
      hourly: hourly,
      updatedAt: new Date()
    });
    
  } catch (error) {
    console.error('Hourly forecast error:', error.message);
    res.status(500).json({
      status: "error",
      message: "Failed to get hourly forecast"
    });
  }
});

// ====== AUTH ROUTES ======

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
    
    // Hash password
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
    res.status(500).json({
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
      process.env.JWT_SECRET || "agrosetu_secret",
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
    res.status(500).json({
      status: "error",
      message: "Login failed"
    });
  }
});

// ====== FORGOT PASSWORD ======
app.post("/forgot-password", async (req, res) => {
  console.log("📧 Forgot password request for:", req.body.email);
  
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({
        status: "error",
        message: "Email is required"
      });
    }
    
    // Find user
    const user = await User.findOne({ email });
    
    if (!user) {
      console.log("❌ Email not found:", email);
      return res.json({
        status: "not_found",
        message: "Email not found in our system",
        suggestion: "Would you like to create an account with this email?"
      });
    }
    
    console.log("✅ User found:", user.email);
    
    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetTokenExpiry = Date.now() + 3600000; // 1 hour
    
    // Save token to user
    user.resetPasswordToken = resetToken;
    user.resetPasswordExpires = new Date(resetTokenExpiry);
    await user.save();
    
    console.log("✅ Reset token generated for:", email);
    
    // Try to send email if configured
    let emailSent = false;
    const transporter = createTransporter();
    
    if (transporter) {
      try {
        const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password/${resetToken}`;
        
        const mailOptions = {
          from: `"AgroSetu" <${process.env.EMAIL_USER}>`,
          to: email,
          subject: 'AgroSetu - Password Reset Request',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #1B5E20;">🌱 AgroSetu Password Reset</h2>
              <p>Hello ${user.name},</p>
              <p>We received a request to reset your password. Click the link below to create a new password:</p>
              <p><a href="${resetUrl}" style="color: #1B5E20; font-weight: bold;">${resetUrl}</a></p>
              <p><strong>This link will expire in 1 hour.</strong></p>
              <p>If you didn't request this, please ignore this email.</p>
              <p>Best regards,<br>AgroSetu Team</p>
            </div>
          `
        };
        
        await transporter.sendMail(mailOptions);
        emailSent = true;
        console.log("✅ Password reset email sent to:", email);
        
      } catch (emailError) {
        console.error("❌ Email sending failed:", emailError.message);
      }
    } else {
      console.log("⚠️  Email not configured. Showing token in response.");
    }
    
    res.json({
      status: "success",
      message: emailSent 
        ? "Password reset link sent to your email" 
        : "Password reset would be sent (email not configured)",
      emailSent: emailSent,
      name: user.name,
      email: email,
      // In development/demo, include token
      demoToken: process.env.NODE_ENV !== 'production' ? resetToken : undefined
    });
    
  } catch (error) {
    console.error("❌ Forgot password error:", error);
    res.status(500).json({
      status: "error",
      message: "Something went wrong. Please try again."
    });
  }
});

// ====== START SERVER ======
const PORT = process.env.PORT || 5001;
const HOST = '0.0.0.0';

app.listen(PORT, HOST, () => {
  console.log("=".repeat(60));
  console.log(`🚀 AgroSetu Backend Server`);
  console.log(`📡 PORT: ${PORT}`);
  console.log(`🌐 Accessible on:`);
  console.log(`   http://localhost:${PORT}`);
  console.log(`   http://127.0.0.1:${PORT}`);
  console.log(`   http://${HOST}:${PORT}`);
  console.log("=".repeat(60));
  console.log("\n📋 Available endpoints:");
  console.log(`   POST http://localhost:${PORT}/signup          - Register user`);
  console.log(`   POST http://localhost:${PORT}/login           - Login user`);
  console.log(`   POST http://localhost:${PORT}/forgot-password - Request password reset`);
  console.log("=".repeat(60));
  console.log("\n📧 Email Configuration:");
  console.log("   To enable email sending, add to .env file:");
  console.log("   EMAIL_USER=your_email@gmail.com");
  console.log("   EMAIL_PASSWORD=your_app_password");
  console.log("=".repeat(60));
});
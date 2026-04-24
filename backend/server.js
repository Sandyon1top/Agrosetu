const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const axios = require("axios"); // ADDED for weather API
const nodemailer = require("nodemailer"); // NEW: For email functionality
const cors = require("cors");
require("dotenv").config();
const multer = require("multer");
const { exec } = require("child_process");
const { promisify } = require("util");
const execAsync = promisify(exec);
const fs = require("fs");
const path = require("path");
const upload = multer({ dest: path.join(__dirname, "uploads/") });

const app = express();
const http = require("http");
const server = http.createServer(app);
const { Server } = require("socket.io");
const io = new Server(server, { cors: { origin: "*" } });

app.set("io", io);

io.on("connection", (socket) => {
  console.log("Client connected via WebSocket: ", socket.id);
  socket.on("join_user_room", (userId) => {
    socket.join(`user_${userId}`);
  });
});

// ====== NEW: EMAIL CONFIGURATION ======
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER, // Add your email to .env
    pass: process.env.EMAIL_PASS, // Add your App Password to .env
  },
});

// ====== CORS MIDDLEWARE ======
app.use(cors());

// ====== BODY PARSER ======
// Increased limit to 10mb to handle Base64 images from Flutter
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ====== MONGODB CONNECTION ======
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log("[DB] MongoDB Connected"))
  .catch((err) => console.log("[DB ERROR] MongoDB Error:", err));

// ====== USER SCHEMA (EMAIL-ONLY — PHONE NUMBER REMOVED PER WORKFLOW) ======
const UserSchema = new mongoose.Schema({
  name: String,
  email: { type: String, unique: true, sparse: true },
  googleId: { type: String, unique: true, sparse: true },
  // FIX: phoneNumber field and phone-related verification removed per workflow
  password: String,

  // Account Status
  isVerified: { type: Boolean, default: false },
  isActive: { type: Boolean, default: true }, // For Deactivation/Delete logic

  // Security
  verificationCode: String,
  verificationExpires: Date,

  createdAt: { type: Date, default: Date.now }
});

const User = mongoose.model("users", UserSchema);

// ====== DISEASE HISTORY SCHEMA ======
const DiseaseHistorySchema = new mongoose.Schema({
  userId: String,
  disease: String,
  confidence: String,
  solutions: [String],
  createdAt: { type: Date, default: Date.now },
});

const DiseaseHistory = mongoose.model("disease_history", DiseaseHistorySchema);

// ====== PASSWORD RESET SCHEMA ======
const PasswordResetSchema = new mongoose.Schema({
  email: String,
  resetCode: String,
  expiresAt: Date,
  used: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

const PasswordReset = mongoose.model("password_resets", PasswordResetSchema);

// ====== WEATHER CACHE SCHEMA ======
const WeatherCacheSchema = new mongoose.Schema({
  latitude: Number,
  longitude: Number,
  type: { type: String, enum: ['current', 'forecast'], default: 'current' }, // NEW: Distinguish cache types
  data: Object,
  expiresAt: Date,
  updatedAt: { type: Date, default: Date.now }
});

const WeatherCache = mongoose.model("weather_cache", WeatherCacheSchema);

// ====== COMMUNITY POST SCHEMA (UPDATED for Nested Comments & Images) ======
const PostSchema = new mongoose.Schema({
  title: String,
  description: String,
  category: String,
  imageUrl: String, // Stores Base64 image data
  author: {
    id: mongoose.Schema.Types.ObjectId,
    name: String,
    email: String,
  },
  likes: [mongoose.Schema.Types.ObjectId], // Array of user IDs who liked
  comments: [
    {
      userId: mongoose.Schema.Types.ObjectId,
      userName: String,
      userEmail: String,
      text: String,
      commentImageUrl: String, // NEW: Stores Base64 for comment images
      replies: [ // NEW: Nested replies array
        {
          userId: mongoose.Schema.Types.ObjectId,
          userName: String,
          text: String,
          createdAt: { type: Date, default: Date.now },
        }
      ],
      createdAt: { type: Date, default: Date.now },
    },
  ],
  solved: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

const Post = mongoose.model("posts", PostSchema);

// ====== NOTIFICATION SCHEMA ======
const NotificationSchema = new mongoose.Schema({
  recipientId: mongoose.Schema.Types.ObjectId,
  senderName: String,
  type: String, // 'like' or 'comment'
  message: String, // Explicit message payload for real-time detailed info
  postTitle: String,
  postId: mongoose.Schema.Types.ObjectId,
  read: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
});

const Notification = mongoose.model("notifications", NotificationSchema);

// ====== HELPER FUNCTIONS ======

// Helper to get coordinates from city name
async function getCoords(city) {
  const apiKey = process.env.OPENWEATHER_API_KEY;
  const url = `http://api.openweathermap.org/geo/1.0/direct?q=${city}&limit=1&appid=${apiKey}`;
  try {
    const response = await axios.get(url);
    if (response.data && response.data.length > 0) {
      return { lat: response.data[0].lat, lon: response.data[0].lon, name: response.data[0].name };
    }
  } catch (error) {
    console.error("[GEO ERROR]", error.message);
  }
  return null;
}

function validatePassword(password) {
  const errors = [];

  if (!password || password.length < 8) {
    errors.push('Password must be at least 8 characters');
  }
  if (!/[A-Z]/.test(password)) {
    errors.push('Password must contain at least one uppercase letter');
  }
  if (!/[a-z]/.test(password)) {
    errors.push('Password must contain at least one lowercase letter');
  }
  if (!/[0-9]/.test(password)) {
    errors.push('Password must contain at least one number');
  }
  if (!/[!@#$%^&*()_+=\[\]{};:`~<>,./\-]/.test(password)) {
    errors.push('Password must contain at least one special character');
  }

  return {
    isValid: errors.length === 0,
    errors: errors
  };
}

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

function getTimeAgo(date) {
  const now = new Date();
  const seconds = Math.floor((now - date) / 1000);

  let interval = seconds / 31536000;
  if (interval > 1) return Math.floor(interval) + " years ago";

  interval = seconds / 2592000;
  if (interval > 1) return Math.floor(interval) + " months ago";

  interval = seconds / 86400;
  if (interval > 1) return Math.floor(interval) + " days ago";

  interval = seconds / 3600;
  if (interval > 1) return Math.floor(interval) + " hours ago";

  interval = seconds / 60;
  if (interval > 1) return Math.floor(interval) + " minutes ago";

  return Math.floor(seconds) + " seconds ago";
}

// ====== JWT MIDDLEWARE ======
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>

  if (!token) {
    return res.status(401).json({ status: "error", message: "Access token required" });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ status: "error", message: "Invalid or expired token" });
    }
    req.user = user;
    next();
  });
}

// ====== GROQ LLM INTEGRATION ======
const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

async function getGroqAnswer(userQuery) {
  try {
    const groqApiKey = process.env.GROQ_API_KEY;

    if (!groqApiKey) {
      console.warn("[GROQ] GROQ_API_KEY not set in .env — skipping Groq");
      return null;
    }

    console.log(`[GROQ] Sending query: "${userQuery}"`);

    const response = await axios.post(
      GROQ_API_URL,
      {
        model: "llama-3.3-70b-versatile",
        messages: [
          {
            role: "system",
            content: `तपाईं एक नेपाली कृषि विशेषज्ञ हुनुहुन्छ। नेपाली किसानहरूलाई खेतीसम्बन्धी सल्लाह दिनुहोस्।

नियमहरू:
- सधैं नेपाली भाषामा जवाफ दिनुहोस्
- जवाफ छोटो र व्यावहारिक राख्नुहोस् (३-५ वाक्य मात्र)
- बाली रोग, किट, मल, सिँचाइ, र मौसमसम्बन्धी प्रश्नहरूको जवाफ दिनुहोस्
- नेपालको स्थानीय परिस्थिति अनुसार सल्लाह दिनुहोस्
- यदि प्रश्न खेतीसँग सम्बन्धित छैन भने विनम्रतापूर्वक भन्नुहोस् कि तपाईं केवल खेतीसम्बन्धी प्रश्नहरूको जवाफ दिन सक्नुहुन्छ`
          },
          {
            role: "user",
            content: userQuery
          }
        ],
        max_tokens: 300,
        temperature: 0.7,
      },
      {
        headers: {
          "Authorization": `Bearer ${groqApiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 15000,
      }
    );

    const answer = response.data.choices[0].message.content.trim();
    console.log(`[GROQ] Answer received: "${answer.substring(0, 100)}..."`);
    return answer;

  } catch (error) {
    console.error("[GROQ ERROR]", error.response?.data || error.message);
    return null;
  }
}

async function getGroqWeatherTip(condition, temp, humidity, windSpeed, location) {
  try {
    const groqApiKey = process.env.GROQ_API_KEY;
    if (!groqApiKey) return null;

    const response = await axios.post(
      GROQ_API_URL,
      {
        model: "llama-3.3-70b-versatile",
        messages: [
          {
            role: "system",
            content: "You are an expert agricultural AI. Provide a concise, action-oriented farming tip (1-2 sentences maximum) based EXACTLY on the current weather metrics provided. Do not use conversational filler."
          },
          {
            role: "user",
            content: `Location: ${location}. Weather: ${condition}. Temp: ${temp}°C, Humidity: ${humidity}%, Wind: ${windSpeed}km/h. Give a farming suggestion.`
          }
        ],
        max_tokens: 100,
        temperature: 0.7,
      },
      {
        headers: {
          "Authorization": `Bearer ${groqApiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 5000,
      }
    );
    return response.data.choices[0].message.content.trim();
  } catch (error) {
    console.error("[GROQ WEATHER] Error:", error.message);
    return null;
  }
}

// ====== ROUTES ======

app.get("/", (req, res) => {
  res.json({
    message: "Agrosetu Backend API",
    status: "running",
    timestamp: new Date().toISOString(),
    endpoints: [
      "GET /health - Server health check",
      "GET /test - CORS test endpoint",
      "GET /api/weather/current - Current weather",
      "GET /api/weather/hourly - Hourly forecast",
      "POST /signup - User registration",
      "POST /login - User login",
      "POST /api/verify-otp - Verify user account",
      "POST /api/resend-otp - Resend OTP",
      "GET /api/notifications/:userId - Get user notifications",
      "POST /api/notifications/read - Mark notifications as read",
      "POST /api/voice/query - Voice assistant query (text)",
      "POST /api/voice/text-query - Voice assistant query (Flutter Web alias)",
      "POST /api/voice/audio-query - Voice assistant query (audio → Whisper → Groq)",
      "POST /api/password-reset/request - Request password reset",
      "POST /api/password-reset/verify - Verify reset code",
      "DELETE /api/community/posts/:postId - Delete a post"
    ]
  });
});

app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    database: mongoose.connection.readyState === 1 ? "connected" : "disconnected",
    groq: process.env.GROQ_API_KEY ? "configured" : "not configured (KB fallback active)",
    timestamp: new Date().toISOString()
  });
});

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
    const { lat, lon, city } = req.query;
    let targetLat = lat || 27.7172;
    let targetLon = lon || 85.3240;

    if (city) {
      const coords = await getCoords(city);
      if (coords) {
        targetLat = coords.lat;
        targetLon = coords.lon;
      }
    }

    console.log(`🌤️ Current weather request for: ${targetLat}, ${targetLon} (City: ${city || 'N/A'})`);

    // Check for ANY cache if offline or for FRESH cache if online
    const cached = await WeatherCache.findOne({
      latitude: targetLat,
      longitude: targetLon,
      type: 'current'
    }).sort({ updatedAt: -1 });

    // If the cache is still valid (less than 30 mins old), use it
    if (cached && (new Date() < cached.expiresAt) && cached.data && cached.data.temp !== undefined) {
      console.log('📦 Serving from fresh cache');
      return res.json({ ...cached.data, source: 'cache', cachedAt: cached.updatedAt });
    }

    const apiKey = process.env.OPENWEATHER_API_KEY;
    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${targetLat}&lon=${targetLon}&appid=${apiKey}&units=metric`;
    const response = await axios.get(url);

    const condition = mapWeatherCondition(response.data.weather[0].main);
    const weatherData = {
      condition: condition,
      temp: Math.round(response.data.main.temp),
      feelsLike: Math.round(response.data.main.feels_like),
      humidity: response.data.main.humidity,
      windSpeed: Math.round(response.data.wind.speed * 3.6),
      rainChance: response.data.rain ? (response.data.rain['1h'] || 0) : 0,
      icon: response.data.weather[0].icon,
      farmingTip: await getGroqWeatherTip(
        condition,
        Math.round(response.data.main.temp),
        response.data.main.humidity,
        Math.round(response.data.wind.speed * 3.6),
        response.data.name || 'Kathmandu'
      ) || getFarmingTip(condition),
      lastUpdated: new Date(),
      location: response.data.name || 'Kathmandu'
    };

    await WeatherCache.findOneAndUpdate(
      { latitude: targetLat, longitude: targetLon, type: 'current' },
      { data: weatherData, expiresAt: new Date(Date.now() + 30 * 60 * 1000), updatedAt: new Date() },
      { upsert: true }
    );

    res.json({ ...weatherData, source: 'api' });
  } catch (error) {
    console.error('❌ Current Weather API error:', error.message);

    // Fallback: Return ANY available cache if API fails
    const { lat, lon } = req.query;
    const fallbackLat = lat || 27.7172;
    const fallbackLon = lon || 85.3240;
    const oldCache = await WeatherCache.findOne({ latitude: fallbackLat, longitude: fallbackLon, type: 'current' }).sort({ updatedAt: -1 });
    if (oldCache) return res.json({ ...oldCache.data, source: 'offline-cache' });

    res.status(500).json({ status: "error", message: "Weather service unavailable" });
  }
});

// Get hourly forecast
app.get("/api/weather/hourly", async (req, res) => {
  try {
    const { lat = 27.7172, lon = 85.3240 } = req.query;
    const apiKey = process.env.OPENWEATHER_API_KEY;
    const url = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric`;
    const response = await axios.get(url);

    const hourly = response.data.list.slice(0, 4).map(item => {
      const date = new Date(item.dt * 1000);
      return {
        time: `${date.getHours()}:00`,
        condition: mapWeatherCondition(item.weather[0].main),
        temp: Math.round(item.main.temp),
        icon: item.weather[0].icon,
        rainChance: item.pop ? Math.round(item.pop * 100) : 0
      };
    });

    res.json({ hourly: hourly, updatedAt: new Date() });
  } catch (error) {
    res.status(500).json({ status: "error", message: "Failed hourly forecast" });
  }
});

// ====== 7-DAY FORECAST API ======
app.get("/api/weather/forecast", async (req, res) => {
  try {
    const { lat, lon, city } = req.query;
    let targetLat = lat || 27.7172;
    let targetLon = lon || 85.3240;

    if (city) {
      const coords = await getCoords(city);
      if (coords) {
        targetLat = coords.lat;
        targetLon = coords.lon;
      }
    }

    console.log(`📅 Forecast request for: ${targetLat}, ${targetLon} (City: ${city || 'N/A'})`);

    // Check for ANY cache if offline or for FRESH cache if online
    const cached = await WeatherCache.findOne({
      latitude: targetLat,
      longitude: targetLon,
      type: 'forecast'
    }).sort({ updatedAt: -1 });

    // If the cache is still valid (less than 3 hours old), use it
    if (cached && (new Date() < cached.expiresAt) && cached.data && Array.isArray(cached.data) && cached.data.length > 0 && cached.data[0].temp !== undefined) {
      console.log('📦 Serving Forecast from fresh cache');
      return res.json(cached.data);
    }

    const apiKey = process.env.OPENWEATHER_API_KEY;
    const url = `https://api.openweathermap.org/data/2.5/forecast?lat=${targetLat}&lon=${targetLon}&appid=${apiKey}&units=metric`;
    const response = await axios.get(url);

    const dailyData = {};
    response.data.list.forEach(item => {
      const date = new Date(item.dt * 1000).toISOString().split('T')[0];
      const temp = Math.round(item.main.temp || 0);
      const temp_max = Math.round(item.main.temp_max || 0);
      const temp_min = Math.round(item.main.temp_min || 0);

      if (!dailyData[date]) {
        dailyData[date] = {
          date: date,
          temp: temp,
          maxTemp: temp_max,
          minTemp: temp_min,
          condition: mapWeatherCondition(item.weather[0].main),
          icon: item.weather[0].icon
        };
      } else {
        if (temp_max > dailyData[date].maxTemp) dailyData[date].maxTemp = temp_max;
        if (temp_min < dailyData[date].minTemp) dailyData[date].minTemp = temp_min;
      }
    });

    const forecastArray = Object.values(dailyData).slice(0, 7);

    await WeatherCache.findOneAndUpdate(
      { latitude: targetLat, longitude: targetLon, type: 'forecast' },
      {
        data: forecastArray,
        expiresAt: new Date(Date.now() + 3 * 60 * 60 * 1000),
        updatedAt: new Date()
      },
      { upsert: true }
    );

    res.json(forecastArray);
  } catch (error) {
    console.error('❌ Forecast API error:', error.message);

    // Fallback: Return ANY available cache if API fails
    const { lat, lon } = req.query;
    const fallbackLat = lat || 27.7172;
    const fallbackLon = lon || 85.3240;
    const oldCache = await WeatherCache.findOne({ latitude: fallbackLat, longitude: fallbackLon, type: 'forecast' }).sort({ updatedAt: -1 });
    if (oldCache) return res.json(oldCache.data);

    res.status(500).json({ status: "error", message: "Forecast unavailable" });
  }
});

// ====== AUTH ROUTES ======

app.post("/signup", async (req, res) => {
  try {
    const { name, identity, password } = req.body;

    if (!name || !identity || !password) {
      return res.status(400).json({ status: "error", message: "Name, identity (email), and password are required" });
    }

    if (!identity.includes('@')) {
      return res.status(400).json({ status: "error", message: "Please provide a valid email address" });
    }

    const passwordCheck = validatePassword(password);
    if (!passwordCheck.isValid) {
      return res.status(400).json({ status: "error", message: passwordCheck.errors[0], errors: passwordCheck.errors });
    }

    const normalizedIdentity = identity.trim().toLowerCase();
    let user = await User.findOne({ email: normalizedIdentity });
    const hashedPassword = await bcrypt.hash(password, 10);
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 15 * 60 * 1000);

    if (user && user.isVerified && user.isActive) {
      return res.status(400).json({ status: "error", message: "Account already exists." });
    }

    if (user) {
      user.name = name;
      user.password = hashedPassword;
      user.verificationCode = otp;
      user.verificationExpires = expires;
      await user.save();
    } else {
      user = await User.create({
        name,
        email: normalizedIdentity,
        password: hashedPassword,
        verificationCode: otp,
        verificationExpires: expires
      });
    }

    await transporter.sendMail({
      from: `"AgroSetu" <${process.env.EMAIL_USER}>`,
      to: identity,
      subject: "Verify your AgroSetu Account",
      html: `<div style="padding:20px; border:1px solid #ddd;">
        <h2>Welcome ${name}!</h2>
        <p>Your verification code is: <b style="font-size:24px;">${otp}</b></p>
        <p>This code expires in <strong>15 minutes</strong>.</p>
      </div>`
    });

    res.json({ status: "pending", message: "OTP sent successfully" });
  } catch (error) {
    console.error("Signup Error:", error);
    res.status(500).json({ status: "error", message: "Signup failed" });
  }
});

app.post("/api/resend-otp", async (req, res) => {
  try {
    const { identity } = req.body;
    if (!identity) {
      return res.status(400).json({ status: "error", message: "Identity (email) is required" });
    }
    const user = await User.findOne({ email: identity });
    if (!user) return res.json({ status: "error", message: "User not found" });

    const newOtp = Math.floor(100000 + Math.random() * 900000).toString();
    user.verificationCode = newOtp;
    user.verificationExpires = new Date(Date.now() + 15 * 60 * 1000);
    await user.save();

    await transporter.sendMail({
      from: `"AgroSetu" <${process.env.EMAIL_USER}>`,
      to: user.email,
      subject: "Your New AgroSetu Verification Code",
      html: `<div style="padding:20px; border:1px solid #ddd;">
        <h2>New Verification Code</h2>
        <p>Your new OTP is: <b style="font-size:24px;">${newOtp}</b></p>
        <p>This code expires in <strong>15 minutes</strong>.</p>
      </div>`
    });

    res.json({ status: "ok", message: "New OTP sent!" });
  } catch (error) {
    console.error("Resend OTP Error:", error);
    res.status(500).json({ status: "error", message: "Resend failed" });
  }
});

app.put("/api/user/update", authenticateToken, async (req, res) => {
  try {
    const { userId, name, email } = req.body;
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { name, email },
      { new: true }
    );
    if (!updatedUser) return res.status(404).json({ status: "error", message: "User not found" });
    res.json({
      status: "ok",
      message: "Profile updated!",
      user: {
        name: updatedUser.name,
        email: updatedUser.email,
      }
    });
  } catch (error) {
    console.error("Update User Error:", error);
    res.status(500).json({ status: "error", message: "Update failed" });
  }
});

app.post("/api/verify-otp", async (req, res) => {
  try {
    const { identity, otp } = req.body;
    const cleanOtp = String(otp).trim();
    const cleanIdentity = String(identity).trim().toLowerCase();

    if (!cleanIdentity || !cleanOtp) {
      return res.status(400).json({ status: "error", message: "Identity and OTP are required" });
    }
    const user = await User.findOne({ email: cleanIdentity });
    if (!user) {
      return res.status(400).json({ status: "error", message: "User not found" });
    }
    if (!user.verificationExpires || new Date() > user.verificationExpires) {
      return res.status(400).json({ status: "error", message: "Verification code has expired. Please request a new one." });
    }
    if (String(user.verificationCode).trim() !== cleanOtp) {
      return res.status(400).json({ status: "error", message: "Invalid verification code" });
    }

    user.isVerified = true;
    user.verificationCode = null;
    user.verificationExpires = null;
    await user.save();
    res.json({ status: "ok", message: "Account verified! You can now login." });
  } catch (error) {
    console.error("Verify OTP Error:", error);
    res.status(500).json({ status: "error", message: "Verification failed" });
  }
});

// User Search API
app.get("/api/users/search", async (req, res) => {
  try {
    const { query } = req.query;
    if (!query) {
      return res.json({ status: "ok", users: [] });
    }

    const users = await User.find({
      name: { $regex: query, $options: 'i' },
      isActive: true
    }).limit(10).select('name email _id');

    res.json({
      status: "ok",
      users: users.map(u => ({
        id: u._id,
        name: u.name,
        email: u.email
      }))
    });
  } catch (error) {
    console.error("User search error:", error);
    res.status(500).json({ status: "error", message: "Search failed" });
  }
});

app.post("/login", async (req, res) => {
  try {
    const { identity, email, password } = req.body;
    const loginId = identity || email;

    if (!loginId || !password) {
      return res.status(400).json({ status: "error", message: "Email and password are required" });
    }

    const normalizedId = loginId.trim().toLowerCase();
    const user = await User.findOne({ email: normalizedId });

    if (!user || !user.isActive) {
      return res.json({ status: "error", message: "Invalid credentials or account deleted" });
    }

    const passwordMatch = await bcrypt.compare(password, user.password);
    if (!passwordMatch) {
      return res.json({ status: "error", message: "Invalid credentials or account deleted" });
    }

    if (!user.isVerified) {
      return res.json({ status: "unverified", message: "Please verify your account first", identity: loginId });
    }

    const token = jwt.sign(
      { userId: user._id, identity: loginId },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      status: "ok",
      token: token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email
      }
    });
  } catch (error) {
    console.error("Login Error:", error);
    res.status(500).json({ status: "error", message: "Login failed" });
  }
});

// ====== GOOGLE AUTH ROUTE ======
const { OAuth2Client } = require('google-auth-library');

const GOOGLE_WEB_CLIENT_ID = process.env.GOOGLE_WEB_CLIENT_ID ||
  '666169833803-mdpcvgsfvt6r1itejpd0f4pjprncvk4u.apps.googleusercontent.com';
const GOOGLE_IOS_CLIENT_ID = process.env.GOOGLE_IOS_CLIENT_ID ||
  '666169833803-ukurcn8csd642q65r126f76uulqo1dbh.apps.googleusercontent.com';

const googleClient = new OAuth2Client();

app.post('/api/auth/google', async (req, res) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ status: 'error', message: 'Missing idToken' });
    }

    // Verify the token AND check it was issued for our app (audience check).
    // Without audience, any valid Google token from any app would be accepted.
    let ticket;
    try {
      ticket = await googleClient.verifyIdToken({
        idToken,
        audience: [GOOGLE_WEB_CLIENT_ID, GOOGLE_IOS_CLIENT_ID],
      });
    } catch (verifyErr) {
      console.error('[Google Auth] Token verification failed:', verifyErr.message);
      return res.status(401).json({ status: 'error', message: 'Invalid Google token' });
    }

    const payload = ticket.getPayload();

    if (!payload.email_verified) {
      return res.status(403).json({ status: 'error', message: 'Google email is not verified' });
    }

    const googleId = payload.sub;
    const email = payload.email.toLowerCase();
    const name = payload.name || email.split('@')[0];

    // Find by googleId first, then fall back to email (links existing email account).
    let user = await User.findOne({ $or: [{ googleId }, { email }] });

    if (!user) {
      // Brand new user — create with no password
      user = await User.create({
        name,
        email,
        googleId,
        password: '',
        isVerified: true,
        isActive: true,
      });
    } else {
      // Existing user — link Google if not already linked, and unblock if needed
      let changed = false;
      if (!user.googleId) { user.googleId = googleId; changed = true; }
      if (!user.isVerified) { user.isVerified = true; changed = true; }
      if (changed) await user.save();

      if (!user.isActive) {
        return res.status(403).json({ status: 'error', message: 'Account deactivated' });
      }
    }

    // Use same JWT payload shape as /login so authenticateToken middleware works identically
    const token = jwt.sign(
      { userId: user._id, identity: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    return res.json({
      status: 'ok',
      message: 'Google login successful',
      data: {
        token,
        user: { id: user._id, name: user.name, email: user.email },
      },
    });
  } catch (err) {
    console.error('[Google Auth] Error:', err);
    return res.status(500).json({ status: 'error', message: 'Google authentication failed' });
  }
});

// ====== COMMUNITY POSTS ROUTES ======

app.get("/api/community/posts", async (req, res) => {
  try {
    const { category, limit = 50, page = 1 } = req.query;
    let query = (category && category !== 'All') ? { category } : {};
    const posts = await Post.find(query).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(parseInt(limit));

    res.json({
      status: "ok",
      posts: posts.map(post => ({
        id: post._id,
        title: post.title,
        description: post.description,
        category: post.category,
        imageUrl: post.imageUrl,
        author: post.author,
        likes: post.likes.length,
        comments: post.comments.length,
        commentList: post.comments,
        solved: post.solved,
        createdAt: post.createdAt,
        timestamp: getTimeAgo(post.createdAt),
      }))
    });
  } catch (error) {
    console.error("Get Posts Error:", error);
    res.status(500).json({ status: "error", message: "Fetch failed" });
  }
});

app.get("/api/community/post-detail/:postId", async (req, res) => {
  try {
    const { postId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(postId)) {
      return res.status(400).json({ status: "error", message: "Invalid ID format" });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ status: "error", message: "Post not found" });
    }

    res.json({
      status: "ok",
      post: {
        id: post._id,
        title: post.title,
        description: post.description,
        category: post.category,
        imageUrl: post.imageUrl,
        author: post.author,
        likes: post.likes.length,
        comments: post.comments.length,
        commentList: post.comments,
        solved: post.solved,
        createdAt: post.createdAt,
        timestamp: getTimeAgo(post.createdAt),
      }
    });
  } catch (error) {
    console.error("Get Single Post Error:", error);
    res.status(500).json({ status: "error", message: "Fetch failed" });
  }
});

app.post("/api/community/posts", async (req, res) => {
  try {
    const { title, description, category, author, image_data } = req.body;
    const post = await Post.create({
      title, description, category, imageUrl: image_data,
      author: { id: author.id, name: author.name, email: author.email },
      likes: [], comments: [], solved: false
    });
    res.json({ status: "ok", message: "Post created", post });
  } catch (error) {
    console.error("Create Post Error:", error);
    res.status(500).json({ status: "error", message: "Post creation failed" });
  }
});

app.post("/api/community/posts/:postId/like", async (req, res) => {
  try {
    let { userId, userName } = req.body;
    const post = await Post.findById(req.params.postId);
    if (!post) return res.json({ status: "error", message: "Not found" });

    // Fallback: If userName is missing, fetch it from the User collection
    if (!userName && userId) {
      const user = await User.findById(userId);
      if (user) userName = user.name;
    }
    if (!userName) userName = "Someone";

    const likeIndex = post.likes.indexOf(userId);
    let liked = false;
    if (likeIndex === -1) {
      post.likes.push(userId);
      liked = true;
      if (post.author.id.toString() !== userId) {
        const messageStr = `${userName} liked your post "${post.title}"`;
        const newNotif = await Notification.create({
          recipientId: post.author.id,
          senderName: userName,
          type: "like",
          message: messageStr,
          postTitle: post.title,
          postId: post._id
        });
        const io = req.app.get("io");
        if (io) io.to(`user_${post.author.id}`).emit("new_notification", newNotif);
      }
    } else {
      post.likes.splice(likeIndex, 1);
      liked = false;
    }
    await post.save();
    res.json({ status: "ok", likes: post.likes.length, liked: liked });
  } catch (error) {
    console.error("Like Post Error:", error);
    res.status(500).json({ status: "error" });
  }
});

app.post("/api/community/posts/:postId/comments", async (req, res) => {
  try {
    let { userId, userName, userEmail, text, image_data } = req.body;
    const post = await Post.findById(req.params.postId);
    if (!post) return res.json({ status: "error", message: "Post not found" });

    // Fallback: If userName is missing, fetch it from the User collection
    if (!userName && userId) {
      const user = await User.findById(userId);
      if (user) {
        userName = user.name;
        userEmail = userEmail || user.email;
      }
    }
    if (!userName) userName = "Someone";

    const newComment = {
      userId,
      userName,
      userEmail,
      text,
      commentImageUrl: image_data,
      replies: [],
      createdAt: new Date()
    };

    post.comments.push(newComment);
    await post.save();

    if (post.author.id.toString() !== userId) {
      const messageStr = `${userName} commented on your post "${post.title}"`;
      const newNotif = await Notification.create({
        recipientId: post.author.id,
        senderName: userName,
        type: "comment",
        message: messageStr,
        postTitle: post.title,
        postId: post._id
      });
      const io = req.app.get("io");
      if (io) io.to(`user_${post.author.id}`).emit("new_notification", newNotif);
    }
    res.json({ status: "ok", comment: newComment });
  } catch (error) {
    console.error("Comment error:", error);
    res.status(500).json({ status: "error" });
  }
});

app.post("/api/community/posts/:postId/comments/:commentId/replies", async (req, res) => {
  try {
    const { userId, userName, text } = req.body;
    const post = await Post.findById(req.params.postId);

    if (!post) return res.status(404).json({ status: "error", message: "Post not found" });

    const comment = post.comments.id(req.params.commentId);
    if (!comment) return res.status(404).json({ status: "error", message: "Comment not found" });

    const reply = { userId, userName, text, createdAt: new Date() };
    comment.replies.push(reply);

    await post.save();
    res.json({ status: "ok", reply });
  } catch (error) {
    console.error("Reply Error:", error);
    res.status(500).json({ status: "error" });
  }
});

app.delete("/api/community/posts/:postId", async (req, res) => {
  try {
    const { userId } = req.query;
    const post = await Post.findById(req.params.postId);

    if (!post) {
      return res.status(404).json({ status: "error", message: "Post not found" });
    }

    if (post.author.id.toString() !== userId) {
      return res.status(403).json({ status: "error", message: "Not authorized to delete this post" });
    }

    await Post.findByIdAndDelete(req.params.postId);
    await Notification.deleteMany({ postId: req.params.postId });

    res.json({ status: "ok", message: "Post deleted successfully" });
  } catch (error) {
    console.error("Delete Post Error:", error);
    res.status(500).json({ status: "error", message: "Delete failed" });
  }
});

// ====== NOTIFICATION ENDPOINTS ======

app.get("/api/notifications/:userId", async (req, res) => {
  try {
    const notifications = await Notification.find({ recipientId: req.params.userId }).sort({ createdAt: -1 }).limit(20);
    res.json({ status: "ok", notifications });
  } catch (e) {
    console.error("Get Notifications Error:", e);
    res.status(500).json({ status: "error" });
  }
});

app.post("/api/notifications/read", async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ status: "error", message: "userId is required" });
    }
    await Notification.updateMany(
      { recipientId: userId, read: false },
      { $set: { read: true } }
    );
    res.json({ status: "ok", message: "Notifications marked as read" });
  } catch (e) {
    console.error("Mark Notifications Read Error:", e);
    res.status(500).json({ status: "error", message: "Failed to mark notifications as read" });
  }
});

// ====== KNOWLEDGE BASE SETUP ======
const knowledgeBasePath = path.join(__dirname, "data", "knowledgeBase.json");
let knowledgeBase = [];
try {
  if (!fs.existsSync(path.join(__dirname, "data"))) {
    fs.mkdirSync(path.join(__dirname, "data"));
  }
  if (fs.existsSync(knowledgeBasePath)) {
    knowledgeBase = JSON.parse(fs.readFileSync(knowledgeBasePath, "utf-8"));
  }
} catch (e) {
  console.error("[KB ERROR]", e.message);
}

// ====== VOICE ADVISORY ROUTE (Text query → Groq only) ======
async function generateAudioBase64(text) {
  const ttsScript = path.join(__dirname, "tts_script.py");
  const tempId = Math.random().toString(36).substring(7);
  const outPath = path.join(__dirname, "uploads", `tts_${tempId}.mp3`);

  try {
    const command = `python3 "${ttsScript}" "${text.replace(/"/g, '\\"')}" "${outPath}"`;
    await execAsync(command, { cwd: __dirname, timeout: 60000 });
    const audioBytes = fs.readFileSync(outPath);
    const base64Audio = audioBytes.toString('base64');
    fs.unlinkSync(outPath);
    return base64Audio;
  } catch (err) {
    console.error("TTS Error:", err);
    if (fs.existsSync(outPath)) fs.unlinkSync(outPath);
    return null;
  }
}

app.post("/api/voice/query", async (req, res) => {
  try {
    const { query, userId } = req.body;
    if (!query) {
      return res.status(400).json({ status: "error", message: "Query is required" });
    }
    const groqAnswer = await getGroqAnswer(query);
    if (groqAnswer) {
      const audioBase64 = await generateAudioBase64(groqAnswer);
      return res.json({ status: "ok", answer: groqAnswer, source: "groq", audioBase64 });
    }
    const fallbackAnswer = "माफ गर्नुहोला, अहिले सेवा उपलब्ध छैन। कृपया केही समयपछि फेरि प्रयास गर्नुहोस्।";
    const audioBase64 = await generateAudioBase64(fallbackAnswer);
    return res.json({
      status: "ok",
      answer: fallbackAnswer,
      source: "fallback",
      audioBase64
    });
  } catch (error) {
    console.error("Voice Route Error:", error);
    res.status(500).json({ status: "error", message: "Voice processing failed" });
  }
});

app.post("/api/voice/text-query", authenticateToken, async (req, res) => {
  try {
    const { query } = req.body;
    if (!query || query.trim() === "") {
      return res.status(400).json({ status: "error", message: "Query is required" });
    }
    const groqAnswer = await getGroqAnswer(query.trim());
    if (groqAnswer) {
      const audioBase64 = await generateAudioBase64(groqAnswer);
      return res.json({
        status: "ok",
        success: true,
        answer: groqAnswer,
        source: "groq",
        audioBase64
      });
    }
    const fallbackAnswer = "माफ गर्नुहोला, अहिले सेवा उपलब्ध छैन। कृपया केही समयपछि फेरि प्रयास गर्नुहोस्।";
    const audioBase64 = await generateAudioBase64(fallbackAnswer);
    return res.json({
      status: "ok",
      success: true,
      answer: fallbackAnswer,
      source: "fallback",
      audioBase64
    });
  } catch (error) {
    console.error("[text-query ERROR]", error.message);
    res.status(500).json({ status: "error", message: "Voice processing failed" });
  }
});

async function transcribeAudio(filePath) {
  const whisperScript = path.join(__dirname, "whisper_script.py");
  const command = `python3 "${whisperScript}" "${filePath}"`;
  const { stdout } = await execAsync(command, { cwd: __dirname, maxBuffer: 1024 * 1024 * 10, timeout: 60000 });
  return stdout.trim();
}

app.post("/api/voice/audio-query", upload.single("audio"), async (req, res) => {
  let filePath = null;
  try {
    if (!req.file) return res.status(400).json({ status: "error", message: "No audio file uploaded" });
    filePath = req.file.path;
    const recognizedText = await transcribeAudio(filePath);
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

    if (!recognizedText || recognizedText.trim() === "") {
      return res.json({
        status: "error",
        message: "Could not transcribe audio. Please speak clearly and try again."
      });
    }

    const groqAnswer = await getGroqAnswer(recognizedText);
    if (groqAnswer) {
      const audioBase64 = await generateAudioBase64(groqAnswer);
      return res.json({
        status: "ok",
        recognizedText,
        answer: groqAnswer,
        matched: true,
        source: "groq",
        audioBase64
      });
    }
    const fallbackAnswer = "माफ गर्नुहोला, अहिले सेवा उपलब्ध छैन। कृपया केही समयपछि फेरि प्रयास गर्नुहोस्।";
    const audioBase64 = await generateAudioBase64(fallbackAnswer);
    return res.json({
      status: "ok",
      recognizedText,
      answer: fallbackAnswer,
      matched: false,
      source: "fallback",
      audioBase64
    });
  } catch (error) {
    console.error("[VOICE ERROR]", error.message);
    if (filePath && fs.existsSync(filePath)) fs.unlinkSync(filePath);
    return res.status(500).json({ status: "error", message: "Voice processing failed: " + error.message });
  }
});

app.post("/api/user/deactivate", async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ status: "error", message: "userId is required" });
    }
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ status: "error", message: "User not found" });
    }
    await User.findByIdAndDelete(userId);
    await Post.deleteMany({ "author.id": userId });
    await Notification.deleteMany({ recipientId: userId });
    await PasswordReset.deleteMany({ email: user.email });
    res.json({ status: "ok", message: "Account deleted successfully" });
  } catch (error) {
    console.error("Delete Account Error:", error);
    res.status(500).json({ status: "error", message: "Deletion failed" });
  }
});

app.post("/api/password-reset/request", async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.json({ status: "error", message: "Email required" });
    const user = await User.findOne({ email });
    if (!user) return res.json({ status: "ok", message: "If account exists, code sent." });

    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    await PasswordReset.deleteMany({ email, used: false });
    await PasswordReset.create({ email, resetCode, expiresAt, used: false });

    await transporter.sendMail({
      from: `"AgroSetu" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: "AgroSetu - Password Reset Code",
      html: `
      <div style="font-family: Arial, sans-serif; padding: 20px; color: #333; border: 1px solid #e0e0e0; border-radius: 10px;">
        <h2 style="color: #2E7D32;">Password Reset Request</h2>
        <p>You requested a password reset for your AgroSetu account.</p>
        <p>Your 6-digit verification code is:</p>
        <div style="font-size: 32px; font-weight: bold; letter-spacing: 5px; margin: 20px 0; color: #1B5E20;">
          ${resetCode}
        </div>
        <p>This code will expire in <strong>15 minutes</strong>.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
        <p style="font-size: 12px; color: #888;">If you did not request this, please ignore this email.</p>
      </div>`
    });

    res.json({ status: "ok", message: "Reset code sent to your email" });
  } catch (error) {
    console.error("Email dispatch error:", error);
    res.status(500).json({ status: "error", message: "Failed to send reset email" });
  }
});

app.post("/api/password-reset/verify", async (req, res) => {
  try {
    const { email, code, newPassword } = req.body;
    if (!email || !code || !newPassword) {
      return res.status(400).json({ status: "error", message: "Email, code, and new password are required" });
    }
    const passwordCheck = validatePassword(newPassword);
    if (!passwordCheck.isValid) {
      return res.status(400).json({ status: "error", message: passwordCheck.errors[0], errors: passwordCheck.errors });
    }
    const resetRecord = await PasswordReset.findOne({ email, resetCode: code, used: false });
    if (!resetRecord || new Date() > resetRecord.expiresAt) {
      return res.json({ status: "error", message: "Invalid or expired code" });
    }
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ status: "error", message: "User not found" });
    }
    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();
    resetRecord.used = true;
    await resetRecord.save();
    res.json({ status: "ok", message: "Password reset successful" });
  } catch (error) {
    console.error("Password Reset Verify Error:", error);
    res.status(500).json({ status: "error", message: "Verification failed" });
  }
});

// ====== DISEASE HISTORY API ======

app.get("/api/disease-history/:userId", async (req, res) => {
  try {
    const history = await DiseaseHistory.find({ userId: req.params.userId }).sort({ createdAt: -1 });
    res.json({ status: "ok", history });
  } catch (error) {
    console.error("Fetch Disease History Error:", error);
    res.status(500).json({ status: "error", message: "Failed to fetch history" });
  }
});

app.post("/api/disease-history/sync", async (req, res) => {
  try {
    const { userId, detections } = req.body;
    if (!userId || !detections || !Array.isArray(detections)) {
      return res.status(400).json({ status: "error", message: "Invalid payload" });
    }

    const savedRecords = [];
    for (const item of detections) {
      // Prevent duplicates by checking if the exact same prediction exists in close timeframe
      // Or just simply save them since it's driven by the client sync
      const record = await DiseaseHistory.create({
        userId,
        disease: item.disease,
        confidence: item.confidence,
        solutions: item.solutions || [],
        createdAt: item.date ? new Date(item.date) : new Date()
      });
      savedRecords.push(record);
    }

    res.json({ status: "ok", message: "History synced successfully", savedCount: savedRecords.length });
  } catch (error) {
    console.error("Sync Disease History Error:", error);
    res.status(500).json({ status: "error", message: "Failed to sync history" });
  }
});

async function startServer() {
  const PORT = process.env.PORT || 3000;
  const HOST = '0.0.0.0';

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const { createServer: createViteServer } = await import("vite");
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  server.listen(PORT, HOST, () => {
    console.log("=".repeat(50));
    console.log(`🚀 Server running on PORT: ${PORT}`);
    console.log(`🌐 Accessible on: http://${HOST}:${PORT}`);
    console.log("=".repeat(50));
  });
}

startServer();

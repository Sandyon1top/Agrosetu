const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const axios = require("axios"); // ADDED for weather API
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
  .then(() => console.log("[DB] MongoDB Connected"))
  .catch((err) => console.log("[DB ERROR] MongoDB Error:", err));

// ====== USER SCHEMA ======
const UserSchema = new mongoose.Schema({
  name: String,
  email: { type: String, unique: true },
  password: String,
});

const User = mongoose.model("users", UserSchema);

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
  data: Object,
  expiresAt: Date,
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

const WeatherCache = mongoose.model("weather_cache", WeatherCacheSchema);

// ====== COMMUNITY POST SCHEMA ======
const PostSchema = new mongoose.Schema({
  title: String,
  description: String,
  category: String,
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
      createdAt: { type: Date, default: Date.now },
    },
  ],
  solved: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

const Post = mongoose.model("posts", PostSchema);

// ====== HELPER FUNCTIONS ======
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
      sunriseEpoch: response.data.sys ? response.data.sys.sunrise : null,
      sunsetEpoch: response.data.sys ? response.data.sys.sunset : null,
      timezoneOffset: response.data.timezone || 0,
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
    
    console.log('[WEATHER] Weather data fetched and cached');
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
  console.log("[SIGNUP] Request for:", req.body.email);
  
  try {
    const { name, email, password } = req.body;
    
    // Validate inputs
    if (!name || !email || !password) {
      console.log("[SIGNUP ERROR] Missing required fields");
      return res.json({ 
        status: "error", 
        message: "Name, email, and password are required" 
      });
    }
    
    // Validate password strength
    const passwordValidation = validatePassword(password);
    if (!passwordValidation.isValid) {
      console.log("[SIGNUP ERROR] Weak password:", passwordValidation.errors);
      return res.json({ 
        status: "error", 
        message: "Password does not meet requirements",
        errors: passwordValidation.errors
      });
    }
    
    console.log("[SIGNUP] Checking if user exists:", email);
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      console.log("[SIGNUP ERROR] Email already registered:", email);
      return res.json({ 
        status: "error", 
        message: "Email already registered" 
      });
    }
    
    console.log("[SIGNUP] Hashing password...");
    const hashedPassword = await bcrypt.hash(password, 10);
    
    console.log("[SIGNUP] Creating user in database...");
    const user = await User.create({
      name,
      email,
      password: hashedPassword
    });
    
    console.log("[SIGNUP SUCCESS] User created:", {
      id: user._id,
      name: user.name,
      email: user.email
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
    console.error("❌ Signup error:", error.message);
    console.error("Stack:", error.stack);
    res.status(500).json({
      status: "error",
      message: "Registration failed: " + error.message
    });
  }
});

// Login endpoint
app.post("/login", async (req, res) => {
  console.log("[LOGIN] Request for:", req.body.email);
  
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      console.log("[LOGIN ERROR] Missing email or password");
      return res.json({
        status: "error",
        message: "Email and password are required"
      });
    }
    
    console.log("[LOGIN] Looking up user:", email);
    const user = await User.findOne({ email });
    if (!user) {
      console.log("[LOGIN ERROR] User not found:", email);
      return res.json({
        status: "error",
        message: "User not found"
      });
    }
    
    console.log("[LOGIN] Validating password for:", email);
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      console.log("[LOGIN ERROR] Invalid password for:", email);
      return res.json({
        status: "error", 
        message: "Invalid password"
      });
    }
    
    console.log("[LOGIN] Password valid, generating token...");
    const token = jwt.sign(
      { userId: user._id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );
    
    console.log("[LOGIN SUCCESS] Successful for:", {
      id: user._id,
      name: user.name,
      email: user.email,
      token: token.substring(0, 20) + "..."
    });
    
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
    console.error("❌ Login error:", error.message);
    console.error("Stack:", error.stack);
    res.status(500).json({
      status: "error",
      message: "Login failed: " + error.message
    });
  }
});

// ====== COMMUNITY POSTS ROUTES ======

// Get all posts (with filtering)
app.get("/api/community/posts", async (req, res) => {
  try {
    const { category, limit = 50, page = 1 } = req.query;
    
    let query = {};
    if (category && category !== 'All') {
      query.category = category;
    }
    
    const skip = (page - 1) * limit;
    
    const posts = await Post.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));
    
    const total = await Post.countDocuments(query);
    
    res.json({
      status: "ok",
      posts: posts.map(post => ({
        id: post._id,
        title: post.title,
        description: post.description,
        category: post.category,
        author: post.author,
        likes: post.likes.length,
        liked: false, // Will be set on client based on user ID
        comments: post.comments.length,
        solved: post.solved,
        createdAt: post.createdAt,
        timestamp: getTimeAgo(post.createdAt),
      })),
      total: total,
      page: page,
      hasMore: skip + posts.length < total,
    });
  } catch (error) {
    console.error("Error fetching posts:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to fetch posts"
    });
  }
});

// Get single post with comments
app.get("/api/community/posts/:postId", async (req, res) => {
  try {
    const post = await Post.findById(req.params.postId);
    
    if (!post) {
      return res.json({
        status: "error",
        message: "Post not found"
      });
    }
    
    res.json({
      status: "ok",
      post: {
        id: post._id,
        title: post.title,
        description: post.description,
        category: post.category,
        author: post.author,
        likes: post.likes.length,
        comments: post.comments,
        solved: post.solved,
        createdAt: post.createdAt,
      }
    });
  } catch (error) {
    console.error("Error fetching post:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to fetch post"
    });
  }
});

// Create a new post
app.post("/api/community/posts", async (req, res) => {
  console.log("[POST] New post from:", req.body.author?.email);
  
  try {
    const { title, description, category, author } = req.body;
    
    if (!title || !description || !category || !author) {
      return res.json({
        status: "error",
        message: "Missing required fields"
      });
    }
    
    const post = await Post.create({
      title,
      description,
      category,
      author: {
        id: author.id,
        name: author.name,
        email: author.email,
      },
      likes: [],
      comments: [],
      solved: false,
    });
    
    res.json({
      status: "ok",
      message: "Post created successfully",
      post: {
        id: post._id,
        title: post.title,
        description: post.description,
        category: post.category,
        author: post.author,
        likes: 0,
        comments: 0,
        solved: false,
        createdAt: post.createdAt,
      }
    });
  } catch (error) {
    console.error("Post creation error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to create post"
    });
  }
});

// Like a post
app.post("/api/community/posts/:postId/like", async (req, res) => {
  try {
    const { userId } = req.body;
    const post = await Post.findById(req.params.postId);
    
    if (!post) {
      return res.json({
        status: "error",
        message: "Post not found"
      });
    }
    
    const likeIndex = post.likes.indexOf(userId);
    if (likeIndex === -1) {
      post.likes.push(userId);
    } else {
      post.likes.splice(likeIndex, 1);
    }
    
    await post.save();
    
    res.json({
      status: "ok",
      message: "Post like toggled",
      likes: post.likes.length,
      liked: post.likes.includes(userId)
    });
  } catch (error) {
    console.error("Like error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to like post"
    });
  }
});

// Add comment to post
app.post("/api/community/posts/:postId/comments", async (req, res) => {
  try {
    const { userId, userName, userEmail, text } = req.body;
    const post = await Post.findById(req.params.postId);
    
    if (!post) {
      return res.json({
        status: "error",
        message: "Post not found"
      });
    }
    
    const comment = {
      userId,
      userName,
      userEmail,
      text,
      createdAt: new Date(),
    };
    
    post.comments.push(comment);
    await post.save();
    
    res.json({
      status: "ok",
      message: "Comment added successfully",
      comment: comment
    });
  } catch (error) {
    console.error("Comment error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to add comment"
    });
  }
});

// Delete post
app.delete("/api/community/posts/:postId", async (req, res) => {
  try {
    const { userId } = req.body;
    const post = await Post.findById(req.params.postId);
    
    if (!post) {
      return res.json({
        status: "error",
        message: "Post not found"
      });
    }
    
    // Check if user is post author
    if (post.author.id.toString() !== userId) {
      return res.json({
        status: "error",
        message: "Unauthorized to delete this post"
      });
    }
    
    await Post.findByIdAndDelete(req.params.postId);
    
    res.json({
      status: "ok",
      message: "Post deleted successfully"
    });
  } catch (error) {
    console.error("Delete error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to delete post"
    });
  }
});

// ====== PASSWORD RESET ENDPOINTS ======

// Request Password Reset - Generate reset code
app.post("/api/password-reset/request", async (req, res) => {
  console.log("[PASSWORD RESET] Request for:", req.body.email);
  
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.json({
        status: "error",
        message: "Email is required"
      });
    }
    
    // Check if user exists
    const user = await User.findOne({ email });
    if (!user) {
      // Don't reveal if user exists for security, but log it
      console.log("[PASSWORD RESET ERROR] User does not exist:", email);
      // Return success even if user doesn't exist (security best practice)
      return res.json({
        status: "ok",
        message: "If this email exists, a reset code has been sent"
      });
    }
    
    console.log("[PASSWORD RESET] User found:", email);
    
    // Generate 6-digit reset code
    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
    
    // Clear any existing reset codes for this email
    await PasswordReset.deleteMany({ email, used: false });
    
    // Create new reset code
    const resetRecord = new PasswordReset({
      email,
      resetCode,
      expiresAt,
      used: false
    });
    
    await resetRecord.save();
    
    console.log("[PASSWORD RESET SUCCESS] Code generated for:", email);
    console.log("[PASSWORD RESET] Dev code:", resetCode);
    
    // In development, return the code in response (remove in production!)
    res.json({
      status: "ok",
      message: "Reset code sent to your email",
      // For testing/development only - remove in production
      _devCode: resetCode
    });
    
  } catch (error) {
    console.error("Password reset request error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to process password reset request"
    });
  }
});

// Verify reset code and reset password
app.post("/api/password-reset/verify", async (req, res) => {
  console.log("[PASSWORD RESET VERIFY] For:", req.body.email);
  
  try {
    const { email, code, newPassword } = req.body;
    
    if (!email || !code || !newPassword) {
      return res.json({
        status: "error",
        message: "Email, code, and password are required"
      });
    }
    
    // Validate password strength
    const passwordValidation = validatePassword(newPassword);
    if (passwordValidation.errors.length > 0) {
      return res.json({
        status: "error",
        message: "Password does not meet security requirements",
        errors: passwordValidation.errors
      });
    }
    
    // Find valid reset code
    const resetRecord = await PasswordReset.findOne({
      email,
      resetCode: code,
      used: false
    });
    
    if (!resetRecord) {
      console.log("[PASSWORD RESET ERROR] Invalid or expired code for:", email);
      return res.json({
        status: "error",
        message: "Invalid or expired reset code"
      });
    }
    
    // Check if code has expired
    if (new Date() > resetRecord.expiresAt) {
      console.log("[PASSWORD RESET ERROR] Code expired for:", email);
      await PasswordReset.deleteOne({ _id: resetRecord._id });
      return res.json({
        status: "error",
        message: "Reset code has expired. Please request a new one"
      });
    }
    
    // Hash new password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);
    
    // Update user password
    const user = await User.findOne({ email });
    if (!user) {
      return res.json({
        status: "error",
        message: "User not found"
      });
    }
    
    user.password = hashedPassword;
    await user.save();
    
    // Mark reset code as used
    resetRecord.used = true;
    await resetRecord.save();
    
    console.log("[PASSWORD RESET SUCCESS] Password updated for:", email);
    
    res.json({
      status: "ok",
      message: "Password reset successfully"
    });
    
  } catch (error) {
    console.error("Password reset verification error:", error);
    res.status(500).json({
      status: "error",
      message: "Failed to reset password"
    });
  }
});

// Helper function to format time
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

// ====== START SERVER ======
const PORT = process.env.PORT || 5001;
const HOST = '0.0.0.0';

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
  console.log(`   GET  http://localhost:${PORT}/api/weather/current`);
  console.log(`   GET  http://localhost:${PORT}/api/weather/hourly`);
  console.log(`   POST http://localhost:${PORT}/signup`);
  console.log(`   POST http://localhost:${PORT}/login`);  console.log(`   POST http://localhost:${PORT}/api/password-reset/request`);
  console.log(`   POST http://localhost:${PORT}/api/password-reset/verify`);  console.log(`   GET  http://localhost:${PORT}/api/community/posts`);
  console.log(`   GET  http://localhost:${PORT}/api/community/posts/:postId`);
  console.log(`   POST http://localhost:${PORT}/api/community/posts`);
  console.log(`   POST http://localhost:${PORT}/api/community/posts/:postId/like`);
  console.log(`   POST http://localhost:${PORT}/api/community/posts/:postId/comments`);
  console.log(`   DELETE http://localhost:${PORT}/api/community/posts/:postId`);
  console.log("=".repeat(50));
  console.log("\n🔑 Weather API configured");
  console.log("📝 Add to .env: OPENWEATHER_API_KEY=your_key_here");
  console.log("=".repeat(50));
});
# AgroSetu 🌾

An AI-powered smart farming mobile application built with Flutter, Node.js, and Flask.

## Features
- Crop disease detection using ensemble deep learning (MobileNetV2, EfficientNetB0, CNN)
- Real-time weather forecasting with farming tips
- AI voice assistant powered by Groq LLaMA-3
- Community forum for farmers
- Market analytics and price trends
- Multilingual support (English / Nepali)
- Admin panel for platform management

## Tech Stack
- **Mobile:** Flutter (Dart)
- **Backend:** Node.js + Express + MongoDB Atlas
- **ML Server:** Python Flask + PyTorch
- **AI:** Groq LLaMA-3, OpenWeatherMap API

## Setup

### Backend
```bash
cd backend
npm install
node server.js
```

### Flask ML Server
```bash
cd Flask
python3 -m venv venv
venv/bin/pip install -r requirements.txt
venv/bin/python app.py
```

### Flutter App
```bash
cd agrosetu_app
flutter pub get
flutter run
```

## Environment Variables
Copy `backend/.env.example` to `backend/.env` and fill in your keys.

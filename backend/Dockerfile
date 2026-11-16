FROM node:20-slim

WORKDIR /app

# Install system dependencies (including Python and ffmpeg for audio/whisper if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy package definitions
COPY package.json package-lock.json* ./

# Use npm install instead of npm ci to avoid package-lock version mismatch failures
RUN npm install --omit=dev

# Copy application files
COPY server.js ./
COPY admin/ ./admin/
COPY data/ ./data/
COPY tts_script.py ./
COPY whisper_script.py ./

# Create uploads directory for audio and temporary file processing
RUN mkdir -p uploads

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["node", "server.js"]

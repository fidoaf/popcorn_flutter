FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
  chromium \
  ca-certificates \
  libnss3 libxss1 libasound2 libatk-bridge2.0-0 libatk1.0-0 \
  libcups2 libdrm2 libgbm1 libxrandr2 libxshmfence1 libxcomposite1 \
  libxdamage1 libxfixes3 libxext6 libx11-6 libxcb1 libx11-xcb1 \
  libglib2.0-0 libpango-1.0-0 libpangocairo-1.0-0 \
  fonts-liberation \
  && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production \
    PORT=3000 \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CHROME_BIN=/usr/bin/chromium

WORKDIR /app
COPY package*.json ./
RUN yarn install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
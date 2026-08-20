const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

const PORT = process.env.PORT || 8080;

const CATALOG_URL =
  process.env.CATALOG_URL || 'http://localhost:8081';

const AUTH_URL =
  process.env.AUTH_URL || 'http://localhost:8082';

const BOOKING_URL =
  process.env.BOOKING_URL || 'http://localhost:8083';

const AI_INSIGHT_URL =
  process.env.AI_INSIGHT_URL || 'http://localhost:8084';

const ANALYTICS_URL =
  process.env.ANALYTICS_URL || 'http://localhost:8085';

app.use(cors());

app.use(
  createProxyMiddleware({
    target: CATALOG_URL,
    changeOrigin: true,
    pathFilter: '/api/catalog',
  })
);

app.use(
  createProxyMiddleware({
    target: AUTH_URL,
    changeOrigin: true,
    pathFilter: '/api/auth',
  })
);

app.use(
  createProxyMiddleware({
    target: BOOKING_URL,
    changeOrigin: true,
    pathFilter: '/api/bookings',
  })
);

app.use(
  createProxyMiddleware({
    target: AI_INSIGHT_URL,
    changeOrigin: true,
    pathFilter: '/api/analyze',
  })
);

app.use(
  createProxyMiddleware({
    target: ANALYTICS_URL,
    changeOrigin: true,
    pathFilter: '/api/analytics',
  })
);

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`API Gateway running on port ${PORT}`);
  console.log(`CATALOG_URL=${CATALOG_URL}`);
  console.log(`AUTH_URL=${AUTH_URL}`);
  console.log(`BOOKING_URL=${BOOKING_URL}`);
  console.log(`AI_INSIGHT_URL=${AI_INSIGHT_URL}`);
  console.log(`ANALYTICS_URL=${ANALYTICS_URL}`);
});
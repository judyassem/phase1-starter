const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

app.use(cors());

// app.use(
//   '/api/auth',
//   createProxyMiddleware({
//     target: process.env.AUTH_SERVICE_URL || 'http://auth:8082',
//     changeOrigin: true,
//     pathRewrite: () => `/api/auth`,
//   })
// );

// app.use(
//   '/api/catalog',
//   createProxyMiddleware({
//     target: process.env.CATALOG_SERVICE_URL || 'http://catalog:8081',
//     changeOrigin: true,
//     pathRewrite: () => `/api/catalog`,
//   })
// );

// app.use(
//   '/api/bookings',
//   createProxyMiddleware({
//     target: process.env.BOOKING_SERVICE_URL || 'http://booking:8083',
//     changeOrigin: true,
//     pathRewrite: () => `/api/bookings/`,
//   })
// );

app.use(
  '/api/auth',
  createProxyMiddleware({
    target: process.env.AUTH_SERVICE_URL || 'http://auth:8082',
    changeOrigin: true,
    pathRewrite: (path) => `/api/auth${path === '/' ? '' : path}`,
  })
);

app.use(
  '/api/catalog',
  createProxyMiddleware({
    target: process.env.CATALOG_SERVICE_URL || 'http://catalog:8081',
    changeOrigin: true,
    pathRewrite: (path) => `/api/catalog${path === '/' ? '' : path}`,
  })
);

app.use(
  '/api/bookings',
  createProxyMiddleware({
    target: process.env.BOOKING_SERVICE_URL || 'http://booking:8083',
    changeOrigin: true,
    pathRewrite: (path) => `/api/bookings${path === '/' ? '' : path}`,
  })
);

app.use(
  '/api/reviews',
  createProxyMiddleware({
    target: process.env.BOOKING_SERVICE_URL || 'http://booking:8083',
    changeOrigin: true,
    pathRewrite: (path) => `/api/reviews${path === '/' ? '' : path}`,
  })
);

app.use(
  '/api/analytics/summary',
  createProxyMiddleware({
    target: process.env.ANALYTICS_SERVICE_URL || 'http://analytics:8085',
    changeOrigin: true,
    pathRewrite: () => '/api/analytics/summary',
  })
);

app.use(
  '/api/analyze',
  createProxyMiddleware({
    target: process.env.AI_INSIGHT_SERVICE_URL || 'http://ai-insight:8084',
    changeOrigin: true,
    pathRewrite: () => `/api/analyze`,
  })
);

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(8080, () => {
  console.log('API Gateway running on port 8080');
});
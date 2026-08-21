{
    const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

app.use(cors());

// Auth service
app.use(
  '/api/auth',
  createProxyMiddleware({
    target: 'http://localhost:8082',
    changeOrigin: true,
  })
);

// Catalog service
app.use(
  '/api/catalog',
  createProxyMiddleware({
    target: 'http://localhost:8081',
    changeOrigin: true,
  })
);

// Booking service
app.use(
  '/api/bookings',
  createProxyMiddleware({
    target: 'http://localhost:8083',
    changeOrigin: true,
  })
);

// Analytics service
app.use(
  '/api/analytics/summary',
  createProxyMiddleware({
    target: 'http://localhost:8085',
    changeOrigin: true,
  })
);

//ai service
app.use(
  '/api/analyze',
  createProxyMiddleware({
    target: 'http://localhost:8084',
    changeOrigin: true,
  })
);

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(8080, () => {
  console.log('API Gateway running on http://localhost:8080');
});
}
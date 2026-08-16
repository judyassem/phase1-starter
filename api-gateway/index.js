const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

app.use(cors());

app.use(
  createProxyMiddleware({
    target: 'http://localhost:8081',
    changeOrigin: true,
    pathFilter: '/api/catalog',
  })
);

app.use(
  createProxyMiddleware({
    target: 'http://localhost:8082',
    changeOrigin: true,
    pathFilter: '/api/auth',
  })
);

app.use(
  createProxyMiddleware({
    target: 'http://localhost:8083',
    changeOrigin: true,
    pathFilter: '/api/bookings',
  })
);

app.use(
  createProxyMiddleware({
    target: 'http://localhost:8084',
    changeOrigin: true,
    pathFilter: '/api/analyze',
  })
);

app.use(
  createProxyMiddleware({
    target: 'http://localhost:8085',
    changeOrigin: true,
    pathFilter: '/api/analytics',
  })
);

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(8080, () => {
  console.log('API Gateway running on http://localhost:8080');
});
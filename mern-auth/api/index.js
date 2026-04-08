import express from 'express';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import userRoutes from './routes/user.route.js';
import authRoutes from './routes/auth.route.js';
import cookieParser from 'cookie-parser';
import path from 'path';
import promBundle from 'express-prom-bundle';
import promClient from 'prom-client';
dotenv.config();

mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
  })
  .catch((err) => {
    console.log(err);
  });

const __dirname = path.resolve();

const app = express();

// ── Prometheus Observability ──────────────────────────────────────────────────
// Collects default Node.js process metrics (heap, CPU, event-loop lag, etc.)
promClient.collectDefaultMetrics({ prefix: 'mern_auth_' });

// Auto-instruments all routes with http_request_duration_seconds histogram
// and http_requests_total counter. Exposes GET /metrics for Prometheus scraping.
const metricsMiddleware = promBundle({
  includeMethod: true,
  includePath: true,
  includeStatusCode: true,
  includeUp: true,
  customLabels: { app: 'mern-auth', env: process.env.NODE_ENV || 'production' },
  promClient: { collectDefaultMetrics: {} },
  metricsPath: '/metrics',
});
app.use(metricsMiddleware);
// ─────────────────────────────────────────────────────────────────────────────

app.use(express.json());
app.use(cookieParser());

app.use('/api/user', userRoutes);
app.use('/api/auth', authRoutes);

app.use(express.static(path.join(__dirname, '/client/dist')));

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'client', 'dist', 'index.html'));
});

app.use((err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';
  return res.status(statusCode).json({
    success: false,
    message,
    statusCode,
  });
});

app.listen(9191, () => {
  console.log('Server listening on port 9191');
});

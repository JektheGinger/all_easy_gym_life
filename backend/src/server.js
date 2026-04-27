require('dotenv').config();

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
const port = Number(process.env.PORT || 3000);

function requireEnv(name) {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'app_user',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'gim_access',
};

const jwtConfig = {
  secret: requireEnv('JWT_SECRET'),
  expiresIn: process.env.JWT_EXPIRES_IN || '1h',
  issuer: process.env.JWT_ISSUER || 'egl-auth-service',
};

const pool = new Pool({
  ...dbConfig,
  max: 10,
  idleTimeoutMillis: 30000,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

app.use(
  cors({
    origin: process.env.CLIENT_ORIGIN || true,
  }),
);
app.use(morgan('dev'));
app.use(express.json());

app.get('/', (_req, res) => {
  res
    .status(200)
    .type('html')
    .send(`
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>Easy Gym Life (EGL) Backend</title>
          <style>
            body {
              margin: 0;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              background: linear-gradient(180deg, #041611 0%, #0b231c 100%);
              color: #e8fff0;
            }
            .wrap {
              max-width: 780px;
              margin: 0 auto;
              padding: 48px 24px 64px;
            }
            .card {
              background: rgba(21, 42, 35, 0.92);
              border: 1px solid #315347;
              border-radius: 20px;
              padding: 24px;
              box-shadow: 0 20px 50px rgba(0, 0, 0, 0.25);
            }
            h1 {
              margin-top: 0;
              font-size: 34px;
            }
            p, li {
              line-height: 1.6;
              color: #c9ded1;
            }
            code {
              background: #10211c;
              padding: 2px 8px;
              border-radius: 8px;
              color: #7be6a5;
            }
            a {
              color: #8fd8ff;
            }
          </style>
        </head>
        <body>
          <div class="wrap">
            <div class="card">
              <h1>Easy Gym Life (EGL) Backend Is Running</h1>
              <p>
                This Express server is the backend API for the Flutter app. It handles
                authentication, JWTs, database access, and future analytics or
                camera/vision processing.
              </p>
              <p>
                This page is only a backend status page. The actual app interface is
                launched separately with <code>flutter run</code>.
              </p>
              <p>Useful endpoints:</p>
              <ul>
                <li><code>GET /api/health</code></li>
                <li><code>POST /api/auth/login</code></li>
                <li><code>GET /api/auth/me</code></li>
              </ul>
              <p>Recommended local workflow:</p>
              <ul>
                <li>Terminal 1: <code>npm run dev</code></li>
                <li>Terminal 2: <code>flutter run</code></li>
              </ul>
            </div>
          </div>
        </body>
      </html>
    `);
});

app.get('/api/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');

    res.status(200).json({
      status: 'ok',
      api: 'easy-gym-life-backend',
      database: 'connected',
    });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(500).json({
      status: 'error',
      api: 'easy-gym-life-backend',
      database: 'unreachable',
    });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      message: 'Email and password are required.',
    });
  }

  try {
    const { rows } = await pool.query(
      `
        SELECT id, email, password_hash, role, display_name, is_active
        FROM app_user
        WHERE email = $1
        LIMIT 1
      `,
      [email.trim().toLowerCase()],
    );

    if (rows.length === 0) {
      return res.status(401).json({
        message: 'Invalid email or password.',
      });
    }

    const user = rows[0];

    if (!user.is_active) {
      return res.status(403).json({
        message: 'This account is inactive.',
      });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password_hash);

    if (!isPasswordValid) {
      return res.status(401).json({
        message: 'Invalid email or password.',
      });
    }

    const token = jwt.sign(
      {
        sub: String(user.id),
        email: user.email,
        role: user.role,
      },
      jwtConfig.secret,
      {
        expiresIn: jwtConfig.expiresIn,
        issuer: jwtConfig.issuer,
      },
    );

    return res.status(200).json({
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        displayName: user.display_name,
      },
    });
  } catch (error) {
    console.error('Login failed:', error);
    return res.status(500).json({
      message: 'Unable to complete login.',
    });
  }
});

app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `
        SELECT id, email, role, display_name, is_active
        FROM app_user
        WHERE id = $1
        LIMIT 1
      `,
      [req.user.sub],
    );

    if (rows.length === 0 || !rows[0].is_active) {
      return res.status(404).json({
        message: 'User not found.',
      });
    }

    const user = rows[0];

    return res.status(200).json({
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        displayName: user.display_name,
      },
    });
  } catch (error) {
    console.error('Profile lookup failed:', error);
    return res.status(500).json({
      message: 'Unable to load user profile.',
    });
  }
});

function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization || '';

  if (!authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      message: 'Bearer token required.',
    });
  }

  const token = authHeader.replace('Bearer ', '').trim();

  try {
    const decoded = jwt.verify(token, jwtConfig.secret, {
      issuer: jwtConfig.issuer,
    });

    req.user = decoded;
    return next();
  } catch (error) {
    return res.status(403).json({
      message: 'Invalid or expired token.',
    });
  }
}

app.use((req, res) => {
  res.status(404).json({
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

app.listen(port, () => {
  console.log(`Easy Gym Life (EGL) backend running on http://localhost:${port}`);
});

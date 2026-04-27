require('dotenv').config();

const { Client } = require('pg');
const bcrypt = require('bcryptjs');

async function seed() {
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER || 'app_user',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'gim_access',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  });
  await client.connect();

  const users = [
    {
      email: 'owner@iron-temple.com',
      password: 'Business123!',
      role: 'business',
      displayName: 'Iron Temple Admin',
    },
    {
      email: 'ops@fitdistrict.io',
      password: 'Business123!',
      role: 'business',
      displayName: 'Fit District Operations',
    },
    {
      email: 'member@easygymlife.app',
      password: 'EGLUser123!',
      role: 'gim',
      displayName: 'Jordan Member',
    },
    {
      email: 'welcome@easygymlife.app',
      password: 'EGLUser123!',
      role: 'gim',
      displayName: 'Taylor Welcome',
    },
  ];

  for (const user of users) {
    const passwordHash = await bcrypt.hash(user.password, 10);

    await client.query(
      `
        INSERT INTO app_user (email, password_hash, role, display_name, is_active)
        VALUES ($1, $2, $3, $4, TRUE)
        ON CONFLICT (email) DO UPDATE
        SET
          password_hash = EXCLUDED.password_hash,
          role = EXCLUDED.role,
          display_name = EXCLUDED.display_name,
          is_active = EXCLUDED.is_active
      `,
      [user.email, passwordHash, user.role, user.displayName],
    );
  }

  await client.end();
  console.log('Demo users seeded successfully.');
}

seed().catch((error) => {
  console.error('Failed to seed demo users:', error);
  process.exit(1);
});

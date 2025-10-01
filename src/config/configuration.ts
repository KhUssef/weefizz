// config/configuration.ts
export default () => ({
  port: parseInt(process.env.PORT || '3000', 10),

  db: {
    host: process.env.DATABASE_HOST,
    port: parseInt(process.env.DATABASE_PORT || '3306', 10),
    username: process.env.DATABASE_USERNAME || 'newuser',
    password: process.env.DATABASE_PASSWORD || 'password',
    database: process.env.DATABASE_NAME || 'project',
  },

  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || 'defaultAccessSecret',
    accessExpires: process.env.JWT_ACCESS_EXPIRES || '15m',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'defaultRefreshSecret',
    refreshExpires: process.env.JWT_REFRESH_EXPIRES || '7d',
  },
});

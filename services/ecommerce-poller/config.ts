export const config = {
  MONGODB_URI: process.env.MONGODB_URI || 'mongodb://localhost:27017',
  R2_ENDPOINT: process.env.R2_ENDPOINT || '',
  R2_ACCESS_KEY: process.env.R2_ACCESS_KEY || '',
  R2_SECRET_KEY: process.env.R2_SECRET_KEY || '',
  R2_BUCKET: process.env.R2_BUCKET || 'baidaohui',
}; 
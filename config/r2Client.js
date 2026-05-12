const { S3Client } = require("@aws-sdk/client-s3");

const r2Client = new S3Client({
  region: "us-east-1", // More compatible than "auto" for some environments
  endpoint: (process.env.R2_ENDPOINT || "").replace(/\/$/, ""), // Strip trailing slash
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  },
  forcePathStyle: true,
});

module.exports = r2Client;

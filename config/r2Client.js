const { S3Client } = require("@aws-sdk/client-s3");
const { NodeHttpHandler } = require("@smithy/node-http-handler");
const https = require("https");

// Validate required environment variables at startup
const R2_ENDPOINT = (process.env.R2_ENDPOINT || "").replace(/\/$/, "");
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY;

if (!R2_ENDPOINT || R2_ENDPOINT.includes(process.env.R2_AccountID)) {
  console.warn(
    "⚠️  R2_ENDPOINT is not configured. Profile picture uploads will fail.\n" +
    "   Set R2_ENDPOINT in your .env file to: https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
  );
}

if (!R2_ACCESS_KEY_ID || R2_ACCESS_KEY_ID === process.env.R2_SECRET_ACCESS_KEY) {
  console.warn("⚠️  R2_ACCESS_KEY_ID is not configured. Set it in your .env file.");
}

// Create a custom HTTPS agent that handles Cloudflare R2's TLS negotiation
// Node.js 22+ (OpenSSL 3.x) enforces stricter SSL defaults that can conflict
// with R2's S3-compatible endpoint during the handshake.
const agent = new https.Agent({
  // Allow TLS 1.2+ (R2 supports TLS 1.2 and 1.3)
  minVersion: "TLSv1.2",
  // Broaden the cipher list to include ciphers R2 accepts
  ciphers: [
    "TLS_AES_128_GCM_SHA256",
    "TLS_AES_256_GCM_SHA384",
    "TLS_CHACHA20_POLY1305_SHA256",
    "ECDHE-RSA-AES128-GCM-SHA256",
    "ECDHE-RSA-AES256-GCM-SHA384",
    "ECDHE-ECDSA-AES128-GCM-SHA256",
    "ECDHE-ECDSA-AES256-GCM-SHA384",
    "DHE-RSA-AES128-GCM-SHA256",
    "DHE-RSA-AES256-GCM-SHA384",
  ].join(":"),
  rejectUnauthorized: true, // Keep SSL verification ON for security
});

const r2Client = new S3Client({
  region: "auto",
  endpoint: R2_ENDPOINT,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID || "",
    secretAccessKey: R2_SECRET_ACCESS_KEY || "",
  },
  forcePathStyle: true,
  requestHandler: new NodeHttpHandler({
    httpsAgent: agent,
    connectionTimeout: 10000,
    socketTimeout: 30000,
  }),
});

module.exports = r2Client;

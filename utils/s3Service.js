const { PutObjectCommand, DeleteObjectCommand } = require("@aws-sdk/client-s3");
const r2 = require("../config/r2Client");
const path = require("path");
const crypto = require("crypto");

/**
 * Upload a file to Cloudflare R2
 * @param {Buffer} buffer 
 * @param {string} originalName 
 * @param {string} folder 
 * @returns {Promise<string>} Filename
 */
const uploadToR2 = async (buffer, originalName, folder = "profiles") => {
  const extension = path.extname(originalName);
  const fileName = `${folder}/${crypto.randomBytes(16).toString("hex")}${extension}`;

  await r2.send(
    new PutObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME || process.env.R2_BUCKET,
      Key: fileName,
      Body: buffer,
      ContentType: getContentType(extension),
    }),
  );

  return fileName;
};

/**
 * Delete a file from Cloudflare R2
 * @param {string} key 
 */
const deleteFromR2 = async (key) => {
  if (!key) return;
  
  try {
    await r2.send(
      new DeleteObjectCommand({
        Bucket: process.env.R2_BUCKET_NAME || process.env.R2_BUCKET,
        Key: key,
      }),
    );
  } catch (error) {
    console.error("Failed to delete from R2:", error);
  }
};

const getContentType = (ext) => {
  const types = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
  };
  return types[ext.toLowerCase()] || "application/octet-stream";
};

module.exports = {
  uploadToR2,
  deleteFromR2,
};

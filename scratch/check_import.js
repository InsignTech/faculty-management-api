try {
    const app = require('../app');
    console.log("Backend app.js imported successfully!");
} catch (e) {
    console.error("Error importing app.js:", e);
}
process.exit(0);

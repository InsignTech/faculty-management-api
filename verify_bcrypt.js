const bcrypt = require('bcryptjs');

const oldPassword = '09h19kqg';
const dbHash = '$2b$10$j6.HSyjzqtR8BT.DHaVQM.AgS.SGgM3h327L/2ZJ2wzVv8GEtZ77W';

async function verify() {
    const isMatch = await bcrypt.compare(oldPassword, dbHash);
    console.log(`Password: ${oldPassword}`);
    console.log(`Hash: ${dbHash}`);
    console.log(`Match Result: ${isMatch}`);
}

verify();

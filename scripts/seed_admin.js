/**
 * Nizhal - Firebase Admin SDK One-time Script to Seed the First Admin Account
 * 
 * Instructions:
 * 1. Download your service account key JSON from Firebase Console -> Project Settings -> Service accounts.
 * 2. Save it as `serviceAccountKey.json` in the root of this project.
 * 3. Run: `node scripts/seed_admin.js <email> <password> <displayName>`
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('\x1b[31mError: serviceAccountKey.json not found in the root of the project.\x1b[0m');
  console.error('Please download it from the Firebase Console and place it at:');
  console.error(serviceAccountPath);
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

const args = process.argv.slice(2);
if (args.length < 2) {
  console.log('\x1b[33mUsage: node scripts/seed_admin.js <email> <password> [displayName]\x1b[0m');
  process.exit(1);
}

const email = args[0];
const password = args[1];
const displayName = args[2] || 'System Administrator';

async function seedAdmin() {
  try {
    console.log(`Attempting to create admin account for email: ${email}...`);

    // 1. Create user in Firebase Authentication
    const userRecord = await auth.createUser({
      email: email,
      emailVerified: true,
      password: password,
      displayName: displayName,
      disabled: false
    });

    console.log(`\x1b[32mAuth user created successfully with UID: ${userRecord.uid}\x1b[0m`);

    // 2. Set Admin Role custom claim (optional, but good practice for API/Rules verification)
    await auth.setCustomUserClaims(userRecord.uid, { role: 'admin' });
    console.log('Custom claims configured for "admin" role.');

    // 3. Create admin user document in Firestore `/users/{uid}`
    const now = new Date();
    await db.collection('users').doc(userRecord.uid).set({
      email: email,
      role: 'admin',
      displayName: displayName,
      aadhaarHash: 'SYSTEM_ADMIN_HASH', // Bypass aadhaar requirements for admin seeding
      fakeReportCount: 0,
      status: 'active',
      termsAccepted: true,
      isAnonymous: false,
      anonymousId: 'AD-0001',
      createdAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: admin.firestore.Timestamp.fromDate(now)
    });

    console.log('\x1b[32mFirestore admin profile document created successfully!\x1b[0m');
    console.log('\x1b[32mAdmin seed completed successfully. You can now login with this email.\x1b[0m');
    process.exit(0);
  } catch (error) {
    console.error('\x1b[31mSeed failed with error:\x1b[0m', error);
    process.exit(1);
  }
}

seedAdmin();

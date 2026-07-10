const { initializeApp } = require('firebase/app');
const { 
  getAuth, 
  createUserWithEmailAndPassword, 
  signInWithEmailAndPassword, 
  signOut 
} = require('firebase/auth');
const { 
  getFirestore, 
  collection,
  doc, 
  setDoc, 
  writeBatch, 
  serverTimestamp 
} = require('firebase/firestore');

// Firebase config retrieved from firebase_options.dart for zooplehackathon
const firebaseConfig = {
  apiKey: 'AIzaSyA5IuxclQEMdXg57sv6RHah65R3g2TXIvs',
  appId: '1:968194436942:web:5806e60b3dd24bbd6fb81f',
  messagingSenderId: '968194436942',
  projectId: 'zooplehackathon',
  authDomain: 'zooplehackathon.firebaseapp.com',
  storageBucket: 'zooplehackathon.firebasestorage.app',
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// Data Plan
const credentials = {
  admin: {
    email: 'admin@nizhal.kerala.gov.in',
    password: 'AdminNizhal2026!',
    displayName: 'Headquarters Admin',
    role: 'admin',
    aadhaarHash: 'SYSTEM_ADMIN_HASH_SEED',
    anonymousId: 'AD-0001'
  },
  authorityEkm: {
    email: 'authority_ekm@nizhal.kerala.gov.in',
    password: 'AuthEkm2026!',
    name: 'Inspector Suresh Kumar',
    badgeId: 'KP-9882',
    jurisdiction: 'Ernakulam',
    specialization: 'narcotics',
    role: 'authority'
  },
  authorityTsr: {
    email: 'authority_tsr@nizhal.kerala.gov.in',
    password: 'AuthTsr2026!',
    name: 'DySP Madhavan Nair',
    badgeId: 'KP-5412',
    jurisdiction: 'Thrissur',
    specialization: 'investigation',
    role: 'authority'
  },
  authorityKoz: {
    email: 'authority_koz@nizhal.kerala.gov.in',
    password: 'AuthKoz2026!',
    name: 'SI Fathima Rahma',
    badgeId: 'KP-7731',
    jurisdiction: 'Kozhikode',
    specialization: 'patrol',
    role: 'authority'
  },
  endUser: {
    email: 'reporter_anonymous@nizhal.kerala.gov.in',
    password: 'UserNizhal2026!',
    displayName: 'Citizen Advocate',
    role: 'user',
    aadhaarHash: '73cfb8417852a39281e28bbd916892543ffb9087cf283a21', // Dummy Aadhaar Hash
    anonymousId: 'NX-8821'
  }
};

async function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function registerAndCreateProfile(cred, profileData) {
  console.log(`Registering auth user: ${cred.email}...`);
  const userCredential = await createUserWithEmailAndPassword(auth, cred.email, cred.password);
  const uid = userCredential.user.uid;
  console.log(`Auth account created. UID: ${uid}. Creating Firestore profile...`);
  
  await setDoc(doc(db, 'users', uid), {
    email: cred.email,
    role: profileData.role,
    displayName: profileData.displayName || null,
    aadhaarHash: profileData.aadhaarHash || 'NOT_APPLICABLE',
    fakeReportCount: 0,
    status: 'active',
    termsAccepted: true,
    isAnonymous: true,
    anonymousId: profileData.anonymousId || 'AX-0000',
    createdAt: new Date(),
    updatedAt: new Date()
  });
  
  console.log(`Profile created successfully for: ${cred.email}`);
  await signOut(auth);
  await delay(1000);
  return uid;
}

async function runSeeder() {
  try {
    console.log('--- STARTING NIZHAL FIREBASE SEEDER ---');

    // 1. Register Admin User
    let adminUid;
    try {
      adminUid = await registerAndCreateProfile(credentials.admin, {
        role: 'admin',
        displayName: credentials.admin.displayName,
        aadhaarHash: credentials.admin.aadhaarHash,
        anonymousId: credentials.admin.anonymousId
      });
    } catch (err) {
      if (err.code === 'auth/email-already-in-use') {
        console.log('Admin auth account already exists. Proceeding...');
      } else {
        throw err;
      }
    }

    // 2. Register End User (Reporter)
    let userUid;
    try {
      userUid = await registerAndCreateProfile(credentials.endUser, {
        role: 'user',
        displayName: credentials.endUser.displayName,
        aadhaarHash: credentials.endUser.aadhaarHash,
        anonymousId: credentials.endUser.anonymousId
      });
    } catch (err) {
      if (err.code === 'auth/email-already-in-use') {
        console.log('End User auth account already exists. Proceeding...');
      } else {
        throw err;
      }
    }

    // 3. Register Authority Users (EKM, TSR, KOZ)
    const authUids = {};
    for (const key of ['authorityEkm', 'authorityTsr', 'authorityKoz']) {
      const cred = credentials[key];
      try {
        const uid = await registerAndCreateProfile(cred, {
          role: 'authority',
          displayName: cred.name,
          aadhaarHash: 'AUTH_STAFF_HASH_' + cred.badgeId,
          anonymousId: 'AX-' + cred.badgeId
        });
        authUids[key] = uid;
      } catch (err) {
        if (err.code === 'auth/email-already-in-use') {
          console.log(`Authority ${cred.email} already exists. Proceeding...`);
        } else {
          throw err;
        }
      }
    }

    // 4. Log in as Admin to seed authorities and reports collections
    console.log('\nLogging in as Admin to seed core records...');
    const adminLogin = await signInWithEmailAndPassword(auth, credentials.admin.email, credentials.admin.password);
    console.log('Logged in as Admin. Seeding authorities collections...');

    // Seed Authorities Collection
    const batch = writeBatch(db);
    
    // Seed EKM Authority
    if (authUids.authorityEkm) {
      batch.set(doc(db, 'authorities', authUids.authorityEkm), {
        name: credentials.authorityEkm.name,
        email: credentials.authorityEkm.email,
        badgeId: credentials.authorityEkm.badgeId,
        jurisdiction: credentials.authorityEkm.jurisdiction,
        specialization: credentials.authorityEkm.specialization,
        isActive: true,
        assignedCaseCount: 1, // Will assign Case A below
        createdAt: new Date(),
        lastActiveAt: new Date()
      });
    }

    // Seed TSR Authority
    if (authUids.authorityTsr) {
      batch.set(doc(db, 'authorities', authUids.authorityTsr), {
        name: credentials.authorityTsr.name,
        email: credentials.authorityTsr.email,
        badgeId: credentials.authorityTsr.badgeId,
        jurisdiction: credentials.authorityTsr.jurisdiction,
        specialization: credentials.authorityTsr.specialization,
        isActive: true,
        assignedCaseCount: 0,
        createdAt: new Date(),
        lastActiveAt: new Date()
      });
    }

    // Seed KOZ Authority
    if (authUids.authorityKoz) {
      batch.set(doc(db, 'authorities', authUids.authorityKoz), {
        name: credentials.authorityKoz.name,
        email: credentials.authorityKoz.email,
        badgeId: credentials.authorityKoz.badgeId,
        jurisdiction: credentials.authorityKoz.jurisdiction,
        specialization: credentials.authorityKoz.specialization,
        isActive: true,
        assignedCaseCount: 1, // Will assign Case C (marked fake)
        createdAt: new Date(),
        lastActiveAt: new Date()
      });
    }

    // 5. Seed Incident Reports
    console.log('Seeding incident reports...');

    // Case A: Critical (Auto-assigned to Ernakulam)
    const reportAId = 'NZ-260709-11111';
    batch.set(doc(db, 'reports', reportAId), {
      anonymousId: credentials.endUser.anonymousId,
      description: "Discovered large-scale chemical manufacturing and distribution of pills inside an abandoned warehouse.",
      category: "manufacturing",
      priority: "critical",
      priorityBypassed: true,
      status: "assigned",
      location: null,
      locationAddress: "Warehouse 12, Industrial Area, Ernakulam",
      city: "Kochi",
      district: "Ernakulam",
      pincode: "682011",
      assignedAuthorityUid: authUids.authorityEkm || 'mock_ekm_uid',
      assignedBy: 'SYSTEM',
      mediaUrls: [],
      keywords: ["manufacturing", "chemical", "pills", "warehouse"],
      isAnonymous: true,
      mediaCount: 0,
      createdAt: new Date(),
      updatedAt: new Date()
    });

    // Sub-collections for Case A (Identity + StatusLog)
    const identityARef = doc(db, `reports/${reportAId}/identity`, userUid || 'mock_user_uid');
    batch.set(identityARef, {
      reportId: reportAId,
      reporterEmail: credentials.endUser.email,
      reporterAadhaarHash: credentials.endUser.aadhaarHash,
      isAnonymous: true
    });

    const statusLogARef = doc(collection(db, `reports/${reportAId}/statusLog`));
    batch.set(statusLogARef, {
      logId: statusLogARef.id,
      reportId: reportAId,
      previousStatus: "",
      newStatus: "assigned",
      changedBy: "SYSTEM",
      changedByRole: "system",
      note: "Auto-assigned to Ernakulam Narcotics wing due to critical priority status.",
      changedAt: new Date()
    });

    // Case B: Medium (Pending Admin Review)
    const reportBId = 'NZ-260709-22222';
    batch.set(doc(db, 'reports', reportBId), {
      anonymousId: credentials.endUser.anonymousId,
      description: "Suspicious drug use and loitering behind the public school compound during evening hours.",
      category: "drug_use",
      priority: "medium",
      priorityBypassed: false,
      status: "submitted",
      location: null,
      locationAddress: "Government School Road, Thrissur",
      city: "Thrissur",
      district: "Thrissur",
      pincode: "680001",
      assignedAuthorityUid: null,
      assignedBy: null,
      mediaUrls: [],
      keywords: ["use", "school", "loitering"],
      isAnonymous: true,
      mediaCount: 0,
      createdAt: new Date(),
      updatedAt: new Date()
    });

    const identityBRef = doc(db, `reports/${reportBId}/identity`, userUid || 'mock_user_uid');
    batch.set(identityBRef, {
      reportId: reportBId,
      reporterEmail: credentials.endUser.email,
      reporterAadhaarHash: credentials.endUser.aadhaarHash,
      isAnonymous: true
    });

    const statusLogBRef = doc(collection(db, `reports/${reportBId}/statusLog`));
    batch.set(statusLogBRef, {
      logId: statusLogBRef.id,
      reportId: reportBId,
      previousStatus: "",
      newStatus: "submitted",
      changedBy: userUid || 'mock_user_uid',
      changedByRole: "user",
      note: "Report submitted",
      changedAt: new Date()
    });

    // Case C: Fake marked (Assigned & Marked Fake in Kozhikode)
    const reportCId = 'NZ-260709-33333';
    batch.set(doc(db, 'reports', reportCId), {
      anonymousId: credentials.endUser.anonymousId,
      description: "Testing fake mark capability.",
      category: "other",
      priority: "low",
      priorityBypassed: false,
      status: "fake",
      location: null,
      locationAddress: "Test Street, Kozhikode",
      city: "Kozhikode",
      district: "Kozhikode",
      pincode: "673001",
      assignedAuthorityUid: authUids.authorityKoz || 'mock_koz_uid',
      assignedBy: 'SYSTEM',
      mediaUrls: [],
      keywords: ["testing"],
      isAnonymous: true,
      mediaCount: 0,
      createdAt: new Date(),
      updatedAt: new Date()
    });

    const identityCRef = doc(db, `reports/${reportCId}/identity`, userUid || 'mock_user_uid');
    batch.set(identityCRef, {
      reportId: reportCId,
      reporterEmail: credentials.endUser.email,
      reporterAadhaarHash: credentials.endUser.aadhaarHash,
      isAnonymous: true
    });

    const statusLogCRef = doc(collection(db, `reports/${reportCId}/statusLog`));
    batch.set(statusLogCRef, {
      logId: statusLogCRef.id,
      reportId: reportCId,
      previousStatus: "assigned",
      newStatus: "fake",
      changedBy: authUids.authorityKoz || 'mock_koz_uid',
      changedByRole: "authority",
      note: "Marked as fake report after checking the location.",
      changedAt: new Date()
    });

    // 6. Global Aggregates doc
    batch.set(doc(db, 'aggregates', 'global'), {
      totalReports: 3,
      resolvedReports: 1, // Fake count is considered resolved/closed
      pendingReports: 2,
      categoryBreakdown: {
        manufacturing: 1,
        drug_use: 1,
        other: 1
      },
      priorityBreakdown: {
        critical: 1,
        medium: 1,
        low: 1
      },
      districtBreakdown: {
        Ernakulam: 1,
        Thrissur: 1,
        Kozhikode: 1
      },
      lastUpdated: new Date()
    });

    // Commit batch
    console.log('Writing documents batch to Firestore...');
    await batch.commit();
    console.log('Batch commit completed successfully.');

    await signOut(auth);
    console.log('\n--- SEED COMPLETED SUCCESSFULLY ---');
    process.exit(0);

  } catch (error) {
    console.error('\n\x1b[31mSeeding failed with error:\x1b[0m', error);
    process.exit(1);
  }
}

runSeeder();

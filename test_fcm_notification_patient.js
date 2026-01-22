/**
 * Firebase Cloud Messaging Test Script - PATIENT APP
 * This sends test notifications to your patient app
 * 
 * Firebase Project: doctorapp-7f7e1
 * Package: com.sagha.patient
 * 
 * Setup:
 * 1. npm install firebase-admin
 * 2. Download service account key from Firebase Console (doctorapp-7f7e1)
 *    and save as firebase-service-account.json
 * 3. Get FCM token from patient app console
 * 4. Update FCM_TOKEN below
 * 5. Run: node test_fcm_notification_patient.js
 */

const admin = require('firebase-admin');

// Load service account key (same project for both apps)
const serviceAccount = require('./firebase-service-account.json');

// Your PATIENT app FCM token - UPDATE THIS!
const FCM_TOKEN = 'YOUR_PATIENT_APP_FCM_TOKEN_HERE';

// Initialize Firebase Admin (only if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

async function sendNotification(token, title, body, data = {}) {
  const message = {
    token: token,
    notification: {
      title: title,
      body: body,
    },
    data: data,
    android: {
      priority: 'high',
      notification: {
        channelId: 'default_channel',
        sound: 'default',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: title,
            body: body,
          },
          sound: 'default',
          badge: 1,
        }
      }
    },
    webpush: {
      notification: {
        title: title,
        body: body,
        icon: '/icon.png',
      },
      fcmOptions: {
        link: '/'
      }
    }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('✅ Notification sent successfully!');
    console.log('Message ID:', response);
    return response;
  } catch (error) {
    console.error('❌ Error sending notification:', error.message);
    if (error.code) {
      console.error('Error code:', error.code);
    }
    throw error;
  }
}

async function runTests() {
  console.log('🔔 Firebase Cloud Messaging Test - PATIENT APP');
  console.log('📱 Target Device Token:', FCM_TOKEN.substring(0, 30) + '...');
  console.log('='.repeat(60));
  console.log('');

  if (FCM_TOKEN === 'YOUR_PATIENT_APP_FCM_TOKEN_HERE') {
    console.error('❌ ERROR: Please update FCM_TOKEN in the script!');
    console.error('');
    console.error('Steps:');
    console.error('1. Run the patient app');
    console.error('2. Check browser console for FCM token');
    console.error('3. Update FCM_TOKEN in test_fcm_notification_patient.js');
    process.exit(1);
  }

  try {
    // Test 1: Appointment reminder for patient
    console.log('📤 Test 1: Sending appointment reminder...');
    await sendNotification(
      FCM_TOKEN,
      'Appointment Reminder 📅',
      'You have an appointment with Dr. Smith tomorrow at 2:00 PM',
      {
        type: 'appointment_reminder',
        appointment_id: '123',
        doctor_name: 'Dr. Smith',
        appointment_date: '2026-01-21',
        appointment_time: '14:00'
      }
    );
    console.log('');
    await sleep(2000);

    // Test 2: Follow-up reminder
    console.log('📤 Test 2: Sending follow-up reminder...');
    await sendNotification(
      FCM_TOKEN,
      'Follow-up Reminder ⏰',
      'Time for your dental follow-up. Please book an appointment.',
      {
        type: 'follow_up_reminder',
        visit_id: '456',
        last_visit_date: '2025-12-20',
        recommended_date: '2026-01-20'
      }
    );
    console.log('');
    await sleep(2000);

    // Test 3: Prescription ready
    console.log('📤 Test 3: Sending prescription notification...');
    await sendNotification(
      FCM_TOKEN,
      'Prescription Ready 💊',
      'Your prescription is ready for pickup',
      {
        type: 'prescription_ready',
        prescription_id: '789',
        medication: 'Amoxicillin',
        doctor_name: 'Dr. Smith'
      }
    );
    console.log('');
    await sleep(2000);

    // Test 4: Treatment plan update
    console.log('📤 Test 4: Sending treatment plan update...');
    await sendNotification(
      FCM_TOKEN,
      'Treatment Plan Updated 📋',
      'Dr. Smith has updated your treatment plan',
      {
        type: 'treatment_update',
        visit_id: '321',
        doctor_name: 'Dr. Smith',
        updated_at: new Date().toISOString()
      }
    );
    console.log('');
    await sleep(2000);

    // Test 5: Test notification
    console.log('📤 Test 5: Sending general test notification...');
    await sendNotification(
      FCM_TOKEN,
      'Test Notification 🔔',
      'Hello! Your patient app is receiving notifications correctly!',
      {
        type: 'test',
        timestamp: new Date().toISOString()
      }
    );

    console.log('');
    console.log('='.repeat(60));
    console.log('✅ All test notifications sent successfully to PATIENT app!');
    console.log('');
    console.log('📱 Check your patient app for notifications');

  } catch (error) {
    console.error('');
    console.error('❌ Test failed!');
    console.error('Error:', error.message);
    process.exit(1);
  }

  process.exit(0);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Run the tests
runTests();

/**
 * Firebase Cloud Messaging Test Script - DOCTOR APP
 * This sends test notifications to your doctor app
 * 
 * Firebase Project: doctorapp-7f7e1
 * Package: com.sagha.doctor
 * 
 * Setup:
 * 1. npm install firebase-admin
 * 2. Download service account key from Firebase Console (doctorapp-7f7e1)
 *    and save as firebase-service-account.json
 * 3. Run: node test_fcm_notification.js
 */

const admin = require('firebase-admin');

// Load service account key
const serviceAccount = require('./firebase-service-account.json');

// Your DOCTOR app FCM token (Updated from device logs)
const FCM_TOKEN = 'cS0rhyfRQtuiSYd4vfW70o:APA91bH5Okc50C1K2IfPZNrz2c942UmgG481OHGEDTdYxzVW-gIc-PGY34jZNujmVdYUIktcvIO82R_K42bqri03HtsfLSEk-bCCHX9GlbKEjleDReGHbkI';

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

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
  console.log('🔔 Firebase Cloud Messaging Test');
  console.log('📱 Target Device Token:', FCM_TOKEN.substring(0, 30) + '...');
  console.log('='.repeat(60));
  console.log('');

  try {
    // Test 1: Simple notification
    console.log('📤 Test 1: Sending simple test notification...');
    await sendNotification(
      FCM_TOKEN,
      'Test Notification 🔔',
      'Hello! This is a test notification from FCM',
      { type: 'test', timestamp: new Date().toISOString() }
    );
    console.log('');
    await sleep(2000);

    // Test 2: Follow-up reminder
    console.log('📤 Test 2: Sending follow-up reminder...');
    await sendNotification(
      FCM_TOKEN,
      'Follow-up Reminder 📅',
      'Patient John Doe needs follow-up today at 2:00 PM',
      {
        type: 'follow_up_reminder',
        patient_id: '123',
        patient_name: 'John Doe',
        follow_up_date: '2026-01-20',
        follow_up_time: '14:00'
      }
    );
    console.log('');
    await sleep(2000);

    // Test 3: Appointment reminder
    console.log('📤 Test 3: Sending appointment reminder...');
    await sendNotification(
      FCM_TOKEN,
      'Appointment Reminder ⏰',
      'You have an appointment with Jane Smith in 30 minutes',
      {
        type: 'appointment_reminder',
        appointment_id: '456',
        patient_name: 'Jane Smith',
        appointment_time: '14:30',
        slot_id: '789'
      }
    );
    console.log('');
    await sleep(2000);

    // Test 4: New patient assignment
    console.log('📤 Test 4: Sending new patient assignment...');
    await sendNotification(
      FCM_TOKEN,
      'New Patient Assigned 👤',
      'You have been assigned patient Sarah Johnson',
      {
        type: 'new_assignment',
        patient_id: '789',
        patient_name: 'Sarah Johnson',
        assigned_at: new Date().toISOString()
      }
    );
    console.log('');
    await sleep(2000);

    // Test 5: Prescription reminder
    console.log('📤 Test 5: Sending prescription reminder...');
    await sendNotification(
      FCM_TOKEN,
      'Prescription Reminder 💊',
      'Patient needs prescription refill',
      {
        type: 'prescription_reminder',
        patient_id: '321',
        patient_name: 'Mike Wilson',
        medication: 'Amoxicillin'
      }
    );

    console.log('');
    console.log('='.repeat(60));
    console.log('✅ All test notifications sent successfully!');
    console.log('');
    console.log('📱 Check your device for notifications');
    console.log('');
    console.log('💡 Tips:');
    console.log('   - If using web: Check browser notifications');
    console.log('   - If using mobile: Check notification tray');
    console.log('   - Make sure app has notification permission');
    console.log('   - Try both foreground and background states');

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

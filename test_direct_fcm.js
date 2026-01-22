const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require(path.join(__dirname, 'doctorapp-7f7e1-firebase-adminsdk-7zb9s-d31a1c7dd8.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// The exact FCM token from the device
const fcmToken = 'ezgpu-Y7Ryu7IQ63YT6EzD:APA91bEsNynkP_yFbdaYapawM9khk5m1ijB56XqUGd7PKRYdq-514PxLpi1LG11zgijLTJNcNCNPtYu9coKmW9PaDngtJriAQzuZ6B78NUWe5gZikCh9aHs';

const message = {
  notification: {
    title: 'Direct Test Notification',
    body: 'This is a direct FCM test to verify the token works'
  },
  android: {
    notification: {
      channelId: 'default',
      priority: 'high',
      defaultSound: true,
      defaultVibrateTimings: true
    }
  },
  token: fcmToken
};

console.log('🚀 Sending direct FCM notification...');
console.log('📱 Token:', fcmToken.substring(0, 30) + '...');

admin.messaging().send(message)
  .then((response) => {
    console.log('✅ Successfully sent message:', response);
  })
  .catch((error) => {
    console.error('❌ Error sending message:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));
  });

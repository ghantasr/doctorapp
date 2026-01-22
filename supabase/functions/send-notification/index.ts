import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FIREBASE_PROJECT_ID = 'doctorapp-7f7e1'
const FIREBASE_PRIVATE_KEY = Deno.env.get('FIREBASE_PRIVATE_KEY') || ''
const FIREBASE_CLIENT_EMAIL = Deno.env.get('FIREBASE_CLIENT_EMAIL') || ''

interface NotificationPayload {
  token: string
  title: string
  body: string
  data?: Record<string, string>
}

/**
 * Get OAuth2 access token for Firebase Cloud Messaging
 */
async function getAccessToken(): Promise<string> {
  const jwtHeader = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  
  const now = Math.floor(Date.now() / 1000)
  const jwtClaimSet = btoa(JSON.stringify({
    iss: FIREBASE_CLIENT_EMAIL,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  }))

  const signatureInput = `${jwtHeader}.${jwtClaimSet}`
  
  // Import private key
  const privateKey = FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
  const key = await crypto.subtle.importKey(
    'pkcs8',
    str2ab(atob(privateKey.split('\n').slice(1, -2).join(''))),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  // Sign JWT
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signatureInput)
  )

  const jwt = `${signatureInput}.${btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')}`

  // Exchange JWT for access token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const data = await response.json()
  return data.access_token
}

/**
 * Send FCM notification
 */
async function sendNotification(payload: NotificationPayload): Promise<boolean> {
  try {
    console.log('🚀 Attempting to send notification...')
    console.log('📱 Token (first 40 chars):', payload.token.substring(0, 40))
    console.log('📋 Title:', payload.title)
    console.log('💬 Body:', payload.body)
    
    const accessToken = await getAccessToken()
    console.log('🔑 Got access token:', accessToken.substring(0, 20) + '...')
    
    const message = {
      message: {
        token: payload.token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data || {},
        android: {
          priority: 'high',
          notification: {
            channel_id: 'default_channel',
            sound: 'default',
            notification_priority: 'PRIORITY_HIGH',
            visibility: 'PUBLIC',
            default_vibrate_timings: true,
            default_sound: true,
            default_light_settings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: payload.title,
                body: payload.body,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
        webpush: {
          notification: {
            title: payload.title,
            body: payload.body,
          },
        },
      },
    }

    console.log('📤 Sending to Firebase...')
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      }
    )

    console.log('📥 Firebase response status:', response.status)
    
    if (!response.ok) {
      const error = await response.text()
      console.error('❌ FCM Error Response:', error)
      return false
    }

    const result = await response.json()
    console.log('✅ Notification sent successfully! Firebase response:', JSON.stringify(result))
    return true
  } catch (error) {
    console.error('Error sending notification:', error)
    return false
  }
}

/**
 * Helper function to convert string to ArrayBuffer
 */
function str2ab(str: string): ArrayBuffer {
  const buf = new ArrayBuffer(str.length)
  const bufView = new Uint8Array(buf)
  for (let i = 0; i < str.length; i++) {
    bufView[i] = str.charCodeAt(i)
  }
  return buf
}

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders,
    })
  }

  try {
    const { type, data } = await req.json()

    console.log('Received notification request:', { type, data })

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let notificationsSent = 0

    switch (type) {
      case 'follow_up_reminder': {
        // Send follow-up reminder to doctor
        const { doctor_id, patient_name, follow_up_date } = data
        
        // Get doctor's FCM tokens
        const { data: tokens } = await supabaseClient
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', doctor_id)

        if (tokens && tokens.length > 0) {
          for (const { token } of tokens) {
            await sendNotification({
              token,
              title: 'Follow-up Reminder 📅',
              body: `Patient ${patient_name} needs follow-up on ${follow_up_date}`,
              data: {
                type: 'follow_up_reminder',
                patient_name,
                follow_up_date,
              },
            })
            notificationsSent++
          }
        }
        break
      }

      case 'appointment_reminder': {
        // Send appointment reminder
        const { user_id, doctor_name, patient_name, appointment_time, is_doctor } = data
        
        console.log('Querying FCM tokens for user_id:', user_id)
        
        const { data: tokens, error } = await supabaseClient
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', user_id)

        console.log('FCM tokens query result:', { tokens, error, count: tokens?.length })

        if (tokens && tokens.length > 0) {
          const title = 'Appointment Reminder ⏰'
          const body = is_doctor
            ? `You have an appointment with ${patient_name} at ${appointment_time}`
            : `You have an appointment with Dr. ${doctor_name} at ${appointment_time}`

          for (const { token } of tokens) {
            console.log('Sending notification to token:', token.substring(0, 30) + '...')
            const success = await sendNotification({
              token,
              title,
              body,
              data: {
                type: 'appointment_reminder',
                appointment_time,
              },
            })
            console.log('Notification send result:', success)
            if (success) notificationsSent++
          }
        } else {
          console.log('No FCM tokens found for user:', user_id)
        }
        break
      }

      case 'new_assignment': {
        // Notify doctor about new patient assignment
        const { doctor_id, patient_name } = data
        
        const { data: tokens } = await supabaseClient
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', doctor_id)

        if (tokens && tokens.length > 0) {
          for (const { token } of tokens) {
            await sendNotification({
              token,
              title: 'New Patient Assigned 👤',
              body: `You have been assigned patient ${patient_name}`,
              data: {
                type: 'new_assignment',
                patient_name,
              },
            })
            notificationsSent++
          }
        }
        break
      }

      case 'prescription_ready': {
        // Notify patient about prescription
        const { patient_id, medication } = data
        
        const { data: tokens } = await supabaseClient
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', patient_id)

        if (tokens && tokens.length > 0) {
          for (const { token } of tokens) {
            await sendNotification({
              token,
              title: 'Prescription Ready 💊',
              body: `Your prescription for ${medication} is ready for pickup`,
              data: {
                type: 'prescription_ready',
                medication,
              },
            })
            notificationsSent++
          }
        }
        break
      }

      default:
        return new Response(
          JSON.stringify({ error: 'Unknown notification type' }),
          { 
            status: 400, 
            headers: { 
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            } 
          }
        )
    }

    return new Response(
      JSON.stringify({
        success: true,
        notificationsSent,
        message: `Sent ${notificationsSent} notification(s)`,
      }),
      { 
        status: 200, 
        headers: { 
          'Content-Type': 'application/json',
          ...corsHeaders,
        } 
      }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { 
          'Content-Type': 'application/json',
          ...corsHeaders,
        } 
      }
    )
  }
})

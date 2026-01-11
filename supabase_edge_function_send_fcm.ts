// Supabase Edge Function: send-fcm-notification
// This function sends actual FCM push notifications using Firebase Admin SDK
// Deploy with: supabase functions deploy send-fcm-notification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface FCMMessage {
  token: string
  notification: {
    title: string
    body: string
  }
  data?: Record<string, string>
  android?: {
    priority: string
  }
  apns?: {
    payload: {
      aps: {
        sound: string
      }
    }
  }
}

async function sendFCMNotification(
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ success: boolean; error?: string }> {
  try {
    // Get Firebase service account from environment
    const firebaseServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')
    if (!firebaseServiceAccount) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_KEY environment variable not set')
    }

    const serviceAccount = JSON.parse(firebaseServiceAccount)
    const projectId = serviceAccount.project_id

    // Get OAuth2 access token for Firebase Admin SDK
    const { access_token } = await getAccessToken(serviceAccount)

    // Construct FCM message
    const message: FCMMessage = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    }

    // Send to FCM v1 API
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
    const response = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${access_token}`,
      },
      body: JSON.stringify({ message }),
    })

    if (!response.ok) {
      const error = await response.text()
      console.error('FCM send failed:', error)
      return { success: false, error: error }
    }

    const result = await response.json()
    console.log('FCM notification sent successfully:', result)
    return { success: true }

  } catch (error) {
    console.error('Error sending FCM notification:', error)
    return { success: false, error: error.message }
  }
}

async function getAccessToken(serviceAccount: any): Promise<{ access_token: string }> {
  // Create JWT for Google OAuth2
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  }

  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  }

  // Encode header and payload
  // NOTE: Using btoa() for simplicity. In production with Unicode,
  // use proper base64url encoding library
  const encodedHeader = btoa(JSON.stringify(header))
  const encodedPayload = btoa(JSON.stringify(payload))
  const unsignedToken = `${encodedHeader}.${encodedPayload}`

  // Sign with private key (simplified - in production use proper crypto library)
  // For Deno, we'll use the Web Crypto API
  const privateKey = serviceAccount.private_key
  
  // Import the private key
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey),
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )

  // Sign the token
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedToken)
  )

  // Encode signature
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
  const jwt = `${unsignedToken}.${encodedSignature}`

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!tokenResponse.ok) {
    const error = await tokenResponse.text()
    throw new Error(`Failed to get access token: ${error}`)
  }

  return await tokenResponse.json()
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  // NOTE: This is a simplified implementation for demonstration
  // In production, use a proper library that handles base64url encoding correctly
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  
  const binaryString = atob(pemContents)
  const bytes = new Uint8Array(binaryString.length)
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }
  return bytes.buffer
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const { fcmToken, title, body, data } = await req.json()

    if (!fcmToken || !title || !body) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Missing required fields: fcmToken, title, body' 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400 
        }
      )
    }

    // Send FCM notification
    const result = await sendFCMNotification(fcmToken, title, body, data)

    return new Response(
      JSON.stringify(result),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: result.success ? 200 : 500 
      }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})

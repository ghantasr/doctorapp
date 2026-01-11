// Supabase Edge Function: send-fcm-simple
// Simplified FCM sending using legacy FCM HTTP API
// This is easier to implement in Edge Functions without complex JWT signing
// Deploy with: supabase functions deploy send-fcm-simple

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * Send FCM notification using the legacy HTTP v1 API
 * This requires the FCM Server Key (not the service account)
 */
async function sendFCMNotificationLegacy(
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ success: boolean; error?: string; messageId?: string }> {
  try {
    // Get FCM Server Key from environment
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      console.error('FCM_SERVER_KEY not set')
      return { 
        success: false, 
        error: 'FCM_SERVER_KEY environment variable not set. Please add it in Supabase dashboard.' 
      }
    }

    // Construct FCM payload for legacy API
    const payload = {
      to: fcmToken,
      priority: 'high',
      notification: {
        title: title,
        body: body,
        sound: 'default',
        badge: '1',
      },
      data: data || {},
    }

    // Send to FCM legacy API
    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${fcmServerKey}`,
      },
      body: JSON.stringify(payload),
    })

    if (!response.ok) {
      const error = await response.text()
      console.error('FCM send failed:', error)
      return { success: false, error: error }
    }

    const result = await response.json()
    
    // Check if there were any errors
    if (result.failure > 0) {
      const errorMsg = result.results?.[0]?.error || 'Unknown FCM error'
      console.error('FCM returned error:', errorMsg)
      return { success: false, error: errorMsg }
    }

    console.log('FCM notification sent successfully:', result.results?.[0]?.message_id)
    return { 
      success: true, 
      messageId: result.results?.[0]?.message_id 
    }

  } catch (error) {
    console.error('Error sending FCM notification:', error)
    return { success: false, error: error.message }
  }
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
    const result = await sendFCMNotificationLegacy(fcmToken, title, body, data)

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

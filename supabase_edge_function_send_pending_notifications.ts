// Supabase Edge Function: send-pending-notifications
// This function processes all pending notifications and sends them via FCM
// Deploy with: supabase functions deploy send-pending-notifications
// Can be scheduled to run every 5-15 minutes to ensure notifications are sent

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * Send FCM notification using the legacy HTTP API
 * This is simpler and doesn't require complex JWT signing
 */
async function sendFCMNotification(
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ success: boolean; error?: string; messageId?: string }> {
  try {
    // Get FCM Server Key from environment (legacy API key from Firebase Console)
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      console.error('FCM_SERVER_KEY not set - notifications will be logged but not sent')
      console.log('To send notifications, add FCM_SERVER_KEY in Supabase Edge Function secrets')
      console.log('Get it from: Firebase Console > Project Settings > Cloud Messaging > Server Key')
      return { success: false, error: 'FCM_SERVER_KEY not configured' }
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
      
      // Handle specific error cases
      if (errorMsg === 'InvalidRegistration' || errorMsg === 'NotRegistered') {
        return { success: false, error: 'invalid_token' }
      }
      
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
    // Create Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get all pending notifications (limit to 100 at a time to avoid timeout)
    const { data: pendingNotifications, error: queryError } = await supabaseClient
      .from('notification_logs')
      .select('id, user_id, notification_type, title, body, data, sent_at')
      .eq('status', 'pending')
      .order('sent_at', { ascending: true })
      .limit(100)

    if (queryError) {
      console.error('Error fetching pending notifications:', queryError)
      throw queryError
    }

    console.log(`Found ${pendingNotifications?.length || 0} pending notifications to process`)

    const results = {
      processed: 0,
      sent: 0,
      failed: 0,
      no_token: 0,
      details: [] as any[]
    }

    // Process each pending notification
    for (const notification of pendingNotifications || []) {
      try {
        results.processed++

        // Get all active FCM tokens for the user (multi-device support)
        const { data: tokenData, error: tokenError } = await supabaseClient
          .from('user_fcm_tokens')
          .select('fcm_token')
          .eq('user_id', notification.user_id)
          .eq('is_active', true)

        if (tokenError) {
          console.error(`Error fetching token for user ${notification.user_id}:`, tokenError)
          results.failed++
          
          // Update notification status to failed
          await supabaseClient
            .from('notification_logs')
            .update({ 
              status: 'failed',
              error_message: tokenError.message 
            })
            .eq('id', notification.id)
          
          continue
        }

        if (!tokenData || tokenData.length === 0) {
          console.log(`No FCM token found for user ${notification.user_id}`)
          results.no_token++
          
          // Update notification status to no_token
          await supabaseClient
            .from('notification_logs')
            .update({ status: 'no_token' })
            .eq('id', notification.id)
          
          results.details.push({
            notification_id: notification.id,
            user_id: notification.user_id,
            status: 'no_token'
          })
          
          continue
        }

        // Convert data object to string key-value pairs for FCM
        const fcmData: Record<string, string> = {}
        if (notification.data && typeof notification.data === 'object') {
          for (const [key, value] of Object.entries(notification.data)) {
            fcmData[key] = String(value)
          }
        }

        // Send to all active tokens for this user (multi-device support)
        let sentToAtLeastOneDevice = false
        let lastError = null

        for (const token of tokenData) {
          const sendResult = await sendFCMNotification(
            token.fcm_token,
            notification.title,
            notification.body,
            fcmData
          )

          if (sendResult.success) {
            sentToAtLeastOneDevice = true
          } else {
            lastError = sendResult.error
            
            // If token is invalid, deactivate this specific token
            if (sendResult.error === 'invalid_token') {
              console.log(`Deactivating invalid token for user ${notification.user_id}`)
              await supabaseClient
                .from('user_fcm_tokens')
                .update({ is_active: false })
                .eq('user_id', notification.user_id)
                .eq('fcm_token', token.fcm_token)
            }
          }
        }

        if (sentToAtLeastOneDevice) {
          results.sent++
          
          // Update notification status to sent
          await supabaseClient
            .from('notification_logs')
            .update({ 
              status: 'sent',
              error_message: null
            })
            .eq('id', notification.id)
          
          results.details.push({
            notification_id: notification.id,
            user_id: notification.user_id,
            status: 'sent',
            device_count: tokenData.length
          })
        } else {
          results.failed++
          
          // Update notification status to failed with error message
          await supabaseClient
            .from('notification_logs')
            .update({ 
              status: 'failed',
              error_message: lastError || 'Failed to send to all devices'
            })
            .eq('id', notification.id)
          
          results.details.push({
            notification_id: notification.id,
            user_id: notification.user_id,
            status: 'failed',
            error: lastError
          })
        }

      } catch (error) {
        console.error(`Error processing notification ${notification.id}:`, error)
        results.failed++
        
        results.details.push({
          notification_id: notification.id,
          user_id: notification.user_id,
          status: 'error',
          error: error.message
        })
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${results.processed} pending notifications`,
        summary: {
          processed: results.processed,
          sent: results.sent,
          failed: results.failed,
          no_token: results.no_token
        },
        details: results.details
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
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

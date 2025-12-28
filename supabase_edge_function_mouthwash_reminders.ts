// Supabase Edge Function: send-mouthwash-reminders
// This function should be deployed to Supabase and scheduled to run twice daily
// Deploy with: supabase functions deploy send-mouthwash-reminders
// Schedule morning: supabase functions schedule send-mouthwash-reminders --cron "0 8 * * *" --env TIME_OF_DAY=morning
// Schedule evening: supabase functions schedule send-mouthwash-reminders --cron "0 20 * * *" --env TIME_OF_DAY=evening

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get time of day from request or environment variable
    const { timeOfDay } = await req.json().catch(() => ({}))
    const targetTimeOfDay = timeOfDay || Deno.env.get('TIME_OF_DAY') || 'morning'

    console.log(`Sending ${targetTimeOfDay} mouthwash reminders`)

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

    // Get all active mouthwash reminders
    const { data: reminders, error: queryError } = await supabaseClient
      .rpc('get_active_mouthwash_reminders')

    if (queryError) {
      console.error('Error fetching mouthwash reminders:', queryError)
      throw queryError
    }

    // Filter by time of day
    const filteredReminders = (reminders || []).filter(
      r => r.time_of_day === targetTimeOfDay
    )

    console.log(`Found ${filteredReminders.length} ${targetTimeOfDay} mouthwash reminders to send`)

    const results = []
    
    // Send notification to each patient
    for (const reminder of filteredReminders) {
      try {
        // Call the function to send notification
        const { data: result, error: sendError } = await supabaseClient
          .rpc('send_mouthwash_notification', {
            p_patient_id: reminder.patient_id,
            p_reminder_text: reminder.reminder_text,
            p_time_of_day: reminder.time_of_day
          })

        if (sendError) {
          console.error(`Error sending notification to patient ${reminder.patient_id}:`, sendError)
          results.push({
            patient_id: reminder.patient_id,
            patient_name: `${reminder.patient_first_name} ${reminder.patient_last_name}`,
            success: false,
            error: sendError.message
          })
          continue
        }

        // If we have an FCM token, send actual push notification via Firebase Admin SDK
        if (result?.has_token && result?.fcm_token) {
          // TODO: Integrate Firebase Admin SDK to send actual push notification
          // For now, we're just logging the notification in the database
          console.log(`Would send push notification to token: ${result.fcm_token}`)
        }

        results.push({
          patient_id: reminder.patient_id,
          patient_name: `${reminder.patient_first_name} ${reminder.patient_last_name}`,
          success: true,
          has_token: result?.has_token || false,
          time_of_day: targetTimeOfDay
        })
      } catch (error) {
        console.error(`Error processing patient ${reminder.patient_id}:`, error)
        results.push({
          patient_id: reminder.patient_id,
          success: false,
          error: error.message
        })
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${results.length} ${targetTimeOfDay} mouthwash reminders`,
        time_of_day: targetTimeOfDay,
        results: results
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

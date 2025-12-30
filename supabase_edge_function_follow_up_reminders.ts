// Supabase Edge Function: send-follow-up-reminders
// This function should be deployed to Supabase and scheduled to run daily at 8 AM
// Deploy with: supabase functions deploy send-follow-up-reminders
// Schedule with: supabase functions schedule send-follow-up-reminders --cron "0 8 * * *"

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

    // Get patients with follow-ups due in 2 days
    const { data: patients, error: queryError } = await supabaseClient
      .rpc('get_follow_up_patients_due_in_days', { days_advance: 2 })

    if (queryError) {
      console.error('Error fetching follow-up patients:', queryError)
      throw queryError
    }

    console.log(`Found ${patients?.length || 0} patients with follow-ups due in 2 days`)

    const results = []
    
    // Send notification to each patient
    for (const patient of patients || []) {
      try {
        // Call the function to send notification
        const { data: result, error: sendError } = await supabaseClient
          .rpc('send_follow_up_notification', {
            p_patient_id: patient.patient_id,
            p_follow_up_date: patient.follow_up_date
          })

        if (sendError) {
          console.error(`Error sending notification to patient ${patient.patient_id}:`, sendError)
          results.push({
            patient_id: patient.patient_id,
            patient_name: `${patient.patient_first_name} ${patient.patient_last_name}`,
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
          patient_id: patient.patient_id,
          patient_name: `${patient.patient_first_name} ${patient.patient_last_name}`,
          success: true,
          has_token: result?.has_token || false
        })
      } catch (error) {
        console.error(`Error processing patient ${patient.patient_id}:`, error)
        results.push({
          patient_id: patient.patient_id,
          success: false,
          error: error.message
        })
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${results.length} follow-up reminders`,
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

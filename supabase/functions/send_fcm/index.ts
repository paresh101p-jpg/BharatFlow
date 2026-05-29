import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { initializeApp, cert } from "npm:firebase-admin/app";
import { getMessaging } from "npm:firebase-admin/messaging";

let app;
try {
  const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  app = initializeApp({
    credential: cert(serviceAccount),
  });
} catch(e) {
  // Ignore if already initialized
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record; // helpline_answers insert
    
    if (!record || !record.question_id) {
      return new Response("Not an answer", { status: 200 });
    }

    // Get the question's author user_id
    const { data: qData, error: qErr } = await supabase
      .from('helpline_questions')
      .select('user_id, question_text')
      .eq('id', record.question_id)
      .single();

    if (qErr || !qData || !qData.user_id) return new Response("No user_id found", { status: 200 });

    // Don't notify if the user replied to their own question
    if (qData.user_id === record.user_id) {
       return new Response("Self reply", { status: 200 });
    }

    // Get FCM token from profiles
    const { data: pData } = await supabase
      .from('profiles')
      .select('fcm_token, notifications_on')
      .eq('id', qData.user_id)
      .single();

    if (!pData || !pData.fcm_token || pData.notifications_on === false) {
      return new Response("No FCM token or notifications disabled", { status: 200 });
    }

    const message = {
      token: pData.fcm_token,
      notification: {
        title: "Naya Jawab Aaya Hai! 🌾",
        body: `${record.user_name || 'Kisi kisan'} ne aapke sawal ka jawab diya hai.`,
      },
      data: {
        route: 'question_details',
        question_id: record.question_id,
      }
    };

    const response = await getMessaging().send(message);
    console.log('Successfully sent message:', response);
    return new Response(JSON.stringify({ success: true, messageId: response }), { status: 200, headers: { "Content-Type": "application/json" } });

  } catch (err) {
    console.error(err);
    return new Response(String(err?.message || err), { status: 500 });
  }
});

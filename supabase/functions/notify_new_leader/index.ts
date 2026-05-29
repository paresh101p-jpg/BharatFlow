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

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record; // leaders_master insert
    
    if (!record || !record.name || !record.constituency) {
      return new Response("Not a valid leader record", { status: 200 });
    }

    const city = record.constituency.split(' ')[0]; // Basic parsing

    const message = {
      topic: 'all_users', // Broadcast to all for testing, later we can use topic: `city_${city}`
      notification: {
        title: `🚨 ${city} Mein Naye Chunav Ki List Aa Gayi Hai!`,
        body: `${record.name} (${record.party}) ka sarakari kacha-chitha dekhein aur apna vote register karein!`,
      },
      data: {
        route: 'political_hub'
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

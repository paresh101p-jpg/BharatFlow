import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TOKEN = "re_XN3oz6b9_Ftg6263oNhDkzkCwZN3JyAvY";

const supabase = createClient(supabaseUrl, supabaseKey);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { question_id, action, reason, answer, token } = await req.json();

    if (token !== TOKEN) {
      return new Response(JSON.stringify({ error: "Invalid Token" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (!question_id) {
       return new Response(JSON.stringify({ error: "Missing ID" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (action === 'reject') {
      const { error } = await supabase
        .from('helpline_questions')
        .update({ status: 'rejected', rejection_reason: reason })
        .eq('id', question_id);
      
      if (error) throw error;
      return new Response(JSON.stringify({ success: true, message: "Question rejected" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (action === 'approve') {
      const { error } = await supabase
        .from('helpline_questions')
        .update({ 
           status: 'approved',
           answer_text: answer || null,
           expert_name: answer ? 'Agri Expert' : null,
           replied_at: answer ? new Date().toISOString() : null
        })
        .eq('id', question_id);
        
      if (error) throw error;
      return new Response(JSON.stringify({ success: true, message: "Question approved" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Invalid action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});

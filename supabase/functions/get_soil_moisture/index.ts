import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    const { farm_id, lat, lng } = await req.json()
    
    // GEE to CDSE Failover Logic
    let moisture_index: number | null = null;
    let status = 'Unknown';
    let fetched_from = 'None';
    
    try {
        // Primary API: Try Google Earth Engine (GEE)
        // Simulated API call (replace with actual fetch)
        const isGEE_Success = Math.random() > 0.3; // 70% success rate mock
        if (!isGEE_Success) throw new Error('GEE limit reached or 429 Error');
        
        moisture_index = Math.floor(Math.random() * (100 - 10) + 10);
        fetched_from = 'GEE';
    } catch (e) {
        // Fallback API: Copernicus Data Space Ecosystem (CDSE)
        console.log("GEE failed, falling back to CDSE...");
        moisture_index = Math.floor(Math.random() * (100 - 10) + 10);
        fetched_from = 'CDSE';
    }
    
    if (moisture_index < 35) {
        status = 'Dry - Immediate Irrigation Needed';
    } else {
        status = 'Optimal Moisture - No Water Needed';
    }
    
    // Save to Cache Table
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data, error } = await supabaseClient
      .from('mk_soil_health')
      .insert([{ farm_id, moisture_index, status, fetched_from }])
      .select()

    if (error) throw error;

    return new Response(
      JSON.stringify({ success: true, data: data[0] }),
      { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }, status: 200 },
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      status: 400,
    })
  }
})

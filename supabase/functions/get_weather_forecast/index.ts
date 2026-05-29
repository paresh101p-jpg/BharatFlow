import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    const { lat, lng } = await req.json()
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Note: In a real scenario, you'd use a Postgres Function (RPC) via PostGIS ST_DWithin 
    // to check the 15km radius caching.
    // For this implementation, we will simulate fetching from VPS/Open-Meteo
    // and caching it into mk_weather_cache.

    const isExtremeWeather = Math.random() > 0.85; // 15% chance of extreme weather
    
    const forecast_data = {
      forecast_15_days: [
        { day: 1, condition: 'Sunny', temp: 32 },
        { day: 2, condition: 'Cloudy', temp: 30 },
        { day: 3, condition: isExtremeWeather ? 'Heavy Rainfall' : 'Clear', temp: 28 },
      ],
      alert: isExtremeWeather ? 'Cyclone / Heavy Rainfall Warning in your area!' : null
    };

    const point = `POINT(${lng} ${lat})`;

    const { data, error } = await supabaseClient
      .from('mk_weather_cache')
      .insert([{ location: point, forecast_data }])
      .select()

    if (error) throw error;

    return new Response(
      JSON.stringify({ success: true, data: forecast_data, cached: false }),
      { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }, status: 200 },
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      status: 400,
    })
  }
})

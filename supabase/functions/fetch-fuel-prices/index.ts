import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req) => {
  try {
    const cities = [
      { id: "surat", state: "Gujarat" },
      { id: "ahmedabad", state: "Gujarat" },
      { id: "delhi", state: "Delhi" },
      { id: "mumbai", state: "Maharashtra" },
      { id: "pune", state: "Maharashtra" },
      { id: "chennai", state: "Tamil Nadu" },
      { id: "kolkata", state: "West Bengal" },
      { id: "jaipur", state: "Rajasthan" },
      { id: "lucknow", state: "Uttar Pradesh" },
      { id: "bangalore", state: "Karnataka" },
      { id: "hyderabad", state: "Telangana" },
      { id: "patna", state: "Bihar" }
    ];
    
    const fuelResults = [];
    const commodityResults = [];

    for (const cityInfo of cities) {
      try {
        const city = cityInfo.id;
        
        // Fetch Fuel, Gold/Silver, and PNG concurrently
        const [pRes, dRes, lRes, cRes, gRes, pngRes] = await Promise.all([
          fetch(`https://www.goodreturns.in/petrol-price-in-${city}.html`),
          fetch(`https://www.goodreturns.in/diesel-price-in-${city}.html`),
          fetch(`https://www.goodreturns.in/lpg-price-in-${city}.html`),
          fetch(`https://www.goodreturns.in/cng-price-in-${city}.html`),
          fetch(`https://www.goodreturns.in/gold-rates/${city}.html`),
          fetch(`https://www.goodreturns.in/png-price-in-${city}.html`)
        ]);
        
        const [pHtml, dHtml, lHtml, cHtml, gHtml, pngHtml] = await Promise.all([
          pRes.text(), dRes.text(), lRes.text(), cRes.text(), gRes.text(), pngRes.text()
        ]);
        
        // Fuel Scraping
        const pMatch = pHtml.match(/petrol price in [a-zA-Z\s]+ is <b>\u20B9\s?(\d+\.\d+)<\/b>/i) || pHtml.match(/is <b>\u20B9\s?(\d+\.\d+)<\/b>/i) || pHtml.match(/at \u20B9\s?(\d+\.\d+)/i);
        const dMatch = dHtml.match(/diesel price in [a-zA-Z\s]+ is <b>\u20B9\s?(\d+\.\d+)<\/b>/i) || dHtml.match(/is <b>\u20B9\s?(\d+\.\d+)<\/b>/i) || dHtml.match(/at \u20B9\s?(\d+\.\d+)/i);
        const lpgMatches = [...lHtml.matchAll(/<b>\u20B9\s?(\d+\.\d+)<\/b>/gi)];
        let domesticLpg = lpgMatches[0] ? parseFloat(lpgMatches[0][1]) : 918.50;
        let commercialLpg = lpgMatches[1] ? parseFloat(lpgMatches[1][1]) : 3024.50;
        if (domesticLpg > commercialLpg && commercialLpg > 0) [domesticLpg, commercialLpg] = [commercialLpg, domesticLpg];
        const cMatch = cHtml.match(/CNG price in [a-zA-Z\s]+ is <b>\u20B9\s?(\d+\.\d+)<\/b>/i) || cHtml.match(/is <b>\u20B9\s?(\d+\.\d+)<\/b>/i);
        const pngMatch = pngHtml.match(/PNG price in [a-zA-Z\s]+ is <b>\u20B9\s?(\d+\.\d+)<\/b>/i) || pngHtml.match(/is <b>\u20B9\s?(\d+\.\d+)<\/b>/i) || pngHtml.match(/at \u20B9\s?(\d+\.\d+)/i);
        
        fuelResults.push({
          city: city.charAt(0).toUpperCase() + city.slice(1),
          state: cityInfo.state,
          petrol: pMatch ? parseFloat(pMatch[1]) : 94.53,
          diesel: dMatch ? parseFloat(dMatch[1]) : 90.22,
          cng: cMatch ? parseFloat(cMatch[1]) : 82.16,
          png: pngMatch ? parseFloat(pngMatch[1]) : 49.60,
          lpg: domesticLpg,
          commercial_lpg: commercialLpg,
          updated_at: new Date().toISOString()
        });

        // Gold & Silver Fetching from API
        let gold24k = 72000;
        let gold22k = 66000;
        let silver = 85000;

        try {
          const [goldRes, silverRes] = await Promise.all([
            fetch(`https://api.gold-api.com/price/XAU/INR`),
            fetch(`https://api.gold-api.com/price/XAG/INR`)
          ]);

          const goldData = await goldRes.json();
          const silverData = await silverRes.json();

          if (goldData && goldData.price) {
            // Price is per Ounce (31.1035g). Convert to per 10g.
            // In India, we have ~15% additional cost (Import Duty + GST)
            const pricePerGram = (goldData.price / 31.1035) * 1.15;
            gold24k = Math.round(pricePerGram * 10);
            gold22k = Math.round(gold24k * 0.9167); // 22K is approx 91.67% of 24K
          }

          if (silverData && silverData.price) {
            // Price is per Ounce (31.1035g). Convert to per 1kg.
            // In India, we have ~15% additional cost (Import Duty + GST)
            const pricePerGram = (silverData.price / 31.1035) * 1.15;
            silver = Math.round(pricePerGram * 1000);
          }
        } catch (apiErr) {
          console.error("API Fetch Error:", apiErr);
        }

        commodityResults.push({
          city: city.charAt(0).toUpperCase() + city.slice(1),
          state: cityInfo.state,
          gold_24k: gold24k,
          gold_22k: gold22k,
          silver: silver,
          updated_at: new Date().toISOString()
        });

      } catch (e) {
        console.error(`Failed to scrape ${cityInfo.id}:`, e);
      }
    }

    if (fuelResults.length > 0) {
      await Promise.all([
        supabase.from("fuel_prices").upsert(fuelResults, { onConflict: "city,state" }),
        supabase.from("fuel_price_history").insert(fuelResults.map(r => ({ ...r, recorded_at: new Date().toISOString() }))),
        supabase.from("commodity_prices").upsert(commodityResults, { onConflict: "city,state" })
      ]);
    }

    return new Response(JSON.stringify({ 
      success: true, 
      message: `${fuelResults.length} cities updated (Fuel + Gold + Silver)`,
    }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
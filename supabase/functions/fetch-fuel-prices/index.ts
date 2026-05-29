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
    let reqData = {};
    try {
      reqData = await req.json();
    } catch (e) {
      // Ignore if no JSON body
    }

    let cities = [];
    if (reqData.city && reqData.state) {
      const sanitizedCity = reqData.city.toLowerCase().replace(/\s+/g, '-');
      cities.push({ id: sanitizedCity, state: reqData.state, displayName: reqData.city });
    } else {
      cities = [
        { id: "surat", state: "Gujarat", displayName: "Surat" },
        { id: "ahmedabad", state: "Gujarat", displayName: "Ahmedabad" },
        { id: "delhi", state: "Delhi", displayName: "Delhi" },
        { id: "mumbai", state: "Maharashtra", displayName: "Mumbai" },
        { id: "pune", state: "Maharashtra", displayName: "Pune" },
        { id: "chennai", state: "Tamil Nadu", displayName: "Chennai" },
        { id: "kolkata", state: "West Bengal", displayName: "Kolkata" },
        { id: "jaipur", state: "Rajasthan", displayName: "Jaipur" },
        { id: "lucknow", state: "Uttar Pradesh", displayName: "Lucknow" },
        { id: "bangalore", state: "Karnataka", displayName: "Bangalore" },
        { id: "hyderabad", state: "Telangana", displayName: "Hyderabad" },
        { id: "patna", state: "Bihar", displayName: "Patna" }
      ];
    }
    
    const fuelResults = [];
    const commodityResults = [];
    let anyPriceChanged = false;

    // Fetch existing fuel prices to detect changes
    const { data: existingData } = await supabase.from('fuel_prices').select('*');
    const existingMap = new Map((existingData || []).map(r => [`${r.city.toLowerCase()}`, r]));

    const fetchOptions = {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      }
    };

    for (const cityInfo of cities) {
      try {
        const city = cityInfo.id;
        
        // Fetch Fuel, Gold/Silver, and PNG concurrently
        const [pRes, dRes, lRes, cRes, gRes, pngRes] = await Promise.all([
          fetch(`https://www.goodreturns.in/petrol-price-in-${city}.html`, fetchOptions),
          fetch(`https://www.goodreturns.in/diesel-price-in-${city}.html`, fetchOptions),
          fetch(`https://www.goodreturns.in/lpg-price-in-${city}.html`, fetchOptions),
          fetch(`https://www.goodreturns.in/cng-price-in-${city}.html`, fetchOptions),
          fetch(`https://www.goodreturns.in/gold-rates/${city}.html`, fetchOptions),
          fetch(`https://www.goodreturns.in/png-price-in-${city}.html`, fetchOptions)
        ]);
        
        const [pHtml, dHtml, lHtml, cHtml, gHtml, pngHtml] = await Promise.all([
          pRes.text(), dRes.text(), lRes.text(), cRes.text(), gRes.text(), pngRes.text()
        ]);
        
        // Fuel Scraping
        const rxPetrol = /petrol price in [a-zA-Z\s]+ is (?:at )?(?:<b>)?(?:&#x20b9;|&#8377;|\u20B9|₹|Rs\.?)\s*(?:<b>)?(\d+(?:,\d+)*\.\d+)(?:<\/b>)?/i;
        const rxDiesel = /diesel price in [a-zA-Z\s]+ is (?:at )?(?:<b>)?(?:&#x20b9;|&#8377;|\u20B9|₹|Rs\.?)\s*(?:<b>)?(\d+(?:,\d+)*\.\d+)(?:<\/b>)?/i;
        const rxCNG = /CNG price in [a-zA-Z\s]+ (?:is|stands) (?:at )?(?:<b>)?(?:&#x20b9;|&#8377;|\u20B9|₹|Rs\.?)\s*(?:<b>)?(\d+(?:,\d+)*\.\d+)(?:<\/b>)?/i;
        const rxPNG = /PNG price in [a-zA-Z\s]+ (?:is|stands) (?:at )?(?:<b>)?(?:&#x20b9;|&#8377;|\u20B9|₹|Rs\.?)\s*(?:<b>)?(\d+(?:,\d+)*\.\d+)(?:<\/b>)?/i;
        
        const pMatch = pHtml.match(rxPetrol);
        const dMatch = dHtml.match(rxDiesel);
        
        const dLpgMatch = lHtml.match(/Domestic LPG .*? (?:is|stands) (?:at )?(?:<b>)?(?:&#x20b9;|&#8377;|\u20B9|₹|Rs\.?)\s*(?:<b>)?(\d+(?:,\d+)*\.\d+)/i) || lHtml.match(/(?:&#x20b9;|&#8377;|\u20B9|₹|Rs\.?)\s*(?:<b>)?(\d+(?:,\d+)*\.\d+)(?:<\/b>)?/i);
        const cLpgMatch = lHtml.match(/Commercial LPG .*? (?:is|stands) (?:at )?(?:<b>)?(?:&#x20b9;|&#8377;|\u20B9|₹|Rs\.?)\s*(?:<b>)?(\d+(?:,\d+)*\.\d+)/i);
        let domesticLpg = dLpgMatch ? parseFloat(dLpgMatch[1].replace(/,/g, '')) : 918.50;
        let commercialLpg = cLpgMatch ? parseFloat(cLpgMatch[1].replace(/,/g, '')) : 3024.50;
        if (domesticLpg > commercialLpg && commercialLpg > 0) [domesticLpg, commercialLpg] = [commercialLpg, domesticLpg];
        
        const cMatch = cHtml.match(rxCNG);
        const pngMatch = pngHtml.match(rxPNG);
        
        const petrol = pMatch ? parseFloat(pMatch[1].replace(/,/g, '')) : null;
        const diesel = dMatch ? parseFloat(dMatch[1].replace(/,/g, '')) : null;
        
        if (!petrol || !diesel) {
           console.log(`Failed to parse fuel for ${city}`);
           continue; // Skip if invalid
        }

        const newRecord = {
          city: cityInfo.displayName.charAt(0).toUpperCase() + cityInfo.displayName.slice(1),
          state: cityInfo.state,
          petrol: petrol,
          diesel: diesel,
          cng: cMatch ? parseFloat(cMatch[1].replace(/,/g, '')) : 82.16,
          png: pngMatch ? parseFloat(pngMatch[1].replace(/,/g, '')) : 49.60,
          lpg: domesticLpg,
          commercial_lpg: commercialLpg,
          updated_at: new Date().toISOString()
        };

        fuelResults.push(newRecord);

        // Check for price changes
        const existing = existingMap.get(city);
        if (existing && (existing.petrol !== newRecord.petrol || existing.diesel !== newRecord.diesel)) {
            anyPriceChanged = true;
        }

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
            const pricePerGram = (goldData.price / 31.1035) * 1.15;
            gold24k = Math.round(pricePerGram * 10);
            gold22k = Math.round(gold24k * 0.9167); 
          }

          if (silverData && silverData.price) {
            const pricePerGram = (silverData.price / 31.1035) * 1.15;
            silver = Math.round(pricePerGram * 1000);
          }
        } catch (apiErr) {
          console.error("API Fetch Error:", apiErr);
        }

        commodityResults.push({
          city: cityInfo.displayName.charAt(0).toUpperCase() + cityInfo.displayName.slice(1),
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
        supabase.from("fuel_price_history").insert(fuelResults.map(r => {
          const { updated_at, ...historyRecord } = r;
          return { ...historyRecord, recorded_at: new Date().toISOString() };
        })),
        supabase.from("commodity_prices").upsert(commodityResults, { onConflict: "city,state" })
      ]);
      
      // Notify users if prices changed
      if (anyPriceChanged) {
        try {
          await getMessaging().send({
            topic: 'fuel_prices_update',
            notification: {
              title: "⛽ Fuel Prices Updated!",
              body: "Check the latest Petrol and Diesel prices in your city.",
            },
            data: { route: 'fuel_prices' }
          });
          console.log("Push notification sent to topic 'fuel_prices_update'");
        } catch (fcmErr) {
          console.error("FCM Send Error:", fcmErr);
        }
      }
    }

    return new Response(JSON.stringify({ 
      success: true, 
      message: `${fuelResults.length} cities updated (Fuel + Gold + Silver)`,
      pricesChanged: anyPriceChanged
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
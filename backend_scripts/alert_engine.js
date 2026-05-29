require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const serviceAccount = require('./firebase-admin.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const WebSocket = require('ws');
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false },
  realtime: { transport: WebSocket },
});

// --- Caching Mechanism ---
const CACHE_FILE = path.join(__dirname, 'sent_alerts_cache.json');
let alertCache = { date: '', alerts: {} };

function loadCache() {
  const today = new Date().toISOString().split('T')[0];
  try {
    if (fs.existsSync(CACHE_FILE)) {
      const data = JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
      if (data.date === today) {
        alertCache = data;
        return;
      }
    }
  } catch (e) {
    console.error("Cache read error:", e);
  }
  // If different day or error, reset cache
  alertCache = { date: today, alerts: {} };
  saveCache();
}

function saveCache() {
  try {
    fs.writeFileSync(CACHE_FILE, JSON.stringify(alertCache, null, 2));
  } catch (e) {
    console.error("Cache write error:", e);
  }
}

function hasSentToday(key) {
  return !!alertCache.alerts[key];
}

function markAsSentToday(key) {
  alertCache.alerts[key] = true;
  saveCache();
}

async function runWeatherAlerts() {
  console.log(`[${new Date().toISOString()}] Starting Weather Alert Engine...`);
  
  const { data: weatherData, error } = await supabase
    .from('india_weather_data')
    .select('location_name, temperature, precipitation_1h, forecast_14d');

  if (error || !weatherData) {
    console.error("Error fetching weather data:", error);
    return;
  }

  const currentHour = new Date().getHours();

  for (const loc of weatherData) {
    const city = loc.location_name;
    const topic = `weather_${city.replace(/[^a-zA-Z0-9]/g, '_')}`;

    // 1. Rain Alerts (10mm, 20mm, 30mm, 40mm, 50mm+)
    const rainNow = loc.precipitation_1h;
    if (rainNow >= 10) {
      let rainLevel = Math.floor(rainNow / 10) * 10;
      const rainKey = `weather_${city}_rain_${rainLevel}`;

      if (!hasSentToday(rainKey)) {
        let title = `🌧️ ${city}: बारिश अपडेट`;
        let body = `आपके क्षेत्र में ${rainLevel}mm से ज्यादा बारिश दर्ज की गई है (${rainNow} mm)।`;

        if (rainLevel >= 50) {
          title = `🚨 ${city}: भारी बारिश अलर्ट`;
          body = `आपके क्षेत्र में भारी बारिश (${rainNow} mm) हो रही है! सावधान रहें।`;
        }

        await admin.messaging().send({
          notification: { title, body },
          data: { type: 'weather', city: city },
          topic: topic
        }).catch(e => console.error(e));
        
        console.log(`Sent Rain Alert (${rainLevel}mm) to ${topic}`);
        markAsSentToday(rainKey);
      }
    }

    // 1.5 Future Extreme Weather Forecast Warning (once a day at 7 AM)
    if (currentHour === 7 && loc.forecast_14d?.time) {
      for (let i = 0; i < loc.forecast_14d.time.length; i++) {
        const rain = loc.forecast_14d.precipitation_sum?.[i] || 0;
        const wind = loc.forecast_14d.wind_speed_10m_max?.[i] || 0;
        
        if (rain >= 50 || wind >= 60) {
          const targetDate = new Date(loc.forecast_14d.time[i]);
          const todayDate = new Date();
          // Reset times to compare dates properly
          targetDate.setHours(0,0,0,0);
          todayDate.setHours(0,0,0,0);
          
          const diffDays = Math.round((targetDate - todayDate) / (1000 * 60 * 60 * 24));
          const forecastKey = `weather_${city}_storm_${targetDate.toISOString().split('T')[0]}`;
          
          if (!hasSentToday(forecastKey)) {
            let dayText = diffDays === 0 ? "आज" : (diffDays === 1 ? "कल" : `${diffDays} दिन बाद`);
            const bodyText = `${dayText} भारी बारिश (${rain}mm) या तूफ़ान (${wind}km/h) की सम्भावना है! सतर्क रहें।`;
            
            await admin.messaging().send({
              notification: {
                title: `⚠️ ${city}: मौसम चेतावनी`,
                body: bodyText,
              },
              data: { type: 'weather', city: city },
              topic: topic
            }).catch(e => console.error(e));
            
            console.log(`Sent Forecast Warning for ${city} (${dayText})`);
            markAsSentToday(forecastKey);
          }
          break; // only send warning for the FIRST upcoming storm day
        }
      }
    }

    // 2. Regular Morning / Evening Updates
    if (currentHour === 6 || currentHour === 7) {
      const morningKey = `weather_${city}_morning`;
      if (!hasSentToday(morningKey)) {
        const todayMax = loc.forecast_14d?.temperature_2m_max?.[0] || loc.temperature;
        await admin.messaging().send({
          notification: {
            title: `🌤️ ${city}: आज का मौसम`,
            body: `आज तापमान ${todayMax}°C तक जा सकता है। विस्तृत जानकारी के लिए ऐप देखें।`,
          },
          data: { type: 'weather', city: city },
          topic: topic
        }).catch(e => console.error(e));
        console.log(`Sent Morning Weather Alert to ${topic}`);
        markAsSentToday(morningKey);
      }
    } else if (currentHour === 17 || currentHour === 18) {
      const eveningKey = `weather_${city}_evening`;
      if (!hasSentToday(eveningKey)) {
        const tomorrowMin = loc.forecast_14d?.temperature_2m_min?.[1] || loc.temperature;
        await admin.messaging().send({
          notification: {
            title: `🌙 ${city}: शाम का मौसम अपडेट`,
            body: `कल न्यूनतम तापमान ${tomorrowMin}°C रहने की संभावना है। शुभ रात्रि!`,
          },
          data: { type: 'weather', city: city },
          topic: topic
        }).catch(e => console.error(e));
        console.log(`Sent Evening Weather Alert to ${topic}`);
        markAsSentToday(eveningKey);
      }
    }
  }
}

async function runMandiAlerts() {
  console.log(`[${new Date().toISOString()}] Starting Mandi Alert Engine...`);
  
  const today = new Date();
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

  const { data: prices, error } = await supabase
    .from('mandi_prices')
    .select('district, mandi_name, commodity_name, modal_price')
    .eq('arrival_date', todayStr)
    .order('modal_price', { ascending: false })
    .limit(100);

  if (error || !prices || prices.length === 0) return;

  const districtAlerts = {};
  for (const price of prices) {
    const dist = (price.district || 'Unknown').toLowerCase().replace(/\s+/g, '_');
    if (!districtAlerts[dist]) districtAlerts[dist] = [];
    if (districtAlerts[dist].length < 3) districtAlerts[dist].push(price);
  }

  for (const [dist, items] of Object.entries(districtAlerts)) {
    if (dist === 'unknown') continue;
    const mandiKey = `mandi_${dist}`;
    if (hasSentToday(mandiKey)) continue;

    const topic = `mandi_${dist}`;
    const mainItem = items[0];
    
    await admin.messaging().send({
      notification: {
        title: `🌾 ${mainItem.district.toUpperCase()} मंडी भाव अपडेट`,
        body: `${mainItem.commodity_name} का ताज़ा भाव ₹${mainItem.modal_price}/Quintal (${mainItem.mandi_name} मंडी)।`,
      },
      data: { type: 'mandi', district: mainItem.district },
      topic: topic
    }).catch(e => console.error(e));
    
    console.log(`Sent Mandi Alert for ${dist}`);
    markAsSentToday(mandiKey);
  }
}

async function runFestivalAlerts() {
  const festivals = {
    "01-14": { title: "मकर संक्रांति की शुभकामनाएँ! 🪁", body: "भारत के सभी किसानों को मकर संक्रांति, पोंगल और लोहड़ी की हार्दिक शुभकामनाएँ।" },
    "04-13": { title: "बैसाखी की शुभकामनाएँ! 🌾", body: "किसानों का पर्व बैसाखी आपके जीवन में खुशहाली लाये।" },
    "10-31": { title: "दीपावली की हार्दिक शुभकामनाएँ! 🪔", body: "भारत फ्लो की तरफ से शुभ दीपावली! लक्ष्मी माता आपके खेतों को धन-धान्य से भर दें।" },
  };

  const today = new Date();
  const mm_dd = `${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  const festivalKey = `festival_${mm_dd}`;
  
  if (festivals[mm_dd] && today.getHours() === 7) { 
    if (!hasSentToday(festivalKey)) {
      await admin.messaging().send({
        notification: {
          title: festivals[mm_dd].title,
          body: festivals[mm_dd].body,
        },
        data: { type: 'festival' },
        topic: 'all_users'
      }).catch(e => console.error(e));
      console.log(`Sent Festival Alert for ${mm_dd}`);
      markAsSentToday(festivalKey);
    }
  }
}

async function runKisanMarketAlerts() {
  console.log(`[${new Date().toISOString()}] Starting Kisan Market Matcher (Queue Based)...`);
  
  const { data: matches, error } = await supabase
    .from('store_matches')
    .select('id, matched_user_id, commodity, district, type, seller_name')
    .eq('is_sent', false)
    .limit(50);

  if (error || !matches || matches.length === 0) return;

  for (const match of matches) {
    const { data: profileData } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', match.matched_user_id)
      .single();
      
    if (profileData && profileData.fcm_token) {
      const title = match.type === 'SELL' ? '🎉 नया विक्रेता मिला!' : '🎉 नया खरीदार मिला!';
      const body = match.type === 'SELL' 
        ? `${match.district} में ${match.commodity} के लिए नया विक्रेता (${match.seller_name}) उपलब्ध है। अभी संपर्क करें!`
        : `${match.district} में ${match.commodity} के लिए नया खरीदार (${match.seller_name}) उपलब्ध है। अभी संपर्क करें!`;

      await admin.messaging().send({
        notification: { title, body },
        data: { type: 'store_match', commodity: match.commodity },
        token: profileData.fcm_token
      }).catch(e => console.error("FCM Error for Match:", e));
      
      console.log(`Notified user ${match.matched_user_id} about match for ${match.commodity}`);
    }
    
    // Mark as sent
    await supabase.from('store_matches').update({ is_sent: true }).eq('id', match.id);
  }
}

async function main() {
  loadCache();
  await runWeatherAlerts();
  await runMandiAlerts();
  await runFestivalAlerts();
  await runKisanMarketAlerts();
  console.log(`[${new Date().toISOString()}] All Alert Engines Completed.`);
  process.exit(0);
}

main().catch(console.error);

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const gnewsApiKey = Deno.env.get("GNEWS_API_KEY")!;
const geminiApiKey = Deno.env.get("GEMINI_API_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req) => {
  try {
    console.log("🚀 News Fetch Triggered...");
    
    // 1. Fetch from GNews
    const lang = "hi";
    const queries = ['खेती', 'किसान', 'मंडी भाव', 'कृषि समाचार'];
    const q = queries.join(' OR ');
    const url = `https://gnews.io/api/v4/search?q=${encodeURIComponent(q)}&lang=${lang}&country=in&max=10&sortby=publishedAt&apikey=${gnewsApiKey}`;
    
    const response = await fetch(url);
    const data = await response.json();
    const articles = data.articles || [];
    
    console.log(`📦 Received ${articles.length} articles from GNews`);
    
    const newsItems = [];
    const currentYear = new Date().getFullYear();

    for (const art of articles) {
      let published = new Date(art.publishedAt);
      if (published.getFullYear() < currentYear) {
         published.setFullYear(currentYear);
      }

      // 2. AI Rewrite via direct Gemini HTTP call
      let title = art.title;
      let summary = art.description || art.title;

      try {
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`;
        const aiRes = await fetch(geminiUrl, {
          method: 'POST',
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: `Rewrite this agricultural news for 'Bharat Flow' app. Make it professional for Indian farmers. Language: Hindi. Format: JSON only with 'title' and 'summary' keys. No extra text. Original Title: ${art.title}. Original Description: ${art.description}` }] }]
          })
        });
        
        const aiData = await aiRes.json();
        const text = aiData.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
           const cleanJson = text.replace(/```json|```/g, '').trim();
           const parsed = JSON.parse(cleanJson);
           title = parsed.title || title;
           summary = parsed.summary || summary;
        }
      } catch (e) {
        console.error(`⚠️ AI Rewrite failed for: ${art.title}`, e);
      }

      newsItems.push({
        title,
        summary,
        content: art.content || '',
        image_url: art.image,
        source_url: art.url,
        published_at: published.toISOString()
      });
    }

    // 3. Upsert to Supabase
    if (newsItems.length > 0) {
      const { error } = await supabase.from('app_news').upsert(newsItems, { onConflict: 'source_url' });
      if (error) throw error;
      console.log(`✅ Successfully upserted ${newsItems.length} unique news items.`);
    }

    // 4. Cleanup old news (> 15 days)
    const oldLimit = new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString();
    await supabase.from('app_news').delete().lt('published_at', oldLimit);

    return new Response(JSON.stringify({ success: true, count: newsItems.length }), { 
      headers: { "Content-Type": "application/json" } 
    });

  } catch (error) {
    console.error("❌ News Fetch Error:", error);
    return new Response(JSON.stringify({ error: error.message }), { 
      status: 500, 
      headers: { "Content-Type": "application/json" } 
    });
  }
});

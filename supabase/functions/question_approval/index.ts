import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || "re_XN3oz6b9_Ftg6263oNhDkzkCwZN3JyAvY";
const TARGET_EMAIL = "paresh101p@gmail.com";

async function sendResendEmail(subject: string, htmlContent: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: "BharatFlow Q&A <onboarding@resend.dev>",
      to: TARGET_EMAIL,
      subject: subject,
      html: htmlContent
    })
  });
  return await res.json();
}

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    
    if (!record || record.status !== 'pending') {
      return new Response("Not a pending question", { status: 200 });
    }

    const { id, user_name, user_city, category, question_text, image_url, voice_url } = record;

    let mediaHtml = "";
    if (image_url) {
      mediaHtml += `<div style="margin: 20px 0;"><img src="${image_url}" style="max-width:100%; border-radius: 8px; border: 1px solid #e0e0e0;"/></div>`;
    }
    if (voice_url) {
      mediaHtml += `<div style="margin: 20px 0;"><a href="${voice_url}" style="padding: 10px 15px; background: #e3f2fd; color: #1565c0; text-decoration: none; border-radius: 5px;">🔊 Listen to Voice Message</a></div>`;
    }

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
        <div style="background: #2E7D32; color: white; padding: 15px; text-align: center; border-radius: 8px 8px 0 0;">
          <h2 style="margin:0;">🚨 New Farmer Question</h2>
        </div>
        
        <div style="padding: 20px; background: #fafafa;">
          <p><strong>Name:</strong> ${user_name || 'Kisan'}</p>
          <p><strong>Location:</strong> ${user_city || 'Unknown'}</p>
          <p><strong>Category:</strong> ${category || 'General'}</p>
          
          <div style="background: white; padding: 15px; border-left: 4px solid #FF9800; margin: 20px 0; font-size: 16px;">
            "${question_text || '(Voice Message Only)'}"
          </div>
          
          ${mediaHtml}
        </div>
        
        <div style="text-align: center; margin-top: 30px;">
          <a href="https://paresh101p-jpg.github.io/BharatFlow/helpline_reply.html?id=${id}&token=re_XN3oz6b9_Ftg6263oNhDkzkCwZN3JyAvY" 
             style="background: #1B5E20; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 16px; display: inline-block;">
             🔍 Moderate & Reply
          </a>
        </div>
      </div>
    `;

    await sendResendEmail(`New Q&A: ${user_name || 'Kisan'} asked a question`, html);
    return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });

  } catch (err) {
    console.error(err);
    return new Response(String(err?.message ?? err), { status: 500 });
  }
});

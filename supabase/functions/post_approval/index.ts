import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || "re_XN3oz6b9_Ftg6263oNhDkzkCwZN3JyAvY";
const TARGET_EMAIL = "paresh101p@gmail.com";
const TOKEN = "re_XN3oz6b9_Ftg6263oNhDkzkCwZN3JyAvY";

async function sendResendEmail(subject: string, htmlContent: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: "BharatFlow System <onboarding@resend.dev>",
      to: TARGET_EMAIL,
      subject: subject,
      html: htmlContent
    })
  });
  return await res.json();
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const payload = await req.json();
    const record = payload.record;
    
    if (!record || record.status !== "pending") {
      return new Response("Not a pending post or invalid payload", { status: 200 });
    }

    const id = record.id;
    const cb = Date.now();
    const approveUrl = `https://paresh101p-jpg.github.io/BharatFlow/moderate.html?id=${id}&action=approve&token=${TOKEN}&cb=${cb}`;
    const rejectUrl = `https://paresh101p-jpg.github.io/BharatFlow/moderate.html?id=${id}&action=reject&token=${TOKEN}&cb=${cb}`;

    const htmlContent = `
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
        <h2 style="color: #0f172a;">New Post Needs Approval</h2>
        <p><strong>Post ID:</strong> ${id}</p>
        <p><strong>Type:</strong> ${record.type || 'SELL'}</p>
        <p><strong>Commodity:</strong> ${record.commodity || 'N/A'}</p>
        <p><strong>Quantity:</strong> ${record.quantity || 'N/A'} ${record.unit || ''}</p>
        <p><strong>Price:</strong> ₹${record.price || 'N/A'}</p>
        <p><strong>User/Seller:</strong> ${record.user_name || 'N/A'} (${record.contact_name || ''})</p>
        <p><strong>Location:</strong> ${record.district || 'N/A'}, ${record.state || 'N/A'}</p>
        ${record.image_url ? `<div style="margin: 20px 0;"><img src="${record.image_url}" alt="Product Image" style="max-width: 100%; border-radius: 8px;" /></div>` : ''}
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
        
        <div style="text-align: center; margin-top: 30px;">
          <a href="${approveUrl}" style="background-color: #10b981; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; margin-right: 10px; display: inline-block;">Approve Post</a>
          <a href="${rejectUrl}" style="background-color: #ef4444; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">Reject Post</a>
        </div>
      </div>
    `;

    const resendResponse = await sendResendEmail("New Post Approval Required: " + (record.commodity || 'Unknown'), htmlContent);
    console.log("Resend API response:", resendResponse);

    return new Response(JSON.stringify({ success: true, email: resendResponse }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error: any) {
    console.error("Error sending email:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});

// MedAsi Core fallback alerter.
//
// Fires a Resend email when a Core call fails and the app falls back to the
// local provider. The user is NOT affected (fallback handles the request); this
// only notifies ops that Core had a problem. Throttled (one mail per cooldown)
// and fire-and-forget — it never throws into the request path and never blocks
// the response. Reuses the existing Resend key already in the edge env (SMTP_PASS).

let lastCoreAlertMs = 0;
const CORE_ALERT_COOLDOWN_MS = 15 * 60 * 1000; // 15 dakikada en fazla 1 mail

export function alertCoreFallback(app: string, context: string, error: unknown): void {
  try {
    const now = Date.now();
    if (now - lastCoreAlertMs < CORE_ALERT_COOLDOWN_MS) return;

    const apiKey = (Deno.env.get("RESEND_API_KEY") || Deno.env.get("SMTP_PASS") || "").trim();
    if (!apiKey) return;
    lastCoreAlertMs = now;

    const from = (Deno.env.get("CORE_ALERT_FROM") || Deno.env.get("SMTP_ADMIN_EMAIL") ||
      "noreply@medasi.com.tr").trim();
    const to = (Deno.env.get("CORE_ALERT_TO") || "kemal.tuncer@medasi.com.tr").trim();
    const message = error instanceof Error ? error.message : String(error);

    void fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `MedAsi Core Alert <${from}>`,
        to: [to],
        subject: `⚠️ MedAsi Core fallback — ${app} / ${context}`,
        text: [
          "MedAsi Core çağrısı başarısız oldu; uygulama yerel sağlayıcıya düştü.",
          "Kullanıcı ETKİLENMEDİ (fallback devrede).",
          "",
          `App: ${app}`,
          `Context: ${context}`,
          `Hata: ${message}`,
          `Zaman: ${new Date().toISOString()}`,
          "",
          "Core sağlığı: https://core.medasi.com.tr/health",
          "",
          `(Bu uyarı en fazla ${CORE_ALERT_COOLDOWN_MS / 60000} dakikada bir gönderilir.)`,
        ].join("\n"),
      }),
    }).catch(() => {});
  } catch {
    // Alerting must never break the request path.
  }
}

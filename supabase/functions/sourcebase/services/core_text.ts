import type { TextGenerationResult } from "./openai-provider.ts";

// Calls MedAsi Core's text-generation endpoint (runs the provider call on the
// storage server). Returns null when Core is not configured, so the caller can
// fall back to its local provider. Throws on a Core error so the caller's catch
// can fall back + alert. Returns the same { text, inputTokens, outputTokens }
// shape the local providers return.
export async function generateTextViaCore(
  provider: string,
  payload: {
    model?: string;
    systemInstruction: string;
    prompt: string;
    maxTokens?: number;
    temperature?: number;
  },
): Promise<TextGenerationResult | null> {
  const coreUrl = (Deno.env.get("MEDASI_CORE_URL") || "").trim().replace(/\/+$/, "");
  if (!coreUrl) return null;
  const coreKey = Deno.env.get("MEDASI_CORE_KEY") || "";

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 160_000);
  try {
    const response = await fetch(`${coreUrl}/v1/aicenter/text/generate`, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "content-type": "application/json",
        "x-medasi-app": "sourcebase",
        ...(coreKey ? { "x-medasi-core-key": coreKey } : {}),
      },
      body: JSON.stringify({ provider, ...payload }),
    });
    if (!response.ok) throw new Error(`core text generate ${response.status}`);
    const data = await response.json();
    if (typeof data?.text !== "string" || !data.text.trim()) {
      throw new Error("core text generate returned empty");
    }
    return {
      text: data.text,
      inputTokens: Number(data.inputTokens ?? 0),
      outputTokens: Number(data.outputTokens ?? 0),
    };
  } finally {
    clearTimeout(timeout);
  }
}

import { SafeError } from "../types.ts";
import type { GenerationOptions } from "./ai-generation-provider.ts";
import { generateTextViaCore } from "./core_text.ts";
import { alertCoreFallback } from "./core_alert.ts";

export interface TextGenerationResult {
  text: string;
  inputTokens: number;
  outputTokens: number;
}

export class OpenAIProvider {
  constructor(private apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "") {}

  // Prefers MedAsi Core (runs the provider call on the storage server). On any
  // Core error/timeout it falls back to the local call so live never breaks.
  async generateText(
    prompt: string,
    systemInstruction: string,
    options: GenerationOptions,
  ): Promise<TextGenerationResult> {
    try {
      const viaCore = await generateTextViaCore("openai-responses", {
        model: options.model,
        systemInstruction,
        prompt,
        maxTokens: options.maxTokens,
      });
      if (viaCore) return viaCore;
    } catch (error) {
      console.error(
        "sourcebase_core_openai_responses_fallback_local",
        error instanceof Error ? error.message : String(error),
      );
      alertCoreFallback("sourcebase", "openai-responses", error);
    }
    return this.generateTextLocal(prompt, systemInstruction, options);
  }

  private async generateTextLocal(
    prompt: string,
    systemInstruction: string,
    options: GenerationOptions,
  ): Promise<TextGenerationResult> {
    if (!this.apiKey) {
      throw new SafeError(
        "OPENAI_NOT_CONFIGURED",
        "AI üretim sağlayıcısı yapılandırılmamış.",
        500,
      );
    }
    const body = JSON.stringify({
      model: options.model,
      input: [
        { role: "system", content: systemInstruction },
        { role: "user", content: prompt },
      ],
      max_output_tokens: options.maxTokens ?? 2048,
    });
    // Transient OpenAI failures (5xx, 429, connection reset/timeout) are common and
    // were hard-failing whole generations. Retry with backoff; only 4xx (real
    // request errors) and auth are non-retryable.
    const maxAttempts = 3;
    let response: Response | undefined;
    let lastErr = "";
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 150_000);
      try {
        response = await fetch("https://api.openai.com/v1/responses", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            "Content-Type": "application/json",
          },
          body,
          signal: controller.signal,
        });
      } catch (error) {
        lastErr = String(error);
        response = undefined;
      } finally {
        clearTimeout(timer);
      }

      if (response) {
        if (response.status === 401 || response.status === 403) {
          console.error("OpenAI request rejected:", response.status);
          throw new SafeError(
            "OPENAI_AUTH_FAILED",
            "AI üretim sağlayıcısı kimlik doğrulaması başarısız.",
            500,
          );
        }
        if (response.ok) break;
        const errBody = await response.text().catch(() => "");
        lastErr = `${response.status} ${errBody.slice(0, 400)}`;
        console.error(
          "OpenAI upstream error:",
          response.status,
          "model:",
          options.model,
          "attempt:",
          attempt,
          "body:",
          errBody.slice(0, 400),
        );
        const retryable = response.status === 429 || response.status >= 500;
        if (!retryable) {
          throw new SafeError(
            "OPENAI_UPSTREAM_ERROR",
            "AI servisine ulaşılamadı.",
            502,
          );
        }
        response = undefined;
      } else {
        console.error(
          "OpenAI request failed:",
          options.model,
          "attempt:",
          attempt,
          lastErr.slice(0, 200),
        );
      }

      if (attempt < maxAttempts) {
        await new Promise((r) => setTimeout(r, attempt * 2000));
      }
    }

    if (!response || !response.ok) {
      throw new SafeError(
        "OPENAI_UPSTREAM_ERROR",
        "AI servisine ulaşılamadı.",
        502,
      );
    }
    const data = await response.json().catch(() => ({}));
    const text = data.output_text?.toString() ||
      extractResponsesText(data.output);
    if (!text.trim()) {
      throw new SafeError("EMPTY_AI_OUTPUT", "AI çıktısı boş döndü.", 500);
    }
    return {
      text,
      inputTokens: Number(data.usage?.input_tokens ?? 0),
      outputTokens: Number(data.usage?.output_tokens ?? 0),
    };
  }
}

function extractResponsesText(output: unknown) {
  if (!Array.isArray(output)) return "";
  const chunks: string[] = [];
  for (const item of output) {
    const content = item?.content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      const text = part?.text?.toString() ?? "";
      if (text) chunks.push(text);
    }
  }
  return chunks.join("\n").trim();
}

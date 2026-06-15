import { SafeError } from "../types.ts";
import {
  ImageRoute,
  isImageProviderAvailable,
  resolveImageRoute,
  RouteOptions,
} from "./model-router.ts";

// Premium gpt-image-2 portrait (1024x1536, high quality) regularly needs 90-150s.
// Generation runs in the background (EdgeRuntime.waitUntil, ~5min worker) so this
// can be generous; 90s was cutting premium images off → IMAGE_UPSTREAM_TIMEOUT.
const DEFAULT_IMAGE_UPSTREAM_TIMEOUT_MS = 180_000;

export interface GeneratedImage {
  provider: string;
  model: string;
  mimeType: string;
  dataUrl?: string;
  url?: string;
  prompt: string;
}

export async function generateInfographicImage(
  spec: unknown,
  options: RouteOptions = {},
): Promise<GeneratedImage> {
  const route = resolveImageRoute(options.imageQuality, options.imageModel);
  const prompt = buildInfographicImagePrompt(spec);
  try {
    return await generateWithRoute(route, prompt, false);
  } catch (error) {
    if (
      route.provider !== route.fallbackProvider &&
      isImageProviderAvailable(route.fallbackProvider)
    ) {
      return await generateWithRoute(route, prompt, true);
    }
    if (error instanceof SafeError) throw error;
    throw new SafeError(
      "IMAGE_GENERATION_FAILED",
      "İnfografik görseli üretilemedi.",
      500,
    );
  }
}

export function buildInfographicImagePrompt(spec: unknown) {
  const source = JSON.stringify(spec).slice(0, 5000);
  return `Türkçe medikal infografik üret.
- Premium akademik tıp eğitimi hissi ver.
- Dikey infografik düzeni kullan.
- Yazılar okunaklı, temiz ve sınav sabahı hızlı tekrar için uygun olsun.
- Robot, neon, yapay zeka klişesi, sahte tıbbi iddia veya kaynak dışı kesin ifade kullanma.
- Model metinleri bozacaksa text-light infographic üret; ayrıntılı açıklama uygulama içinde ayrıca gösterilecek.
- MedAsi/SourceBase ile uyumlu temiz klinik renk paleti kullan.

İnfografik içerik planı:
${source}`;
}

async function generateWithRoute(
  route: ImageRoute,
  prompt: string,
  useFallback: boolean,
): Promise<GeneratedImage> {
  const provider = useFallback ? route.fallbackProvider : route.provider;
  const model = useFallback ? route.fallbackModel : route.model;
  if (!isImageProviderAvailable(provider)) {
    throw new SafeError(
      "IMAGE_PROVIDER_NOT_CONFIGURED",
      "İnfografik görsel sağlayıcısı yapılandırılmamış.",
      500,
    );
  }
  if (provider === "openai") {
    return await generateOpenAIImage(model, prompt, route.quality);
  }
  return await generateStabilityImage(model, prompt);
}

async function generateOpenAIImage(
  model: string,
  prompt: string,
  quality: ImageRoute["quality"],
): Promise<GeneratedImage> {
  const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
  const response = await fetchImageUpstream(
    "https://api.openai.com/v1/images/generations",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        prompt,
        quality: openAiQuality(model, quality),
        size: "1024x1536",
        n: 1,
      }),
    },
  );
  if (response.status === 401 || response.status === 403) {
    console.error("OpenAI image request rejected:", response.status);
    throw new SafeError(
      "IMAGE_AUTH_FAILED",
      "İnfografik görsel sağlayıcısı kimlik doğrulaması başarısız.",
      500,
    );
  }
  if (!response.ok) {
    console.error("OpenAI image upstream error:", response.status);
    throw new SafeError(
      "IMAGE_UPSTREAM_ERROR",
      "İnfografik görsel servisine ulaşılamadı.",
      502,
    );
  }
  const data = await response.json().catch(() => ({}));
  const image = Array.isArray(data.data) ? data.data[0] : undefined;
  const b64 = image?.b64_json?.toString();
  const url = image?.url?.toString();
  if (!b64 && !url) {
    throw new SafeError(
      "IMAGE_EMPTY",
      "İnfografik görsel çıktısı boş döndü.",
      500,
    );
  }
  return {
    provider: "openai",
    model,
    mimeType: "image/png",
    dataUrl: b64 ? `data:image/png;base64,${b64}` : undefined,
    url,
    prompt,
  };
}

async function generateStabilityImage(
  model: string,
  prompt: string,
): Promise<GeneratedImage> {
  const apiKey = Deno.env.get("STABILITY_API_KEY")?.trim() ?? "";
  const form = new FormData();
  form.set("prompt", prompt);
  form.set("output_format", "png");
  const response = await fetchImageUpstream(
    "https://api.stability.ai/v2beta/stable-image/generate/ultra",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: "application/json",
      },
      body: form,
    },
  );
  if (response.status === 401 || response.status === 403) {
    console.error("Stability image request rejected:", response.status);
    throw new SafeError(
      "IMAGE_AUTH_FAILED",
      "İnfografik görsel sağlayıcısı kimlik doğrulaması başarısız.",
      500,
    );
  }
  if (!response.ok) {
    console.error("Stability image upstream error:", response.status);
    throw new SafeError(
      "IMAGE_UPSTREAM_ERROR",
      "İnfografik görsel servisine ulaşılamadı.",
      502,
    );
  }
  const data = await response.json().catch(() => ({}));
  const b64 = data.image?.toString() ?? "";
  if (!b64) {
    throw new SafeError(
      "IMAGE_EMPTY",
      "İnfografik görsel çıktısı boş döndü.",
      500,
    );
  }
  return {
    provider: "stability",
    model,
    mimeType: "image/png",
    dataUrl: `data:image/png;base64,${b64}`,
    prompt,
  };
}

function openAiQuality(model: string, quality: ImageRoute["quality"]) {
  if (quality === "draft") return "low";
  if (quality === "premium") return "high";
  return "medium";
}

async function fetchImageUpstream(
  input: string,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), imageTimeoutMs());
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (isAbortError(error)) {
      console.error("Image upstream request timed out:", input);
      throw new SafeError(
        "IMAGE_UPSTREAM_TIMEOUT",
        "İnfografik görsel servisi zaman aşımına uğradı.",
        504,
      );
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function imageTimeoutMs() {
  const configured = Number(
    Deno.env.get("SOURCEBASE_IMAGE_TIMEOUT_MS") ??
      Deno.env.get("IMAGE_UPSTREAM_TIMEOUT_MS") ??
      "",
  );
  if (Number.isFinite(configured) && configured >= 5_000) {
    return Math.min(configured, 120_000);
  }
  return DEFAULT_IMAGE_UPSTREAM_TIMEOUT_MS;
}

function isAbortError(error: unknown) {
  return error instanceof Error && error.name === "AbortError";
}

import { SafeError } from "../types.ts";
import { PodcastScript } from "../types.ts";
import {
  PodcastAudioRoute,
  resolvePodcastAudioRoute,
  RouteOptions,
} from "./model-router.ts";

const DEFAULT_AUDIO_UPSTREAM_TIMEOUT_MS = 60_000;
// Per-request input ceiling for the OpenAI speech endpoint.
const MAX_CHARS_PER_REQUEST = 3_800;
// Total transcript budget synthesized into one episode (keeps the synchronous
// job within its time/cost envelope; longer scripts are narrated up to here and
// the remaining transcript still ships as text).
const MAX_TOTAL_CHARS = 12_000;
// How many speech requests run at once. Order is preserved on reassembly.
const TTS_CONCURRENCY = 3;

export interface GeneratedPodcastAudio {
  provider: "openai";
  model: string;
  mimeType: "audio/mpeg";
  dataUrl: string;
  voices: string[];
  characterCount: number;
  segmentCount: number;
  truncated: boolean;
}

interface SpeechChunk {
  voice: string;
  text: string;
}

/**
 * Podcast script -> tek parça mp3 ses.
 * Host ve uzman ayrı seslerle seslendirilir, segmentler sırayla birleştirilir.
 */
export async function generatePodcastAudio(
  script: PodcastScript,
  options: RouteOptions = {},
): Promise<GeneratedPodcastAudio> {
  const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
  if (!apiKey) {
    throw new SafeError(
      "AUDIO_PROVIDER_NOT_CONFIGURED",
      "Podcast ses sağlayıcısı yapılandırılmamış.",
      500,
    );
  }

  const route = resolvePodcastAudioRoute(options);
  const { chunks, truncated, characterCount } = planSpeechChunks(script, route);
  if (chunks.length === 0) {
    throw new SafeError(
      "AUDIO_SCRIPT_EMPTY",
      "Seslendirilecek podcast metni bulunamadı.",
      500,
    );
  }

  const parts = await synthesizeChunks(apiKey, route, chunks);
  const merged = concatAudioBuffers(parts);
  const dataUrl = `data:audio/mpeg;base64,${bytesToBase64(merged)}`;

  return {
    provider: "openai",
    model: route.model,
    mimeType: "audio/mpeg",
    dataUrl,
    voices: distinctVoices(chunks),
    characterCount,
    segmentCount: script.segments?.length ?? 0,
    truncated,
  };
}

export function planSpeechChunks(
  script: PodcastScript,
  route: PodcastAudioRoute,
): { chunks: SpeechChunk[]; truncated: boolean; characterCount: number } {
  const segments = Array.isArray(script.segments) ? script.segments : [];
  const chunks: SpeechChunk[] = [];
  let remaining = MAX_TOTAL_CHARS;
  let truncated = false;
  let characterCount = 0;

  for (const segment of segments) {
    if (remaining <= 0) {
      truncated = true;
      break;
    }
    const voice = voiceForSpeaker(segment?.speaker, route);
    const spoken = spokenText(segment?.text);
    if (!spoken) continue;

    const allowed = spoken.length > remaining
      ? spoken.slice(0, remaining)
      : spoken;
    if (allowed.length < spoken.length) truncated = true;
    remaining -= allowed.length;
    characterCount += allowed.length;

    for (const piece of splitForSpeech(allowed)) {
      chunks.push({ voice, text: piece });
    }
  }

  return { chunks, truncated, characterCount };
}

async function synthesizeChunks(
  apiKey: string,
  route: PodcastAudioRoute,
  chunks: SpeechChunk[],
): Promise<Uint8Array[]> {
  const parts = new Array<Uint8Array>(chunks.length);
  let cursor = 0;

  async function worker() {
    while (true) {
      const index = cursor++;
      if (index >= chunks.length) return;
      parts[index] = await synthesizeSpeech(apiKey, route, chunks[index]);
    }
  }

  const workers = Array.from(
    { length: Math.min(TTS_CONCURRENCY, chunks.length) },
    () => worker(),
  );
  await Promise.all(workers);
  return parts;
}

async function synthesizeSpeech(
  apiKey: string,
  route: PodcastAudioRoute,
  chunk: SpeechChunk,
): Promise<Uint8Array> {
  const response = await fetchAudioUpstream(
    "https://api.openai.com/v1/audio/speech",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: route.model,
        voice: chunk.voice,
        input: chunk.text,
        response_format: "mp3",
      }),
    },
  );
  if (response.status === 401 || response.status === 403) {
    console.error("OpenAI audio request rejected:", response.status);
    throw new SafeError(
      "AUDIO_AUTH_FAILED",
      "Podcast ses sağlayıcısı kimlik doğrulaması başarısız.",
      500,
    );
  }
  if (!response.ok) {
    console.error("OpenAI audio upstream error:", response.status);
    throw new SafeError(
      "AUDIO_UPSTREAM_ERROR",
      "Podcast ses servisine ulaşılamadı.",
      502,
    );
  }
  const buffer = new Uint8Array(await response.arrayBuffer());
  if (buffer.byteLength === 0) {
    throw new SafeError(
      "AUDIO_EMPTY",
      "Podcast ses çıktısı boş döndü.",
      500,
    );
  }
  return buffer;
}

function voiceForSpeaker(
  speaker: string | undefined,
  route: PodcastAudioRoute,
): string {
  const normalized = (speaker ?? "").toLowerCase();
  if (
    normalized.includes("expert") || normalized.includes("uzman") ||
    normalized.includes("guest") || normalized.includes("konuk") ||
    normalized.includes("doktor") || normalized.includes("hoca")
  ) {
    return route.expertVoice;
  }
  if (
    normalized.includes("host") || normalized.includes("sunucu") ||
    normalized.includes("moderator") || normalized.includes("anlatıcı") ||
    normalized.includes("narrator")
  ) {
    return route.hostVoice;
  }
  return route.narratorVoice;
}

function spokenText(text: unknown): string {
  return (text?.toString() ?? "")
    .replace(/\s+/g, " ")
    .trim();
}

export function splitForSpeech(text: string): string[] {
  if (text.length <= MAX_CHARS_PER_REQUEST) return [text];
  const pieces: string[] = [];
  const sentences = text.split(/(?<=[.!?…])\s+/);
  let current = "";
  for (const sentence of sentences) {
    if (sentence.length > MAX_CHARS_PER_REQUEST) {
      if (current) {
        pieces.push(current);
        current = "";
      }
      for (let i = 0; i < sentence.length; i += MAX_CHARS_PER_REQUEST) {
        pieces.push(sentence.slice(i, i + MAX_CHARS_PER_REQUEST));
      }
      continue;
    }
    if ((current + " " + sentence).trim().length > MAX_CHARS_PER_REQUEST) {
      if (current) pieces.push(current);
      current = sentence;
    } else {
      current = current ? `${current} ${sentence}` : sentence;
    }
  }
  if (current) pieces.push(current);
  return pieces.filter((piece) => piece.trim().length > 0);
}

export function concatAudioBuffers(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((sum, part) => sum + part.byteLength, 0);
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    merged.set(part, offset);
    offset += part.byteLength;
  }
  return merged;
}

function distinctVoices(chunks: SpeechChunk[]): string[] {
  return Array.from(new Set(chunks.map((chunk) => chunk.voice)));
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

async function fetchAudioUpstream(
  input: string,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), audioTimeoutMs());
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (isAbortError(error)) {
      throw new SafeError(
        "AUDIO_UPSTREAM_TIMEOUT",
        "Podcast ses servisi zaman aşımına uğradı.",
        504,
      );
    }
    throw new SafeError(
      "AUDIO_UPSTREAM_ERROR",
      "Podcast ses servisine ulaşılamadı.",
      502,
    );
  } finally {
    clearTimeout(timeout);
  }
}

function audioTimeoutMs(): number {
  const raw = Number(Deno.env.get("AUDIO_UPSTREAM_TIMEOUT_MS"));
  return Number.isFinite(raw) && raw > 0
    ? raw
    : DEFAULT_AUDIO_UPSTREAM_TIMEOUT_MS;
}

function isAbortError(error: unknown): boolean {
  return error instanceof DOMException && error.name === "AbortError";
}

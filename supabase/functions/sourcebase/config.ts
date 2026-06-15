import { SafeError } from "./types.ts";

export interface S3Config {
  publicEndpoint: string;
  provider: "s3";
  bucket: string;
  endpoint: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
}

export type ObjectStorageConfig = S3Config;

export function envValue(...names: string[]) {
  return firstEnv(...names);
}

export function getSupabaseUrl() {
  return envValue("SUPABASE_URL", "SOURCEBASE_SUPABASE_URL");
}

export function getSupabaseAnonKey() {
  return envValue(
    "SUPABASE_ANON_KEY",
    "SOURCEBASE_SUPABASE_PUBLIC_TOKEN",
    "SOURCEBASE_SUPABASE_ANON_KEY",
  );
}

export function getSupabaseServiceRoleKey() {
  return envValue(
    "SUPABASE_SERVICE_ROLE_KEY",
    "SOURCEBASE_SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_SERVICE_KEY",
  );
}

export function getAllowedOrigin() {
  return envValue("SOURCEBASE_ALLOWED_ORIGIN", "SOURCEBASE_PUBLIC_URL") ||
    "https://sourcebase.medasi.com.tr";
}

export function getObjectStorageConfig(): ObjectStorageConfig {
  const driver = envValue("STORAGE_DRIVER", "SOURCEBASE_STORAGE_DRIVER")
    .toLowerCase();
  const s3Bucket = canonicalFirst("S3_BUCKET", "SOURCEBASE_S3_BUCKET");
  const s3Endpoint = canonicalFirst("S3_ENDPOINT", "SOURCEBASE_S3_ENDPOINT");
  const s3AccessKey = canonicalFirst(
    "S3_ACCESS_KEY",
    "S3_ACCESS_KEY_ID",
    "SOURCEBASE_S3_ACCESS_KEY",
    "SOURCEBASE_S3_ACCESS_KEY_ID",
  );
  const s3SecretKey = canonicalFirst(
    "S3_SECRET_KEY",
    "S3_SECRET_ACCESS_KEY",
    "SOURCEBASE_S3_SECRET_KEY",
    "SOURCEBASE_S3_SECRET_ACCESS_KEY",
  );
  if (driver && driver !== "s3") {
    throw new SafeError(
      "S3_NOT_CONFIGURED",
      "S3 yükleme ayarları tamamlanmamış.",
      500,
    );
  }

  if (!s3Bucket || !s3Endpoint || !s3AccessKey || !s3SecretKey) {
    throw new SafeError(
      "S3_NOT_CONFIGURED",
      "S3 yükleme ayarları tamamlanmamış.",
      500,
    );
  }

  const s3PublicEndpoint = canonicalFirst(
    "S3_PUBLIC_ENDPOINT",
    "SOURCEBASE_S3_PUBLIC_ENDPOINT",
  ) || s3Endpoint;

  return {
    provider: "s3",
    bucket: s3Bucket,
    endpoint: normalizeEndpoint(s3Endpoint),
    publicEndpoint: normalizeEndpoint(s3PublicEndpoint),
    region: canonicalFirst("S3_REGION", "SOURCEBASE_S3_REGION") || "nbg1",
    accessKeyId: s3AccessKey,
    secretAccessKey: s3SecretKey,
  };
}

export function runtimeConfigStatus() {
  const openAiConfigured = Boolean(envValue("OPENAI_API_KEY"));
  const anthropicConfigured = Boolean(envValue("ANTHROPIC_API_KEY"));
  const stabilityConfigured = Boolean(envValue("STABILITY_API_KEY"));

  const s3Configured = Boolean(
    canonicalFirst("S3_BUCKET", "SOURCEBASE_S3_BUCKET") &&
      canonicalFirst("S3_ENDPOINT", "SOURCEBASE_S3_ENDPOINT") &&
      canonicalFirst(
        "S3_ACCESS_KEY",
        "S3_ACCESS_KEY_ID",
        "SOURCEBASE_S3_ACCESS_KEY",
        "SOURCEBASE_S3_ACCESS_KEY_ID",
      ) &&
      canonicalFirst(
        "S3_SECRET_KEY",
        "S3_SECRET_ACCESS_KEY",
        "SOURCEBASE_S3_SECRET_KEY",
        "SOURCEBASE_S3_SECRET_ACCESS_KEY",
      ),
  );
  const storageDriver = envValue("STORAGE_DRIVER", "SOURCEBASE_STORAGE_DRIVER")
    .toLowerCase();

  return {
    storage: {
      provider: storageDriver || "s3",
      s3Configured,
    },
    ai: {
      textProviderConfigured: openAiConfigured || anthropicConfigured,
      openAiConfigured,
      anthropicConfigured,
      imageProviderConfigured: openAiConfigured || stabilityConfigured,
      stabilityConfigured,
    },
    image: {
      openAiConfigured,
      stabilityConfigured,
      providerConfigured: openAiConfigured || stabilityConfigured,
    },
  };
}

function firstEnv(...names: string[]) {
  for (const name of names) {
    const value = Deno.env.get(name)?.trim();
    if (!value) continue;
    if (name.endsWith("_BASE64")) {
      const decoded = decodeBase64Env(value);
      if (decoded) return decoded;
      continue;
    }
    return stripWrappingQuotes(value);
  }
  return "";
}

function canonicalFirst(canonical: string, ...aliases: string[]) {
  if (hasEnv(canonical)) {
    return firstEnv(canonical);
  }
  return firstEnv(...aliases);
}

function hasEnv(name: string) {
  return Deno.env.get(name) !== undefined;
}

function stripWrappingQuotes(value: string) {
  if (value.length < 2) return value;
  const first = value.at(0);
  const last = value.at(-1);
  if ((first === `"` && last === `"`) || (first === "'" && last === "'")) {
    return value.slice(1, -1).trim();
  }
  return value;
}

function normalizeEndpoint(value: string) {
  const cleaned = value.trim().replace(/\/+$/, "");
  return /^https?:\/\//i.test(cleaned) ? cleaned : `https://${cleaned}`;
}

function decodeBase64Env(value: string) {
  try {
    return new TextDecoder().decode(
      Uint8Array.from(
        atob(stripWrappingQuotes(value)),
        (char) => char.charCodeAt(0),
      ),
    ).trim();
  } catch (_error) {
    return "";
  }
}

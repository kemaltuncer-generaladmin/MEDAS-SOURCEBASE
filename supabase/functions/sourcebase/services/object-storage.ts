import { ObjectStorageConfig } from "../config.ts";
import { SafeError } from "../types.ts";

export interface ObjectMetadata {
  name: string;
  contentLength: number;
  contentType: string;
}

export function objectStorageUrl(
  storage: ObjectStorageConfig,
  objectName: string,
) {
  return `${storage.provider}://${storage.bucket}/${objectName}`;
}

export async function createSignedPutUrl(input: {
  storage: ObjectStorageConfig;
  objectName: string;
  expiresInSeconds: number;
}) {
  return createS3PresignedUrl({
    storage: input.storage,
    method: "PUT",
    objectName: input.objectName,
    expiresInSeconds: input.expiresInSeconds,
    usePublicEndpoint: true,
  });
}

export async function createSignedReadUrl(input: {
  storage: ObjectStorageConfig;
  objectName: string;
  expiresInSeconds: number;
}) {
  return createS3PresignedUrl({
    storage: input.storage,
    method: "GET",
    objectName: input.objectName,
    expiresInSeconds: input.expiresInSeconds,
    usePublicEndpoint: true,
  });
}

export async function getObjectMetadata(input: {
  storage: ObjectStorageConfig;
  bucket: string;
  objectName: string;
}): Promise<ObjectMetadata> {
  assertExpectedBucket(input.storage, input.bucket);
  const response = await fetch(
    await createS3PresignedUrl({
      storage: input.storage,
      method: "GET",
      objectName: input.objectName,
      expiresInSeconds: 300,
      usePublicEndpoint: true,
    }),
    { headers: { Range: "bytes=0-0" } },
  );
  if (response.status === 404) {
    throw new SafeError(
      "FILE_OBJECT_MISSING",
      "Yüklenen dosya depolama alanında bulunamadı.",
      400,
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new SafeError(
      "STORAGE_AUTH_FAILED",
      "Dosya depolama kimlik doğrulaması başarısız.",
      500,
    );
  }
  if (!response.ok) {
    throw new SafeError(
      "UPLOAD_VERIFY_FAILED",
      "Yüklenen dosya doğrulanamadı.",
      500,
    );
  }

  const contentLength = contentLengthFromMetadataResponse(response);
  if (!Number.isFinite(contentLength) || contentLength <= 0) {
    throw new SafeError(
      "FILE_OBJECT_EMPTY",
      "Yüklenen dosya boş görünüyor.",
      400,
    );
  }

  return {
    name: input.objectName,
    contentLength,
    contentType: response.headers.get("content-type")?.toLowerCase().trim() ??
      "",
  };
}

function contentLengthFromMetadataResponse(response: Response) {
  const contentRange = response.headers.get("content-range") ?? "";
  const totalMatch = contentRange.match(/\/(\d+)$/);
  if (totalMatch) return Number(totalMatch[1]);
  return Number(response.headers.get("content-length") ?? 0);
}

export async function downloadObject(input: {
  storage: ObjectStorageConfig;
  bucket: string;
  objectName: string;
}): Promise<ArrayBuffer> {
  assertExpectedBucket(input.storage, input.bucket);
  const response = await fetch(
    await createSignedReadUrl({
      storage: input.storage,
      objectName: input.objectName,
      expiresInSeconds: 300,
    }),
  );
  if (response.status === 404) {
    throw new SafeError(
      "FILE_OBJECT_MISSING",
      "Yüklenen dosya depolama alanında bulunamadı.",
      400,
    );
  }
  if (!response.ok) {
    throw new SafeError(
      "FILE_OBJECT_MISSING",
      "Yüklenen dosya depolama alanında bulunamadı.",
      500,
    );
  }
  return response.arrayBuffer();
}

export async function deleteObject(input: {
  storage: ObjectStorageConfig;
  bucket: string;
  objectName: string;
}) {
  try {
    assertExpectedBucket(input.storage, input.bucket);
    const url = await createS3PresignedUrl({
      storage: input.storage,
      method: "DELETE",
      objectName: input.objectName,
      expiresInSeconds: 300,
      usePublicEndpoint: true,
    });
    const response = await fetch(url, { method: "DELETE" });
    if (!response.ok && response.status !== 404) {
      console.warn("storage delete skipped:", response.status);
    }
  } catch (error) {
    const safeCode = error instanceof SafeError
      ? error.code
      : "STORAGE_DELETE_ERROR";
    console.warn("storage delete skipped:", safeCode);
  }
}

export async function assertBucketPermissions(storage: ObjectStorageConfig) {
  const response = await fetch(
    await createS3PresignedUrl({
      storage,
      method: "HEAD",
      objectName: "sourcebase/.permission-check",
      expiresInSeconds: 60,
      usePublicEndpoint: true,
    }),
    { method: "HEAD" },
  );
  if (response.status === 401 || response.status === 403) {
    throw new SafeError(
      "S3_PERMISSION_DENIED",
      "Dosya yükleme yetkisi doğrulanamadı.",
      500,
    );
  }
  if (!response.ok && response.status !== 404) {
    throw new SafeError(
      "S3_UPSTREAM_ERROR",
      "Dosya depolama servisine ulaşılamadı.",
      502,
    );
  }
}

function assertExpectedBucket(storage: ObjectStorageConfig, bucket: string) {
  if (bucket !== storage.bucket) {
    throw new SafeError(
      "STORAGE_BUCKET_MISMATCH",
      "Dosya depolama alanı doğrulanamadı.",
      403,
    );
  }
}

async function createS3PresignedUrl(input: {
  storage: ObjectStorageConfig;
  method: "GET" | "PUT" | "HEAD" | "DELETE";
  objectName: string;
  expiresInSeconds: number;
  usePublicEndpoint?: boolean;
}) {
  assertObjectName(input.objectName);
  const endpointUrl = input.usePublicEndpoint && input.storage.publicEndpoint
    ? input.storage.publicEndpoint
    : input.storage.endpoint;
  const endpoint = new URL(endpointUrl);
  const host = endpoint.host;
  const now = new Date();
  const date = formatDate(now);
  const timestamp = `${date}T${formatTime(now)}Z`;
  const credentialScope = `${date}/${input.storage.region}/s3/aws4_request`;
  const canonicalUri = `/${input.storage.bucket}/${encodePath(input.objectName)}`;
  const query: Record<string, string> = {
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": `${input.storage.accessKeyId}/${credentialScope}`,
    "X-Amz-Date": timestamp,
    "X-Amz-Expires": String(input.expiresInSeconds),
    "X-Amz-SignedHeaders": "host",
  };
  const canonicalQuery = canonicalQueryString(query);
  const canonicalRequest = [
    input.method,
    canonicalUri,
    canonicalQuery,
    `host:${host}\n`,
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    timestamp,
    credentialScope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const signingKey = await awsSigningKey(
    input.storage.secretAccessKey,
    date,
    input.storage.region,
  );
  const signature = toHex(await hmacSha256(signingKey, stringToSign));
  return `${endpoint.protocol}//${host}${canonicalUri}?${canonicalQuery}&X-Amz-Signature=${signature}`;
}

function assertObjectName(objectName: string) {
  if (!objectName || objectName.includes("..") || objectName.startsWith("/")) {
    throw new SafeError(
      "STORAGE_OBJECT_INVALID",
      "Dosya depolama yolu geçersiz.",
      400,
    );
  }
}

async function awsSigningKey(secret: string, date: string, region: string) {
  const kDate = await hmacSha256(`AWS4${secret}`, date);
  const kRegion = await hmacSha256(kDate, region);
  const kService = await hmacSha256(kRegion, "s3");
  return hmacSha256(kService, "aws4_request");
}

async function hmacSha256(key: string | Uint8Array, value: string) {
  const rawKey = typeof key === "string"
    ? new TextEncoder().encode(key)
    : key;
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    rawKey,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      new TextEncoder().encode(value),
    ),
  );
}

function formatDate(date: Date) {
  return date.toISOString().slice(0, 10).replaceAll("-", "");
}

function formatTime(date: Date) {
  return date.toISOString().slice(11, 19).replaceAll(":", "");
}

function encodePath(path: string) {
  return path.split("/").map(rfc3986Encode).join("/");
}

function canonicalQueryString(query: Record<string, string>) {
  return Object.entries(query)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${rfc3986Encode(key)}=${rfc3986Encode(value)}`)
    .join("&");
}

function rfc3986Encode(value: string) {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return toHex(new Uint8Array(digest));
}

function toHex(bytes: Uint8Array) {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

import { getObjectStorageConfig } from "../config.ts";
import {
  createSignedPutUrl,
  objectStorageUrl,
} from "./object-storage.ts";
import { SafeError } from "../types.ts";

export interface StoredGeneratedImage {
  bucket: string;
  objectName: string;
  storageUrl: string;
}

export async function storeGeneratedImageFromDataUrl(input: {
  userId: string;
  jobId: string;
  dataUrl?: string;
}): Promise<StoredGeneratedImage | undefined> {
  const parsed = parseDataUrl(input.dataUrl);
  if (!parsed) return undefined;

  const storage = getObjectStorageConfig();
  const extension = parsed.mimeType === "image/jpeg" ? "jpg" : "png";
  const objectName =
    `sourcebase/users/${input.userId}/generated/infographics/${input.jobId}.${extension}`;
  const uploadUrl = await createSignedPutUrl({
    storage,
    objectName,
    expiresInSeconds: 300,
  });

  const response = await fetch(uploadUrl, {
    method: "PUT",
    headers: { "content-type": parsed.mimeType },
    body: parsed.bytes,
  });
  if (!response.ok) {
    throw new SafeError(
      "IMAGE_STORAGE_FAILED",
      "İnfografik görseli depolanamadı.",
      500,
    );
  }

  return {
    bucket: storage.bucket,
    objectName,
    storageUrl: objectStorageUrl(storage, objectName),
  };
}

function parseDataUrl(dataUrl: string | undefined) {
  const text = dataUrl?.trim() ?? "";
  const match = /^data:(image\/[a-z0-9.+-]+);base64,(.+)$/i.exec(text);
  if (!match) return undefined;
  try {
    const binary = atob(match[2]);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return { mimeType: match[1].toLowerCase(), bytes };
  } catch (_error) {
    throw new SafeError(
      "IMAGE_STORAGE_INVALID_DATA",
      "İnfografik görsel verisi işlenemedi.",
      500,
    );
  }
}

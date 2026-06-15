import { getObjectStorageConfig } from "../config.ts";
import {
  createSignedPutUrl,
  objectStorageUrl,
} from "./object-storage.ts";
import { SafeError } from "../types.ts";

export interface StoredGeneratedAudio {
  bucket: string;
  objectName: string;
  storageUrl: string;
}

export async function storeGeneratedAudioFromDataUrl(input: {
  userId: string;
  jobId: string;
  dataUrl?: string;
}): Promise<StoredGeneratedAudio | undefined> {
  const parsed = parseAudioDataUrl(input.dataUrl);
  if (!parsed) return undefined;

  const storage = getObjectStorageConfig();
  const extension = parsed.mimeType === "audio/mp4" ? "m4a" : "mp3";
  const objectName =
    `sourcebase/users/${input.userId}/generated/podcasts/${input.jobId}.${extension}`;
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
      "AUDIO_STORAGE_FAILED",
      "Podcast sesi depolanamadı.",
      500,
    );
  }

  return {
    bucket: storage.bucket,
    objectName,
    storageUrl: objectStorageUrl(storage, objectName),
  };
}

function parseAudioDataUrl(dataUrl: string | undefined) {
  const text = dataUrl?.trim() ?? "";
  const match = /^data:(audio\/[a-z0-9.+-]+);base64,(.+)$/i.exec(text);
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
      "AUDIO_STORAGE_INVALID_DATA",
      "Podcast ses verisi işlenemedi.",
      500,
    );
  }
}

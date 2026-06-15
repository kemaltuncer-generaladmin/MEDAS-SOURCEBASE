/**
 * SourceBase Document Extraction Service
 *
 * PDF, DOCX, PPTX dosyalarından metin çıkarımı
 * AGENTS.md Kural 12.4: Kaynak metni data olarak ele alınır
 */

import { ObjectStorageConfig } from "../config.ts";
import { downloadObject } from "./object-storage.ts";
import { SafeError } from "../types.ts";

const MAX_EXTRACTION_BYTES = 100 * 1024 * 1024;
const MIN_EXTRACTED_TEXT_CHARS = 10;
const ZIP_LOCAL_FILE_HEADER = 0x04034b50;

export interface ExtractionResult {
  text: string;
  pageCount?: number;
  chunks?: string[];
  metadata: {
    fileType: string;
    extractedAt: string;
    charCount: number;
    wordCount: number;
  };
}

export async function downloadFromObjectStorage(
  bucket: string,
  objectName: string,
  storage: ObjectStorageConfig,
): Promise<ArrayBuffer> {
  if (!bucket || !objectName || objectName.includes("..")) {
    throw new SafeError(
      "STORAGE_OBJECT_INVALID",
      "Dosya depolama yolu geçersiz.",
      400,
    );
  }
  return downloadObject({ storage, bucket, objectName });
}

export async function extractPdf(
  content: ArrayBuffer,
): Promise<ExtractionResult & { chunks: string[] }> {
  const extracted = await extractFromPDF(content);
  return extractionResult("pdf", extracted.text, extracted.pageCount);
}

export async function extractDocx(
  content: ArrayBuffer,
): Promise<ExtractionResult & { chunks: string[] }> {
  return extractionResult("docx", await extractFromDOCX(content));
}

export async function extractPptx(
  content: ArrayBuffer,
): Promise<ExtractionResult & { chunks: string[] }> {
  return extractionResult("pptx", await extractFromPPTX(content));
}

function extractionResult(
  fileType: string,
  rawText: string,
  pageCount?: number,
): ExtractionResult & { chunks: string[] } {
  const text = sanitizeSourceText(rawText);
  if (usefulTextLength(text) < MIN_EXTRACTED_TEXT_CHARS) {
    if (fileType === "pdf") {
      throw new SafeError(
        "FILE_SCANNED_PDF_OCR_REQUIRED",
        "Bu PDF taranmış/görsel tabanlı görünüyor. Metin çıkarılamadı. OCR desteği gerekir.",
        400,
      );
    }
    throw new SafeError(
      "FILE_TEXT_EMPTY",
      "Dosyadan okunabilir metin çıkarılamadı.",
      400,
    );
  }
  return {
    text,
    pageCount,
    chunks: chunkText(text),
    metadata: {
      fileType,
      extractedAt: new Date().toISOString(),
      charCount: text.length,
      wordCount: text.split(/\s+/).filter((word) => word.length > 0).length,
    },
  };
}

/**
 * Dosyadan metin çıkar
 */
export async function extractText(
  fileUrl: string,
  fileType: string,
): Promise<ExtractionResult> {
  try {
    const content = await downloadFile(fileUrl);

    let text = "";
    let pageCount: number | undefined;

    switch (fileType.toLowerCase()) {
      case "pdf":
        ({ text, pageCount } = await extractFromPDF(content));
        break;
      case "docx":
        text = await extractFromDOCX(content);
        break;
      case "pptx":
        text = await extractFromPPTX(content);
        break;
      default:
        throw new SafeError(
          "UNSUPPORTED_FILE_TYPE",
          "Bu dosya türü desteklenmiyor. PDF, PPTX, PPT, DOCX veya DOC yükleyin.",
          400,
        );
    }

    return extractionResult(fileType, text, pageCount);
  } catch (error) {
    if (error instanceof SafeError) {
      throw error;
    }
    throw new SafeError(
      "FILE_PARSE_FAILED",
      "Dosyadan metin çıkarılamadı.",
      500,
    );
  }
}

async function downloadFile(url: string): Promise<ArrayBuffer> {
  try {
    const response = await fetch(url);

    if (!response.ok) {
      throw new Error(`Storage download failed: ${response.status}`);
    }

    const contentLength = Number(response.headers.get("content-length") ?? 0);
    if (contentLength > MAX_EXTRACTION_BYTES) {
      throw new SafeError(
        "FILE_TOO_LARGE",
        "Dosya işleme sınırından büyük.",
        400,
      );
    }

    const buffer = await response.arrayBuffer();
    if (buffer.byteLength <= 0) {
      throw new SafeError(
        "FILE_OBJECT_EMPTY",
        "Yüklenen dosya boş görünüyor.",
        400,
      );
    }
    if (buffer.byteLength > MAX_EXTRACTION_BYTES) {
      throw new SafeError(
        "FILE_TOO_LARGE",
        "Dosya işleme sınırından büyük.",
        400,
      );
    }
    return buffer;
  } catch (error) {
    if (error instanceof SafeError) {
      throw error;
    }
    throw new SafeError(
      "FILE_OBJECT_MISSING",
      "Yüklenen dosya depolama alanında bulunamadı.",
      500,
    );
  }
}

async function extractFromPDF(
  content: ArrayBuffer,
): Promise<{ text: string; pageCount: number }> {
  const bytes = new Uint8Array(content);
  const raw = latin1Decode(bytes);
  const streams = await extractPdfStreams(bytes, raw);
  const cmap = buildPdfToUnicodeMap(streams);
  const parts = [extractPdfTextOperators(raw, cmap)];

  for (const stream of streams) {
    parts.push(extractPdfTextOperators(stream, cmap));
  }

  const pageMatches = raw.match(/\/Type\s*\/Page\b/g) || [];
  const pageCount = pageMatches.length || 1;
  return {
    text: parts.filter(Boolean).join("\n"),
    pageCount,
  };
}

async function extractFromDOCX(content: ArrayBuffer): Promise<string> {
  const entries = await unzipTextEntries(
    content,
    (name) =>
      name === "word/document.xml" ||
      name.startsWith("word/header") ||
      name.startsWith("word/footer"),
  );
  return entries
    .map((entry) => extractOfficeXmlText(entry.text))
    .filter(Boolean)
    .join("\n\n");
}

async function extractFromPPTX(content: ArrayBuffer): Promise<string> {
  const entries = await unzipTextEntries(
    content,
    (name) =>
      name.startsWith("ppt/slides/slide") ||
      name.startsWith("ppt/notesSlides/notesSlide") ||
      name.startsWith("ppt/slideMasters/slideMaster"),
  );
  return entries
    .map((entry, index) => {
      const text = extractOfficeXmlText(entry.text);
      if (!text) return "";
      return `Slayt ${index + 1}\n${text}`;
    })
    .filter(Boolean)
    .join("\n\n");
}

function latin1Decode(bytes: Uint8Array) {
  return new TextDecoder("latin1").decode(bytes);
}

async function extractPdfStreams(
  bytes: Uint8Array,
  raw: string,
): Promise<string[]> {
  const streams: string[] = [];
  const pattern = /(<<[\s\S]*?>>)\s*stream\r?\n?([\s\S]*?)\r?\n?endstream/g;
  for (const match of raw.matchAll(pattern)) {
    const dictionary = match[1] ?? "";
    const body = match[2] ?? "";
    const bodyStart = (match.index ?? 0) + match[0].indexOf(body);
    const streamBytes = stripPdfStreamBoundaries(
      bytes.slice(bodyStart, bodyStart + body.length),
    );
    if (dictionary.includes("/FlateDecode")) {
      const inflated = await inflateBytes(streamBytes);
      if (inflated) streams.push(latin1Decode(inflated));
    } else {
      streams.push(latin1Decode(streamBytes));
    }
  }
  return streams;
}

function stripPdfStreamBoundaries(value: Uint8Array) {
  let start = 0;
  let end = value.length;
  if (value[start] === 0x0d && value[start + 1] === 0x0a) start += 2;
  else if (value[start] === 0x0a || value[start] === 0x0d) start += 1;
  if (end > start && value[end - 2] === 0x0d && value[end - 1] === 0x0a) {
    end -= 2;
  } else if (
    end > start && (value[end - 1] === 0x0a || value[end - 1] === 0x0d)
  ) {
    end -= 1;
  }
  return value.slice(start, end);
}

function extractPdfTextOperators(value: string, cmap: PdfToUnicodeMap) {
  const textParts: string[] = [];

  for (const match of value.matchAll(/(\((?:\\.|[^\\()])*\))\s*(?:Tj|'|")/g)) {
    textParts.push(decodePdfLiteral(match[1]));
  }
  for (const match of value.matchAll(/<([0-9a-fA-F\s]+)>\s*Tj/g)) {
    textParts.push(decodePdfHex(match[1], cmap));
  }
  for (const match of value.matchAll(/\[([\s\S]*?)\]\s*TJ/g)) {
    const arrayBody = match[1] ?? "";
    for (
      const item of arrayBody.matchAll(
        /\((?:\\.|[^\\()])*\)|<([0-9a-fA-F\s]+)>/g,
      )
    ) {
      const token = item[0];
      textParts.push(
        token.startsWith("(")
          ? decodePdfLiteral(token)
          : decodePdfHex(token.slice(1, -1), cmap),
      );
    }
    textParts.push("\n");
  }

  return textParts
    .join(" ")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\s+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

type PdfToUnicodeMap = Map<string, string>;

function buildPdfToUnicodeMap(streams: string[]): PdfToUnicodeMap {
  const map: PdfToUnicodeMap = new Map();
  for (const stream of streams) {
    for (
      const section of stream.matchAll(
        /beginbfchar([\s\S]*?)endbfchar|beginbfrange([\s\S]*?)endbfrange/g,
      )
    ) {
      const bfchar = section[1];
      const bfrange = section[2];
      if (bfchar) {
        for (
          const match of bfchar.matchAll(
            /<([0-9a-fA-F\s]+)>\s*<([0-9a-fA-F\s]+)>/g,
          )
        ) {
          map.set(
            normalizePdfHexKey(match[1]),
            pdfUnicodeHexToString(match[2]),
          );
        }
      }
      if (bfrange) {
        readPdfBfRanges(bfrange, map);
      }
    }
  }
  return map;
}

function readPdfBfRanges(section: string, map: PdfToUnicodeMap) {
  for (
    const match of section.matchAll(
      /<([0-9a-fA-F\s]+)>\s*<([0-9a-fA-F\s]+)>\s*(<([0-9a-fA-F\s]+)>|\[([\s\S]*?)\])/g,
    )
  ) {
    const startKey = normalizePdfHexKey(match[1]);
    const endKey = normalizePdfHexKey(match[2]);
    const start = parseInt(startKey, 16);
    const end = parseInt(endKey, 16);
    if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) {
      continue;
    }
    const width = startKey.length;
    const arrayBody = match[5];
    if (arrayBody) {
      const values = [...arrayBody.matchAll(/<([0-9a-fA-F\s]+)>/g)];
      values.forEach((value, index) => {
        map.set(
          (start + index).toString(16).toUpperCase().padStart(width, "0"),
          pdfUnicodeHexToString(value[1]),
        );
      });
      continue;
    }
    const destStart = parseInt(normalizePdfHexKey(match[4]), 16);
    if (!Number.isFinite(destStart)) continue;
    for (let code = start; code <= end; code++) {
      map.set(
        code.toString(16).toUpperCase().padStart(width, "0"),
        String.fromCodePoint(destStart + code - start),
      );
    }
  }
}

function normalizePdfHexKey(hex: string) {
  return hex.replace(/\s+/g, "").toUpperCase();
}

function decodePdfLiteral(token: string) {
  const body = token.startsWith("(") && token.endsWith(")")
    ? token.slice(1, -1)
    : token;
  let output = "";
  for (let i = 0; i < body.length; i++) {
    const char = body[i];
    if (char !== "\\") {
      output += char;
      continue;
    }
    const next = body[++i] ?? "";
    if (next === "n") output += "\n";
    else if (next === "r") output += "\n";
    else if (next === "t") output += "\t";
    else if (next === "b" || next === "f") output += " ";
    else if (next === "\n" || next === "\r") {
      if (next === "\r" && body[i + 1] === "\n") i++;
    } else if (/[0-7]/.test(next)) {
      let octal = next;
      for (let j = 0; j < 2 && /[0-7]/.test(body[i + 1] ?? ""); j++) {
        octal += body[++i];
      }
      output += String.fromCharCode(parseInt(octal, 8));
    } else {
      output += next;
    }
  }
  return output;
}

function decodePdfHex(hex: string, cmap: PdfToUnicodeMap = new Map()) {
  const clean = normalizePdfHexKey(hex);
  if (!clean) return "";
  const mapped = decodePdfHexWithCMap(clean, cmap);
  if (mapped) return mapped;
  const bytes = new Uint8Array(Math.ceil(clean.length / 2));
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(clean.slice(i * 2, i * 2 + 2).padEnd(2, "0"), 16);
  }
  if (bytes[0] === 0xfe && bytes[1] === 0xff) {
    let output = "";
    for (let i = 2; i + 1 < bytes.length; i += 2) {
      output += String.fromCharCode((bytes[i] << 8) | bytes[i + 1]);
    }
    return output;
  }
  return new TextDecoder().decode(bytes);
}

function decodePdfHexWithCMap(cleanHex: string, cmap: PdfToUnicodeMap) {
  if (cmap.size === 0) return "";
  const direct = cmap.get(cleanHex);
  if (direct) return direct;
  const widths = [...new Set([...cmap.keys()].map((key) => key.length))]
    .sort((a, b) => b - a);
  let output = "";
  let offset = 0;
  while (offset < cleanHex.length) {
    const width = widths.find((candidate) =>
      cmap.has(cleanHex.slice(offset, offset + candidate))
    );
    if (!width) return "";
    output += cmap.get(cleanHex.slice(offset, offset + width)) ?? "";
    offset += width;
  }
  return output;
}

function pdfUnicodeHexToString(hex: string) {
  const clean = normalizePdfHexKey(hex);
  if (!clean) return "";
  let output = "";
  for (let index = 0; index + 3 < clean.length; index += 4) {
    output += String.fromCharCode(parseInt(clean.slice(index, index + 4), 16));
  }
  return output;
}

async function unzipTextEntries(
  content: ArrayBuffer,
  shouldRead: (name: string) => boolean,
) {
  const bytes = new Uint8Array(content);
  const view = new DataView(content);
  const entries: { name: string; text: string }[] = [];

  const zipEntries = zipCentralDirectoryEntries(bytes, view)
    .filter((entry) => shouldRead(entry.name) && entry.name.endsWith(".xml"))
    .sort((a, b) => naturalCompare(a.name, b.name));

  for (const entry of zipEntries) {
    if (!shouldRead(entry.name) || !entry.name.endsWith(".xml")) continue;
    const data = await readZipEntry(bytes, view, entry);
    if (data) {
      entries.push({ name: entry.name, text: new TextDecoder().decode(data) });
    }
  }

  return entries;
}

type ZipEntry = {
  name: string;
  method: number;
  compressedSize: number;
  localHeaderOffset: number;
};

function zipCentralDirectoryEntries(
  bytes: Uint8Array,
  view: DataView,
): ZipEntry[] {
  const eocdOffset = findEndOfCentralDirectory(view);
  if (eocdOffset < 0) return [];
  const entryCount = view.getUint16(eocdOffset + 10, true);
  let offset = view.getUint32(eocdOffset + 16, true);
  const entries: ZipEntry[] = [];

  for (let i = 0; i < entryCount && offset + 46 <= bytes.length; i++) {
    if (view.getUint32(offset, true) !== 0x02014b50) break;
    const method = view.getUint16(offset + 10, true);
    const compressedSize = view.getUint32(offset + 20, true);
    const nameLength = view.getUint16(offset + 28, true);
    const extraLength = view.getUint16(offset + 30, true);
    const commentLength = view.getUint16(offset + 32, true);
    const localHeaderOffset = view.getUint32(offset + 42, true);
    const name = new TextDecoder().decode(
      bytes.slice(offset + 46, offset + 46 + nameLength),
    );
    entries.push({ name, method, compressedSize, localHeaderOffset });
    offset += 46 + nameLength + extraLength + commentLength;
  }

  return entries;
}

function findEndOfCentralDirectory(view: DataView) {
  for (let offset = view.byteLength - 22; offset >= 0; offset--) {
    if (view.getUint32(offset, true) === 0x06054b50) return offset;
  }
  return -1;
}

async function readZipEntry(
  bytes: Uint8Array,
  view: DataView,
  entry: ZipEntry,
) {
  const offset = entry.localHeaderOffset;
  if (
    offset < 0 || offset + 30 > bytes.length ||
    view.getUint32(offset, true) !== ZIP_LOCAL_FILE_HEADER
  ) {
    return null;
  }
  const localNameLength = view.getUint16(offset + 26, true);
  const localExtraLength = view.getUint16(offset + 28, true);
  const dataStart = offset + 30 + localNameLength + localExtraLength;
  const dataEnd = dataStart + entry.compressedSize;
  if (dataStart < 0 || dataEnd > bytes.length) return null;
  const compressed = bytes.slice(dataStart, dataEnd);
  if (entry.method === 0) return compressed;
  if (entry.method === 8) return await inflateBytes(compressed, true);
  return null;
}

async function inflateBytes(bytes: Uint8Array, raw = false) {
  const formats = raw ? ["deflate-raw", "deflate"] : ["deflate", "deflate-raw"];
  const blobPart = bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
  for (const format of formats) {
    try {
      const stream = new Blob([blobPart]).stream().pipeThrough(
        new DecompressionStream(format as CompressionFormat),
      );
      return new Uint8Array(await new Response(stream).arrayBuffer());
    } catch (_error) {
      // Try the next deflate container flavor.
    }
  }
  return null;
}

function extractOfficeXmlText(xml: string) {
  const paragraphs: string[] = [];
  const paragraphMatches = [
    ...xml.matchAll(/<(?:\w+:)?p\b[^>]*>([\s\S]*?)<\/(?:\w+:)?p>/g),
  ];
  const blocks = paragraphMatches.length > 0
    ? paragraphMatches.map((match) => match[1] ?? "")
    : [xml];

  for (const block of blocks) {
    const parts: string[] = [];
    for (
      const match of block.matchAll(
        /<(?:\w+:)?t\b[^>]*>([\s\S]*?)<\/(?:\w+:)?t>/g,
      )
    ) {
      parts.push(decodeXmlEntities(match[1] ?? ""));
    }
    if (parts.length === 0) {
      parts.push(decodeXmlEntities(block.replace(/<[^>]+>/g, " ")));
    }
    const text = parts.join(" ").replace(/\s{2,}/g, " ").trim();
    if (text) paragraphs.push(text);
  }

  return paragraphs.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

function decodeXmlEntities(value: string) {
  return value
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
}

/**
 * Kaynak metnini temizle ve sanitize et
 * AGENTS.md Kural 12.4: Prompt injection'a karşı koruma
 */
export function sanitizeSourceText(text: string): string {
  return text
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "") // Kontrol karakterlerini kaldır
    .replace(/\r\n/g, "\n") // Windows line endings'i normalize et
    .replace(/\r/g, "\n") // Mac line endings'i normalize et
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n") // Fazla boş satırları temizle
    .trim();
}

function usefulTextLength(text: string) {
  return text.replace(/[\s\W_]+/g, "").length;
}

function naturalCompare(a: string, b: string) {
  return a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" });
}

/**
 * Metni token limitine göre chunk'la
 */
export function chunkText(text: string, maxTokens = 8000): string[] {
  // Basit karakter bazlı chunking (1 token ≈ 4 karakter)
  const maxChars = maxTokens * 4;
  const chunks: string[] = [];

  let currentChunk = "";
  const paragraphs = text.split("\n\n");

  for (const paragraph of paragraphs) {
    if ((currentChunk + paragraph).length > maxChars) {
      if (currentChunk) {
        chunks.push(currentChunk.trim());
        currentChunk = "";
      }

      // Eğer tek paragraf çok büyükse, zorla böl
      if (paragraph.length > maxChars) {
        const words = paragraph.split(" ");
        for (const word of words) {
          if ((currentChunk + " " + word).length > maxChars) {
            chunks.push(currentChunk.trim());
            currentChunk = word;
          } else {
            currentChunk += (currentChunk ? " " : "") + word;
          }
        }
      } else {
        currentChunk = paragraph;
      }
    } else {
      currentChunk += (currentChunk ? "\n\n" : "") + paragraph;
    }
  }

  if (currentChunk) {
    chunks.push(currentChunk.trim());
  }

  return chunks;
}

/**
 * Token sayısını tahmin et
 */
export function estimateTokens(text: string): number {
  // Basit tahmin: 1 token ≈ 4 karakter
  return Math.ceil(text.length / 4);
}

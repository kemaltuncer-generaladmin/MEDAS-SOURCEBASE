export type SourceFileType =
  | "pdf"
  | "pptx"
  | "ppt"
  | "docx"
  | "doc"
  | "unknown";

const GENERIC_MIME_TYPES = new Set([
  "",
  "application/octet-stream",
  "binary/octet-stream",
  "application/x-binary",
]);

const MIME_TO_TYPE: Record<string, SourceFileType> = {
  "application/pdf": "pdf",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation":
    "pptx",
  "application/vnd.ms-powerpoint": "ppt",
  "application/mspowerpoint": "ppt",
  "application/powerpoint": "ppt",
  "application/x-mspowerpoint": "ppt",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
    "docx",
  "application/msword": "doc",
};

const EXTENSION_TO_TYPE: Record<string, SourceFileType> = {
  pdf: "pdf",
  pptx: "pptx",
  ppt: "ppt",
  docx: "docx",
  doc: "doc",
};

export type NormalizedSourceFileType = {
  type: SourceFileType;
  extension: string;
  mimeType: string;
  mimeTypeType: SourceFileType;
  extensionType: SourceFileType;
  isGenericMime: boolean;
  mismatch: boolean;
};

export function normalizeSourceFileType(input: {
  fileName?: string;
  contentType?: string;
}): NormalizedSourceFileType {
  const extension = extensionFromName(input.fileName ?? "");
  const extensionType = EXTENSION_TO_TYPE[extension] ?? "unknown";
  const mimeType = normalizeContentType(input.contentType ?? "");
  const isGenericMime = GENERIC_MIME_TYPES.has(mimeType) ||
    mimeType === "application/zip" ||
    mimeType === "application/x-zip-compressed";
  const mimeTypeType = MIME_TO_TYPE[mimeType] ?? "unknown";
  const mismatch = !isGenericMime &&
    mimeTypeType !== "unknown" &&
    extensionType !== "unknown" &&
    mimeTypeType !== extensionType;

  let type: SourceFileType = "unknown";
  if (isGenericMime) {
    type = extensionType;
  } else if (
    extensionType !== "unknown" &&
    isRelatedOfficeMismatch(extensionType, mimeTypeType)
  ) {
    type = extensionType;
  } else if (mimeTypeType !== "unknown") {
    type = mimeTypeType;
  } else {
    type = extensionType;
  }

  return {
    type,
    extension,
    mimeType,
    mimeTypeType,
    extensionType,
    isGenericMime,
    mismatch,
  };
}

export function isSupportedSourceFileType(type: SourceFileType) {
  return type !== "unknown";
}

export function isLimitedLegacyOfficeType(type: SourceFileType) {
  return type === "ppt" || type === "doc";
}

export function canonicalContentTypeFor(type: SourceFileType) {
  switch (type) {
    case "pdf":
      return "application/pdf";
    case "pptx":
      return "application/vnd.openxmlformats-officedocument.presentationml.presentation";
    case "ppt":
      return "application/vnd.ms-powerpoint";
    case "docx":
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    case "doc":
      return "application/msword";
    default:
      return "application/octet-stream";
  }
}

export function userMessageForLimitedLegacyType(type: SourceFileType) {
  if (type === "ppt") {
    return "Eski .ppt formatı şu anda sınırlı destekleniyor. Lütfen dosyayı .pptx olarak kaydedip tekrar yükleyin.";
  }
  if (type === "doc") {
    return "Eski .doc formatı şu anda sınırlı destekleniyor. Lütfen dosyayı .docx olarak kaydedip tekrar yükleyin.";
  }
  return "Bu dosya türü şu anda sınırlı destekleniyor. Lütfen .pptx veya .docx olarak tekrar yükleyin.";
}

function normalizeContentType(value: string) {
  return value.toLowerCase().split(";")[0].trim();
}

function extensionFromName(value: string) {
  const withoutQuery = value.split("?")[0].split("#")[0];
  const fileName = withoutQuery.split(/[\\/]/).pop() ?? "";
  const dot = fileName.lastIndexOf(".");
  if (dot < 0 || dot === fileName.length - 1) return "";
  return fileName.slice(dot + 1).toLowerCase();
}

function isRelatedOfficeMismatch(
  extensionType: SourceFileType,
  mimeTypeType: SourceFileType,
) {
  return (
    (extensionType === "pptx" && mimeTypeType === "ppt") ||
    (extensionType === "ppt" && mimeTypeType === "pptx") ||
    (extensionType === "docx" && mimeTypeType === "doc") ||
    (extensionType === "doc" && mimeTypeType === "docx")
  );
}

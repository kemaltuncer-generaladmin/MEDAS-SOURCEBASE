import {
  canonicalContentTypeFor,
  isLimitedLegacyOfficeType,
  normalizeSourceFileType,
  userMessageForLimitedLegacyType,
} from "./file-types.ts";

Deno.test("normalizeSourceFileType supports canonical office and PDF types", () => {
  const cases = [
    ["lecture.pdf", "application/pdf", "pdf"],
    [
      "slides.pptx",
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      "pptx",
    ],
    ["legacy.ppt", "application/vnd.ms-powerpoint", "ppt"],
    [
      "notes.docx",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "docx",
    ],
    ["legacy.doc", "application/msword", "doc"],
  ] as const;

  for (const [fileName, contentType, expected] of cases) {
    assertEquals(
      normalizeSourceFileType({ fileName, contentType }).type,
      expected,
    );
  }
});

Deno.test("normalizeSourceFileType falls back to extension for generic MIME", () => {
  assertEquals(
    normalizeSourceFileType({
      fileName: "PATH/RENAL.PDF?download=1",
      contentType: "application/octet-stream",
    }).type,
    "pdf",
  );
  assertEquals(
    normalizeSourceFileType({
      fileName: "Cardiology.PPTX",
      contentType: "application/zip",
    }).type,
    "pptx",
  );
});

Deno.test("normalizeSourceFileType handles unsupported and related mismatches", () => {
  const unsupported = normalizeSourceFileType({
    fileName: "archive.zip",
    contentType: "application/zip",
  });
  assertEquals(unsupported.type, "unknown");

  const relatedMismatch = normalizeSourceFileType({
    fileName: "deck.pptx",
    contentType: "application/vnd.ms-powerpoint",
  });
  assertEquals(relatedMismatch.type, "pptx");
  assertEquals(relatedMismatch.mismatch, true);
});

Deno.test("legacy office formats have explicit limited-support messages", () => {
  assertEquals(isLimitedLegacyOfficeType("ppt"), true);
  assertEquals(isLimitedLegacyOfficeType("doc"), true);
  assertEquals(
    userMessageForLimitedLegacyType("ppt"),
    "Eski .ppt formatı şu anda sınırlı destekleniyor. Lütfen dosyayı .pptx olarak kaydedip tekrar yükleyin.",
  );
  assertEquals(
    userMessageForLimitedLegacyType("doc"),
    "Eski .doc formatı şu anda sınırlı destekleniyor. Lütfen dosyayı .docx olarak kaydedip tekrar yükleyin.",
  );
  assertEquals(canonicalContentTypeFor("doc"), "application/msword");
});

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}

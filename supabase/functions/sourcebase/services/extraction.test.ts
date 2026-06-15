import { extractDocx, extractPdf, extractPptx } from "./extraction.ts";
import { SafeError } from "../types.ts";

const fixtureDir = "test/fixtures/sourcebase";

Deno.test("extractPdf reads text-based PDF fixture", async () => {
  await ensureFixtures();
  const bytes = await Deno.readFile(`${fixtureDir}/valid_text_pdf.pdf`);
  const result = await extractPdf(bytes.buffer);
  assert(result.text.includes("Valid text PDF fixture"));
  assert(result.text.includes("SourceBase ingestion"));
});

Deno.test("extractPdf decodes ToUnicode CMap text PDF fixture", async () => {
  await ensureFixtures();
  const bytes = await Deno.readFile(`${fixtureDir}/valid_cmap_pdf.pdf`);
  const result = await extractPdf(bytes.buffer);
  assert(result.text.includes("CMap text PDF"));
});

Deno.test("extractPdf returns OCR-required error for image/scanned PDF fixture", async () => {
  await ensureFixtures();
  const bytes = await Deno.readFile(`${fixtureDir}/scanned_or_image_pdf.pdf`);
  const error = await assertRejects(
    () => extractPdf(bytes.buffer),
    SafeError,
  );
  assertEquals(error.code, "FILE_SCANNED_PDF_OCR_REQUIRED");
  assertEquals(
    error.message,
    "Bu PDF taranmış/görsel tabanlı görünüyor. Metin çıkarılamadı. OCR desteği gerekir.",
  );
});

Deno.test("extractPptx reads slide and notes text", async () => {
  await ensureFixtures();
  const bytes = await Deno.readFile(`${fixtureDir}/valid_pptx.pptx`);
  const result = await extractPptx(bytes.buffer);
  assert(result.text.includes("Slayt 1"));
  assert(result.text.includes("Cardiology slide title"));
  assert(result.text.includes("Speaker note text"));
});

Deno.test("extractDocx reads body, header, and footer text", async () => {
  await ensureFixtures();
  const bytes = await Deno.readFile(`${fixtureDir}/valid_docx.docx`);
  const result = await extractDocx(bytes.buffer);
  assert(result.text.includes("Header source text"));
  assert(result.text.includes("DOCX body paragraph for SourceBase"));
  assert(result.text.includes("Footer source text"));
});

Deno.test("extractPptx and extractDocx return empty-text errors for empty office files", async () => {
  const emptyPptx = makeZip({
    "ppt/slides/slide1.xml": `<p:sld xmlns:p="p" xmlns:a="a"><p:cSld/></p:sld>`,
  });
  const pptxError = await assertRejects(
    () => extractPptx(emptyPptx.buffer),
    SafeError,
  );
  assertEquals(pptxError.code, "FILE_TEXT_EMPTY");

  const emptyDocx = makeZip({
    "word/document.xml": `<w:document xmlns:w="w"><w:body/></w:document>`,
  });
  const docxError = await assertRejects(
    () => extractDocx(emptyDocx.buffer),
    SafeError,
  );
  assertEquals(docxError.code, "FILE_TEXT_EMPTY");
});

async function ensureFixtures() {
  await Deno.mkdir(fixtureDir, { recursive: true });
  await Deno.writeFile(
    `${fixtureDir}/valid_text_pdf.pdf`,
    encodeText(minimalTextPdf([
      "Valid text PDF fixture",
      "SourceBase ingestion extracts real text",
    ])),
  );
  await Deno.writeFile(
    `${fixtureDir}/valid_cmap_pdf.pdf`,
    encodeText(minimalCMapPdf("CMap text PDF")),
  );
  await Deno.writeFile(
    `${fixtureDir}/scanned_or_image_pdf.pdf`,
    encodeText(minimalScannedPdf()),
  );
  await Deno.writeFile(
    `${fixtureDir}/valid_pptx.pptx`,
    makeZip({
      "ppt/slides/slide1.xml": officeXml([
        "Cardiology slide title",
        "Mechanism and treatment branch",
      ]),
      "ppt/notesSlides/notesSlide1.xml": officeXml(["Speaker note text"]),
    }),
  );
  await Deno.writeFile(
    `${fixtureDir}/valid_docx.docx`,
    makeZip({
      "word/header1.xml": officeXml(["Header source text"]),
      "word/document.xml": officeXml([
        "DOCX body paragraph for SourceBase",
        "Second paragraph keeps separation",
      ]),
      "word/footer1.xml": officeXml(["Footer source text"]),
    }),
  );
  await Deno.writeFile(
    `${fixtureDir}/old_format_ppt.ppt`,
    encodeText("Legacy PPT placeholder fixture"),
  );
  await Deno.writeFile(
    `${fixtureDir}/old_format_doc.doc`,
    encodeText("Legacy DOC placeholder fixture"),
  );
}

function minimalCMapPdf(text: string) {
  const codes = [...text].map((char, index) => ({
    code: (index + 1).toString(16).padStart(4, "0").toUpperCase(),
    unicode: char.charCodeAt(0).toString(16).padStart(4, "0").toUpperCase(),
  }));
  const encodedText = codes.map((item) => item.code).join("");
  const cmap = `/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
${codes.length} beginbfchar
${codes.map((item) => `<${item.code}> <${item.unicode}>`).join("\n")}
endbfchar
endcmap
CMapName currentdict /CMap defineresource pop
end
end`;
  return `%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /Type0 /BaseFont /ABCDEE+Custom /Encoding /Identity-H /ToUnicode 6 0 R >>
endobj
5 0 obj
<< /Length ${encodedText.length + 40} >>
stream
BT
/F1 12 Tf
72 720 Td
<${encodedText}> Tj
ET
endstream
endobj
6 0 obj
<< /Length ${cmap.length} >>
stream
${cmap}
endstream
endobj
%%EOF`;
}

function minimalTextPdf(lines: string[]) {
  const operators = lines.map((line, index) =>
    `${index === 0 ? "" : "0 -18 Td "}(${escapePdf(line)}) Tj`
  ).join("\n");
  return `%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>
endobj
4 0 obj
<< /Length 128 >>
stream
BT
/F1 12 Tf
72 720 Td
${operators}
ET
endstream
endobj
%%EOF`;
}

function minimalScannedPdf() {
  return `%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /XObject << /Im1 4 0 R >> >> >>
endobj
4 0 obj
<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 3 >>
stream
abc
endstream
endobj
%%EOF`;
}

function officeXml(paragraphs: string[]) {
  return `<w:document xmlns:w="w" xmlns:a="a">${
    paragraphs.map((text) =>
      `<w:p><w:r><w:t>${escapeXml(text)}</w:t></w:r></w:p>`
    ).join("")
  }</w:document>`;
}

function makeZip(files: Record<string, string>) {
  const chunks: Uint8Array[] = [];
  const central: Uint8Array[] = [];
  let offset = 0;
  for (const [name, text] of Object.entries(files)) {
    const nameBytes = encodeText(name);
    const data = encodeText(text);
    const crc = crc32(data);
    const local = new Uint8Array(30 + nameBytes.length + data.length);
    const localView = new DataView(local.buffer);
    localView.setUint32(0, 0x04034b50, true);
    localView.setUint16(4, 20, true);
    localView.setUint16(8, 0, true);
    localView.setUint32(14, crc, true);
    localView.setUint32(18, data.length, true);
    localView.setUint32(22, data.length, true);
    localView.setUint16(26, nameBytes.length, true);
    local.set(nameBytes, 30);
    local.set(data, 30 + nameBytes.length);
    chunks.push(local);

    const header = new Uint8Array(46 + nameBytes.length);
    const view = new DataView(header.buffer);
    view.setUint32(0, 0x02014b50, true);
    view.setUint16(4, 20, true);
    view.setUint16(6, 20, true);
    view.setUint16(10, 0, true);
    view.setUint32(16, crc, true);
    view.setUint32(20, data.length, true);
    view.setUint32(24, data.length, true);
    view.setUint16(28, nameBytes.length, true);
    view.setUint32(42, offset, true);
    header.set(nameBytes, 46);
    central.push(header);
    offset += local.length;
  }

  const centralSize = central.reduce((sum, item) => sum + item.length, 0);
  const eocd = new Uint8Array(22);
  const eocdView = new DataView(eocd.buffer);
  eocdView.setUint32(0, 0x06054b50, true);
  eocdView.setUint16(8, central.length, true);
  eocdView.setUint16(10, central.length, true);
  eocdView.setUint32(12, centralSize, true);
  eocdView.setUint32(16, offset, true);
  return concatBytes([...chunks, ...central, eocd]);
}

function concatBytes(parts: Uint8Array[]) {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const output = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

function crc32(bytes: Uint8Array) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function encodeText(value: string) {
  return new TextEncoder().encode(value);
}

function escapePdf(value: string) {
  return value.replace(/[()\\]/g, (char) => `\\${char}`);
}

function escapeXml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function assert(value: unknown, message = "Assertion failed") {
  if (!value) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}

async function assertRejects<T extends Error>(
  fn: () => Promise<unknown>,
  errorClass: new (...args: never[]) => T,
) {
  try {
    await fn();
  } catch (error) {
    if (error instanceof errorClass) return error;
    throw new Error(`Expected ${errorClass.name}, got ${String(error)}`);
  }
  throw new Error(`Expected ${errorClass.name} to be thrown`);
}

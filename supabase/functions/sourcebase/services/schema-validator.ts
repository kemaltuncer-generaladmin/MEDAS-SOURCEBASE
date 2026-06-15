import { InfographicPlan, SafeError } from "../types.ts";

export function parseModelJson<T>(text: string): T {
  const jsonText = extractJsonCandidate(text);
  const attempts = [
    jsonText,
    repairJsonText(jsonText),
    closeTruncatedJson(repairJsonText(jsonText)),
  ];
  for (const attempt of attempts) {
    try {
      return JSON.parse(attempt) as T;
    } catch (_error) {
      // Try the next repair strategy.
    }
  }
  throw new SafeError(
    "INVALID_AI_OUTPUT",
    "AI çıktısı işlenemedi.",
    500,
  );
}

export function validateInfographicSpec(value: unknown): InfographicPlan {
  if (!isRecord(value)) {
    throw invalid();
  }
  const title = requiredText(
    value.title ?? value.headline ?? value.main_title,
    "title",
  );
  const rawSections = firstArray(
    value.sections,
    value.blocks,
    value.panels,
    value.items,
    value.cards,
  );
  const sections = rawSections
    .map(sectionFromUnknown)
    .filter((section): section is { heading: string; bullets: string[] } =>
      Boolean(section)
    )
    .filter((section) => section.bullets.length > 0)
    .slice(0, 8);

  if (sections.length === 0) {
    throw invalid();
  }

  return {
    title,
    audience: optionalText(value.audience) || "medical_student",
    style: optionalText(value.style) || "premium clinical academic",
    layout: optionalText(value.layout) || "vertical infographic",
    sections,
    visual_elements: stringArray(value.visual_elements ?? value.visualNotes),
    color_palette: optionalText(value.color_palette) ||
      "MedAsi/SourceBase compatible, clean, clinical",
    avoid: stringArray(value.avoid),
    language: optionalText(value.language) || "tr",
    visualNotes: stringArray(value.visualNotes ?? value.visual_elements),
  };
}

function extractJsonCandidate(text: string) {
  if (!text.trim()) {
    throw new SafeError("EMPTY_AI_OUTPUT", "AI çıktısı boş döndü.", 500);
  }
  const jsonMatch = text.match(/```json\s*([\s\S]*?)\s*```/) ||
    text.match(/```\s*([\s\S]*?)\s*```/);
  if (jsonMatch?.[1]) return jsonMatch[1].trim();
  const firstObject = text.indexOf("{");
  const firstArray = text.indexOf("[");
  const starts = [firstObject, firstArray].filter((index) => index >= 0);
  if (starts.length === 0) return text.trim();
  const start = Math.min(...starts);
  const endObject = text.lastIndexOf("}");
  const endArray = text.lastIndexOf("]");
  const end = Math.max(endObject, endArray);
  return end > start ? text.slice(start, end + 1).trim() : text.trim();
}

function repairJsonText(text: string) {
  return text
    .replace(/,\s*([}\]])/g, "$1")
    .replace(/[“”]/g, `"`)
    .replace(/[‘’]/g, "'");
}

function closeTruncatedJson(text: string) {
  const stack: string[] = [];
  let inString = false;
  let escaped = false;

  for (const char of text) {
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === "\\" && inString) {
      escaped = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;

    if (char === "{") stack.push("}");
    else if (char === "[") stack.push("]");
    else if (char === "}" || char === "]") {
      if (stack[stack.length - 1] === char) stack.pop();
    }
  }

  let repaired = text.trimEnd();
  if (inString) repaired += '"';
  return repaired + stack.reverse().join("");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requiredText(value: unknown, field: string) {
  const text = optionalText(value);
  if (!text) {
    throw new SafeError(
      "INVALID_AI_OUTPUT",
      `AI çıktısında ${field} eksik.`,
      500,
    );
  }
  return text;
}

function optionalText(value: unknown) {
  const text = value?.toString().replace(/\s+/g, " ").trim() ?? "";
  return text || undefined;
}

function stringArray(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => optionalText(item))
    .filter((item): item is string => Boolean(item));
}

function firstArray(...values: unknown[]) {
  for (const value of values) {
    if (Array.isArray(value) && value.length > 0) return value;
  }
  return [];
}

function sectionFromUnknown(value: unknown) {
  if (typeof value === "string") {
    return {
      heading: value.slice(0, 80),
      bullets: [value],
    };
  }
  if (!isRecord(value)) return null;
  const heading = optionalText(value.heading) ||
    optionalText(value.title) ||
    optionalText(value.label) ||
    optionalText(value.name) ||
    "Kritik bilgi";
  const bullets = [
    ...stringArray(value.bullets),
    ...stringArray(value.points),
    ...stringArray(value.items),
    ...stringArray(value.key_points),
  ];
  const text = optionalText(value.text) ||
    optionalText(value.summary) ||
    optionalText(value.description);
  if (text) bullets.push(text);
  return { heading, bullets: bullets.slice(0, 8) };
}

function invalid() {
  return new SafeError(
    "INVALID_AI_OUTPUT",
    "AI çıktısı beklenen şemaya uymuyor.",
    500,
  );
}

/**
 * SourceBase Content Validators
 *
 * AI üretilen içeriğin kalite kontrolü
 * AGENTS.md Kural 12.3: Kart kalite kuralları
 */

import {
  Algorithm,
  ComparisonTable,
  Flashcard,
  PodcastScript,
  QuizQuestion,
  SafeError,
  Summary,
} from "../types.ts";

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

/**
 * Flashcard validasyonu
 */
export function validateFlashcard(card: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isFlashcard(card)) {
    errors.push("Geçersiz flashcard formatı");
    return { valid: false, errors, warnings };
  }

  // Front kontrolü
  if (!card.front || card.front.trim().length < 3) {
    errors.push("Kart ön yüzü çok kısa (min 3 karakter)");
  }
  if (card.front && card.front.length > 500) {
    warnings.push("Kart ön yüzü çok uzun (max 500 karakter önerilir)");
  }

  // Back kontrolü
  if (!card.back || card.back.trim().length < 3) {
    errors.push("Kart arka yüzü çok kısa (min 3 karakter)");
  }
  if (card.back && card.back.length > 1000) {
    warnings.push("Kart arka yüzü çok uzun (max 1000 karakter önerilir)");
  }

  // Explanation kontrolü
  if (card.explanation && card.explanation.length > 2000) {
    warnings.push("Açıklama çok uzun (max 2000 karakter önerilir)");
  }

  // Difficulty kontrolü
  if (card.difficulty && !["easy", "medium", "hard"].includes(card.difficulty)) {
    errors.push("Geçersiz zorluk seviyesi");
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Quiz question validasyonu
 */
export function validateQuizQuestion(question: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isQuizQuestion(question)) {
    errors.push("Geçersiz quiz sorusu formatı");
    return { valid: false, errors, warnings };
  }

  // Question kontrolü
  if (!question.question || question.question.trim().length < 10) {
    errors.push("Soru metni çok kısa (min 10 karakter)");
  }

  // Options kontrolü
  if (!Array.isArray(question.options) || question.options.length !== 5) {
    errors.push("Tam 5 seçenek gerekli");
  }

  // CorrectIndex kontrolü
  if (
    typeof question.correctIndex !== "number" ||
    question.correctIndex < 0 ||
    question.correctIndex >= question.options.length
  ) {
    errors.push("Geçersiz doğru cevap indeksi");
  }

  // Explanation kontrolü
  if (!question.explanation || question.explanation.trim().length < 10) {
    errors.push("Açıklama çok kısa (min 10 karakter)");
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Summary validasyonu
 */
export function validateSummary(summary: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isSummary(summary)) {
    errors.push("Geçersiz özet formatı");
    return { valid: false, errors, warnings };
  }

  // Title kontrolü
  if (!summary.title || summary.title.trim().length < 3) {
    errors.push("Başlık çok kısa (min 3 karakter)");
  }

  // BulletPoints kontrolü
  if (!Array.isArray(summary.bulletPoints) || summary.bulletPoints.length < 1) {
    errors.push("En az 1 madde gerekli");
  }
  if (summary.bulletPoints.length > 20) {
    warnings.push("Çok fazla madde (max 20 önerilir)");
  }

  // FullText kontrolü
  if (!summary.fullText || summary.fullText.trim().length < 50) {
    errors.push("Tam metin çok kısa (min 50 karakter)");
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Algorithm validasyonu
 */
export function validateAlgorithm(algorithm: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isAlgorithm(algorithm)) {
    errors.push("Geçersiz algoritma formatı");
    return { valid: false, errors, warnings };
  }

  // Title kontrolü
  if (!algorithm.title || algorithm.title.trim().length < 3) {
    errors.push("Başlık çok kısa (min 3 karakter)");
  }

  // Steps kontrolü
  if (!Array.isArray(algorithm.steps) || algorithm.steps.length < 1) {
    errors.push("En az 1 adım gerekli");
  }

  // Her adımı kontrol et
  algorithm.steps.forEach((step, index) => {
    if (!step.title || step.title.trim().length < 3) {
      errors.push(`Adım ${index + 1}: Başlık çok kısa`);
    }
    if (!step.description || step.description.trim().length < 10) {
      errors.push(`Adım ${index + 1}: Açıklama çok kısa`);
    }
  });

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Comparison table validasyonu
 */
export function validateComparisonTable(table: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isComparisonTable(table)) {
    errors.push("Geçersiz karşılaştırma tablosu formatı");
    return { valid: false, errors, warnings };
  }

  // Title kontrolü
  if (!table.title || table.title.trim().length < 3) {
    errors.push("Başlık çok kısa (min 3 karakter)");
  }

  // Headers kontrolü
  if (!Array.isArray(table.headers) || table.headers.length < 2) {
    errors.push("En az 2 sütun başlığı gerekli");
  }

  // Rows kontrolü
  if (!Array.isArray(table.rows) || table.rows.length < 1) {
    errors.push("En az 1 satır gerekli");
  }

  // Her satırı kontrol et
  table.rows.forEach((row, index) => {
    if (!row.label || row.label.trim().length < 1) {
      errors.push(`Satır ${index + 1}: Etiket eksik`);
    }
    if (!Array.isArray(row.values) || row.values.length !== table.headers.length) {
      errors.push(`Satır ${index + 1}: Değer sayısı başlık sayısıyla eşleşmiyor`);
    }
  });

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Podcast script validasyonu
 */
export function validatePodcastScript(script: unknown): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!isPodcastScript(script)) {
    errors.push("Geçersiz podcast script formatı");
    return { valid: false, errors, warnings };
  }

  // Title kontrolü
  if (!script.title || script.title.trim().length < 3) {
    errors.push("Başlık çok kısa (min 3 karakter)");
  }

  // Segments kontrolü
  if (!Array.isArray(script.segments) || script.segments.length < 1) {
    errors.push("En az 1 segment gerekli");
  }

  // Her segmenti kontrol et
  script.segments.forEach((segment, index) => {
    if (!segment.speaker || segment.speaker.trim().length < 1) {
      errors.push(`Segment ${index + 1}: Konuşmacı eksik`);
    }
    if (!segment.text || segment.text.trim().length < 10) {
      errors.push(`Segment ${index + 1}: Metin çok kısa`);
    }
  });

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

// Type guards
function isFlashcard(value: unknown): value is Flashcard {
  return (
    typeof value === "object" &&
    value !== null &&
    "front" in value &&
    "back" in value
  );
}

function isQuizQuestion(value: unknown): value is QuizQuestion {
  return (
    typeof value === "object" &&
    value !== null &&
    "question" in value &&
    "options" in value &&
    "correctIndex" in value &&
    "explanation" in value
  );
}

function isSummary(value: unknown): value is Summary {
  return (
    typeof value === "object" &&
    value !== null &&
    "title" in value &&
    "bulletPoints" in value &&
    "fullText" in value
  );
}

function isAlgorithm(value: unknown): value is Algorithm {
  return (
    typeof value === "object" &&
    value !== null &&
    "title" in value &&
    "steps" in value
  );
}

function isComparisonTable(value: unknown): value is ComparisonTable {
  return (
    typeof value === "object" &&
    value !== null &&
    "title" in value &&
    "headers" in value &&
    "rows" in value
  );
}

function isPodcastScript(value: unknown): value is PodcastScript {
  return (
    typeof value === "object" &&
    value !== null &&
    "title" in value &&
    "segments" in value
  );
}

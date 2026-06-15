/**
 * SourceBase Type Definitions
 * Tüm Edge Function'lar için ortak tipler
 */

export class SafeError extends Error {
  constructor(
    public code: string,
    message: string,
    public status: number = 400,
  ) {
    super(message);
    this.name = "SafeError";
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function requireString(value: unknown, name: string): string {
  const text = value?.toString().trim() ?? "";
  if (!text) {
    throw new SafeError("INVALID_PAYLOAD", `${name} alanı zorunlu.`, 400);
  }
  return text;
}

// Job Status Types
export type JobStatus =
  | "queued"
  | "processing"
  | "completed"
  | "failed"
  | "cancelled";

// Generation Types
export type GenerationType =
  | "flashcard"
  | "quiz"
  | "summary"
  | "exam_morning_summary"
  | "algorithm"
  | "comparison"
  | "podcast"
  | "clinical_scenario"
  | "learning_plan"
  | "infographic"
  | "mind_map";

// AI Provider Types
export type AIProvider = "openai" | "anthropic";

// Generation Job Interface
export interface GenerationJob {
  id: string;
  owner_user_id: string;
  source_file_id?: string;
  source_id?: string;
  deck_id?: string;
  job_type: GenerationType;
  status: JobStatus;
  model?: string;
  input_tokens?: number;
  output_tokens?: number;
  cost_estimate?: number;
  error_message?: string;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

// Flashcard Interface
export interface Flashcard {
  front: string;
  back: string;
  explanation?: string;
  tags?: string[];
  difficulty?: "easy" | "medium" | "hard";
}

// Quiz Question Interface
export interface QuizQuestion {
  question: string;
  options: string[];
  correctIndex: number;
  explanation: string;
  optionRationales?: string[];
  difficulty?: "easy" | "medium" | "hard";
}

// Summary Interface
export interface Summary {
  title: string;
  bulletPoints: string[];
  fullText: string;
  keyTerms?: string[];
  mainTopics?: string[];
  mustKnow?: string[];
  redFlags?: string[];
  commonlyConfused?: string[];
  clinicalDecisionFlow?: string[];
  examTraps?: string[];
}

export interface ExamMorningSummary {
  title: string;
  must_know: string[];
  commonly_confused: string[];
  clinical_tus_tips: string[];
  red_flags?: string[];
  mini_table?: {
    headers?: string[];
    rows: Array<Record<string, string> | string[] | string>;
  };
  algorithm_flow?: string[];
  self_check: Array<{
    question: string;
    answer: string;
  }>;
}

// Algorithm Interface
export interface Algorithm {
  title: string;
  steps: Array<{
    stepNumber: number;
    title: string;
    description: string;
  }>;
  notes?: string;
}

// Comparison Table Interface
export interface ComparisonTable {
  title: string;
  headers: string[];
  rows: Array<{
    label: string;
    values: string[];
  }>;
}

// Podcast Script Interface
export interface PodcastScript {
  title: string;
  duration: string;
  segments: Array<{
    speaker: string;
    text: string;
    timestamp?: string;
  }>;
}

export interface ClinicalScenario {
  title: string;
  patientInfo?: string;
  chiefComplaint?: string;
  history?: string;
  physicalExam?: string[];
  labsImaging?: string[];
  decisionPoint?: string;
  caseStem: string;
  findings: string[];
  questions: Array<{
    question: string;
    answer: string;
    explanation?: string;
  }>;
  learningObjective?: string[];
  examTips?: string[];
  teachingPoints: string[];
}

export interface LearningPlan {
  title: string;
  sourceName?: string;
  duration?: string;
  dailyGoals?: string[];
  checklist?: string[];
  reviewDays?: string[];
  questionFlashcardSuggestions?: string[];
  weakPoints?: string[];
  startToday?: string[];
  objectives: string[];
  sessions: Array<{
    title: string;
    activities: string[];
    estimatedMinutes?: number;
  }>;
  checkpoints: string[];
}

export interface InfographicPlan {
  title: string;
  audience?: string;
  style?: string;
  layout?: string;
  sections: Array<{
    heading: string;
    bullets: string[];
  }>;
  visual_elements?: string[];
  color_palette?: string;
  avoid?: string[];
  language?: string;
  visualNotes: string[];
  image?: {
    provider: string;
    model: string;
    mimeType: string;
    dataUrl?: string;
    url?: string;
    prompt?: string;
  };
}

export interface MindMap {
  title: string;
  centralTopic: string;
  branches: Array<{
    label: string;
    children: string[];
  }>;
}

// Central AI Chat Message
export interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
  timestamp?: string;
}

// Central AI Chat Response
export interface ChatResponse {
  message: string;
  suggestions?: string[];
  context?: Record<string, unknown>;
}

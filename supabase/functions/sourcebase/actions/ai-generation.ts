/**
 * SourceBase AI Generation Actions
 *
 * Edge Function actions for AI content generation.
 * AGENTS.md Kural 11: OpenAI API key sadece server-side kullanılır.
 */

import {
  getObjectStorageConfig,
  getSupabaseServiceRoleKey,
  getSupabaseUrl,
} from "../config.ts";
import {
  GenerationJob,
  GenerationType,
  isRecord,
  requireString,
  SafeError,
} from "../types.ts";
import { logAiPipeline } from "../services/ai-logger.ts";
import { createSignedReadUrl } from "../services/object-storage.ts";
import {
  JobGenerationOptions,
  JobProcessor,
  updateJob,
} from "../services/job-processor.ts";
import type { McPricingQuote } from "../services/medasicoin-pricing.ts";
import {
  estimateGenerationPricing,
  normalizeQualityTier,
  routeOptionsForQuality,
} from "../services/medasicoin-pricing.ts";
import {
  captureMedasiCoin,
  getWalletBalance,
  refundMedasiCoin,
  reserveMedasiCoin,
} from "../services/medasicoin-wallet.ts";
import {
  resolveTextRoute,
  routeOptionsFromPayload,
} from "../services/model-router.ts";
import { AITextClient } from "../services/ai-generation-provider.ts";
import {
  downloadFromObjectStorage,
  estimateTokens,
  extractDocx,
  extractPdf,
  extractPptx,
  sanitizeSourceText,
} from "../services/extraction.ts";
import {
  normalizeSourceFileType,
  userMessageForLimitedLegacyType,
} from "../services/file-types.ts";

const MAX_EXPLICIT_SOURCE_CHARS = 120_000;
const MAX_CHAT_MESSAGE_CHARS = 4_000;
const MAX_CHAT_CONTEXT_CHARS = 12_000;
const MAX_CONTEXT_FILES = 5;
const MAX_ACTIVE_USER_JOBS = 3;
const STALE_ACTIVE_JOB_MS = Number(
  Deno.env.get("SOURCEBASE_STALE_ACTIVE_JOB_MS") ?? "240000",
) || 240_000;

const JOB_TYPE_ALIASES: Record<string, GenerationType> = {
  flashcard: "flashcard",
  flashcards: "flashcard",
  quiz: "quiz",
  question: "quiz",
  questions: "quiz",
  summary: "summary",
  exam_morning_summary: "exam_morning_summary",
  examMorningSummary: "exam_morning_summary",
  algorithm: "algorithm",
  comparison: "comparison",
  podcast: "podcast",
  clinical_scenario: "clinical_scenario",
  clinicalScenario: "clinical_scenario",
  learning_plan: "learning_plan",
  learningPlan: "learning_plan",
  infographic: "infographic",
  mind_map: "mind_map",
  mindMap: "mind_map",
};

/**
 * Process file extraction
 * Dosyadan metin çıkarımı yapar
 */
export async function processFileExtraction(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const fileId = requireUuid(payload.fileId, "fileId");

  const extractionResult = await extractTextFromDriveFile(userId, fileId);

  return {
    fileId,
    textLength: extractionResult.text.length,
    pageCount: extractionResult.pageCount,
    chunkCount: extractionResult.chunks.length,
    tokenEstimate: estimateTokens(extractionResult.text),
  };
}

async function extractTextFromDriveFile(userId: string, fileId: string) {
  const supabaseUrl = getSupabaseUrl();
  const serviceKey = getSupabaseServiceRoleKey();

  if (!supabaseUrl || !serviceKey) {
    throw new SafeError(
      "CONFIG_ERROR",
      "Sunucu yapılandırması eksik.",
      500,
    );
  }

  const response = await fetch(
    `${supabaseUrl}/rest/v1/drive_files?id=eq.${fileId}&owner_user_id=eq.${userId}&select=*&limit=1`,
    {
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "accept-profile": "sourcebase",
      },
    },
  );

  if (!response.ok) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }

  const files = await response.json();
  if (!Array.isArray(files) || files.length === 0) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }

  const file = files[0];
  const bucket = String(file.storage_bucket ?? "");
  const objectName = String(file.storage_object_name ?? "");
  const normalizedFileType = normalizeSourceFileType({
    fileName: String(file.original_filename ?? file.title ?? objectName),
    contentType: String(file.mime_type ?? ""),
  });
  const storedFileType = String(file.file_type ?? "").trim().toLowerCase();
  const storedFileTypeInfo = normalizeSourceFileType({
    fileName: storedFileType.includes("/") ? "" : `source.${storedFileType}`,
    contentType: storedFileType.includes("/") ? storedFileType : "",
  });
  const fileType = normalizedFileType.type !== "unknown"
    ? normalizedFileType.type
    : storedFileTypeInfo.type;
  if (
    !bucket || !objectName ||
    !objectName.startsWith(`sourcebase/users/${userId}/`)
  ) {
    throw new SafeError(
      "FILE_STORAGE_INVALID",
      "Dosya depolama bilgisi doğrulanamadı.",
      400,
    );
  }

  let storage;
  try {
    storage = getObjectStorageConfig();
  } catch (_error) {
    throw new SafeError(
      "STORAGE_NOT_CONFIGURED",
      "Dosya depolama yapılandırılmamış.",
      500,
    );
  }

  const fileBuffer = await downloadFromObjectStorage(
    bucket,
    objectName,
    storage,
  );

  let extractionResult;
  switch (fileType) {
    case "pdf":
      extractionResult = await extractPdf(fileBuffer);
      break;
    case "docx":
      extractionResult = await extractDocx(fileBuffer);
      break;
    case "pptx":
      extractionResult = await extractPptx(fileBuffer);
      break;
    case "ppt":
      throw new SafeError(
        "FILE_TYPE_LIMITED_SUPPORT",
        userMessageForLimitedLegacyType("ppt"),
        400,
      );
    case "doc":
      throw new SafeError(
        "FILE_TYPE_LIMITED_SUPPORT",
        userMessageForLimitedLegacyType("doc"),
        400,
      );
    default:
      throw new SafeError(
        "FILE_TYPE_UNSUPPORTED",
        "Bu dosya türü desteklenmiyor. PDF, PPTX, PPT, DOCX veya DOC yükleyin.",
        400,
      );
  }

  if (!extractionResult.text.trim()) {
    throw new SafeError(
      "FILE_TEXT_EMPTY",
      "Dosyadan okunabilir metin çıkarılamadı.",
      400,
    );
  }

  const updateResponse = await fetch(
    `${supabaseUrl}/rest/v1/drive_files?id=eq.${fileId}`,
    {
      method: "PATCH",
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "content-type": "application/json",
        "accept-profile": "sourcebase",
        "content-profile": "sourcebase",
      },
      body: JSON.stringify({
        page_count: extractionResult.pageCount,
        ai_status: "ready",
        metadata: {
          ...file.metadata,
          extraction: {
            textLength: extractionResult.text.length,
            chunkCount: extractionResult.chunks.length,
            extractedAt: new Date().toISOString(),
          },
        },
      }),
    },
  );
  if (!updateResponse.ok) {
    throw new SafeError(
      "FILE_UPDATE_FAILED",
      "Dosya işleme durumu güncellenemedi.",
      500,
    );
  }

  return extractionResult;
}

/**
 * Create generation job
 * AI içerik üretim işi başlatır
 */
export async function createGenerationJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const fileId = optionalUuid(payload.fileId, "fileId");
  const jobType = normalizeJobType(requireString(payload.jobType, "jobType"));
  const selectedSourceIds = generationSourceIds(fileId, payload);
  const primaryFileId = fileId ?? selectedSourceIds[0];
  logAiPipeline({
    action: "create_generation_job",
    status: "received",
    jobType,
  });
  for (const sourceId of selectedSourceIds) {
    await assertDriveFileOwned(userId, sourceId);
  }
  const explicitSourceText = sanitizeSourceText(
    payload.sourceText?.toString() ?? "",
  );
  if (explicitSourceText.length > MAX_EXPLICIT_SOURCE_CHARS) {
    throw new SafeError(
      "SOURCE_TEXT_TOO_LARGE",
      "Kaynak metin çok uzun.",
      400,
    );
  }
  const sourceTextLength = explicitSourceText.length ||
    (selectedSourceIds.length > 0
      ? await sourceTextLengthForSourceIds(userId, selectedSourceIds)
      : 0);
  if (!explicitSourceText.trim() && selectedSourceIds.length === 0) {
    throw new SafeError(
      "SOURCE_TEXT_REQUIRED",
      "Kaynak metin veya dosya seçimi gerekli.",
      400,
    );
  }

  const count = boundedNumber(payload.count, undefined, 1, 100, "count", true);
  const temperature = boundedNumber(
    payload.temperature,
    undefined,
    0,
    1,
    "temperature",
  );
  const modelPolicy = textOption(payload.modelPolicy) ??
    textOption(payload.model_policy);
  const minimumDepth = textOption(payload.minimumDepth) ??
    textOption(payload.minimum_depth);
  const outputLengthPolicy = textOption(payload.outputLengthPolicy) ??
    textOption(payload.output_length_policy);
  const imageModelPolicy = textOption(payload.imageModelPolicy) ??
    textOption(payload.image_model_policy) ??
    textOption(payload.gptImageModel) ??
    textOption(payload.gpt_image_model) ??
    textOption(payload.openaiImageModel) ??
    textOption(payload.openai_image_model) ??
    textOption(payload.imageModel) ??
    textOption(payload.image_model);
  const maxTokens = boundedNumber(
    payload.maxTokens ?? payload.max_tokens,
    defaultMaxTokens(jobType, sourceTextLength, outputLengthPolicy),
    256,
    8192,
    "maxTokens",
    true,
  );
  const qualityTier = normalizeQualityTier(
    payload.quality_tier ?? payload.qualityTier,
  );
  const routingPayload = {
    ...payload,
    sourceIds: selectedSourceIds,
    source_ids: selectedSourceIds,
    sourceCount: selectedSourceIds.length || undefined,
    source_count: selectedSourceIds.length || undefined,
    selectedSourceCount: selectedSourceIds.length || undefined,
    selected_source_count: selectedSourceIds.length || undefined,
  };
  const routeOptions = routeOptionsForQuality(
    qualityTier,
    routeOptionsFromPayload(routingPayload),
  );
  const pricing = estimateGenerationPricing({
    jobType,
    sourceTextLength,
    maxTokens,
    count,
    qualityTier,
    routeOptions,
  });
  const config = createAiConfig();
  const walletConfig = {
    supabaseUrl: config.supabaseUrl,
    serviceRoleKey: config.serviceRoleKey,
  };
  const balance = await getWalletBalance(walletConfig, userId);
  if (balance.balance_units < pricing.amount_units) {
    throw new SafeError(
      "INSUFFICIENT_MC",
      "Yetersiz MedasiCoin bakiyesi.",
      402,
    );
  }

  const processor = new JobProcessor(config);
  await assertJobCapacity(processor, userId, primaryFileId, jobType);

  const jobInput = {
    userId,
    sourceFileId: primaryFileId,
    jobType,
    sourceText: explicitSourceText,
    options: {
      count,
      temperature,
      maxTokens,
      sourceTextLength,
      sourceIds: selectedSourceIds,
      routeOptions,
      pricing,
      summaryMode: textOption(payload.summary_mode) ??
        defaultSummaryMode(jobType, outputLengthPolicy),
      lengthTarget: textOption(payload.length_target) ??
        defaultLengthTarget(jobType, sourceTextLength, outputLengthPolicy),
      outputFormat: textOption(payload.output_format) ??
        defaultOutputFormat(jobType, outputLengthPolicy),
      cardStyle: textOption(payload.card_style),
      extractKeyConcepts: booleanOption(payload.extract_key_concepts),
      addHints: booleanOption(payload.add_hints),
      questionType: textOption(payload.question_type),
      explanations: booleanOption(payload.explanations),
      algorithmType: textOption(payload.algorithm_type),
      comparisonType: textOption(payload.comparison_type),
      tableFormat: textOption(payload.table_format),
      detailLevel: textOption(payload.detail_level),
      infographicType: textOption(payload.infographic_type),
      visualStyle: textOption(payload.visual_style),
      density: textOption(payload.density),
      mapType: textOption(payload.map_type),
      depth: textOption(payload.depth),
      viewMode: textOption(payload.view_mode),
      scenarioType: textOption(payload.scenario_type),
      difficulty: textOption(payload.difficulty),
      planGoal: textOption(payload.plan_goal),
      dailyTime: textOption(payload.daily_time),
      studyStyle: textOption(payload.study_style),
      qualityTier,
      modelPolicy,
      minimumDepth,
      outputLengthPolicy,
      imageModelPolicy,
      aiBrief: textOption(payload.aiBrief) ?? textOption(payload.ai_brief),
      outputContract: textOption(payload.outputContract) ??
        textOption(payload.output_contract),
    },
  };
  const job = await processor.createQueuedJob(jobInput);
  logAiPipeline({
    action: "create_generation_job",
    status: "queued",
    jobId: job.id,
    jobType,
    provider: job.metadata?.modelRoute && isRecord(job.metadata.modelRoute)
      ? job.metadata.modelRoute.provider?.toString()
      : undefined,
    model: job.model,
  });
  let reservation;
  try {
    reservation = await reserveMedasiCoin({
      config: walletConfig,
      userId,
      jobId: job.id,
      quote: pricing,
      reason: `ai_generation:${jobType}`,
    });
  } catch (error) {
    const errorCode = error instanceof SafeError ? error.code : "WALLET_ERROR";
    logAiPipeline({
      action: "create_generation_job",
      status: "failed",
      jobId: job.id,
      jobType,
      errorCode,
    });
    await updateJob(config.supabaseUrl, config.serviceRoleKey, job.id, {
      status: "failed",
      error_message: error instanceof SafeError
        ? error.message
        : "MedasiCoin rezervasyonu tamamlanamadı.",
      metadata: {
        ...job.metadata,
        errorCode,
        failedAt: new Date().toISOString(),
      },
    });
    throw error;
  }

  return {
    jobId: job.id,
    status: job.status,
    jobType: job.job_type,
    createdAt: job.created_at,
    ...pricing,
    balance_before: reservation.balance_before,
    balance_after_reserve: reservation.balance_after_reserve,
  };
}

export async function processGenerationJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireUuid(payload.jobId, "jobId");
  logAiPipeline({
    action: "process_generation_job",
    status: "received",
    jobId,
  });

  const processor = createJobProcessor();
  const job = await processor.getJobStatus(userId, jobId);
  if (job.status === "completed") {
    return {
      jobId: job.id,
      status: job.status,
      jobType: job.job_type,
      alreadyCompleted: true,
    };
  }
  if (job.status === "cancelled") {
    throw new SafeError("JOB_CANCELLED", "İş iptal edilmiş.", 400);
  }
  if (job.status === "failed") {
    const metadata = isRecord(job.metadata) ? job.metadata : {};
    throw new SafeError(
      metadata.errorCode?.toString() || "JOB_ALREADY_FAILED",
      job.error_message || "AI üretimi tamamlanamadı.",
      400,
    );
  }
  if (isStaleActiveJob(job)) {
    const staleError = staleActiveJobError(job);
    await processor.failJobBeforeProcessing(job, job.job_type, staleError);
    throw staleError;
  }
  if (job.status === "processing") {
    return {
      jobId: job.id,
      status: job.status,
      jobType: job.job_type,
      alreadyProcessing: true,
    };
  }

  // The full generation (text + optional image/audio) routinely exceeds the
  // public gateway's ~60s request cap; a synchronous await returns a 504 to the
  // client AND the edge worker is recycled when the connection drops, leaving the
  // job stuck "processing" forever (this is why media/premium jobs never finished
  // and infographic images never rendered). Run the work in the background via
  // EdgeRuntime.waitUntil (worker stays alive ~5min) and return immediately so the
  // client just polls job status. Falls back to synchronous for local/dev.
  const runWork = async () => {
    let sourceText: string;
    try {
      sourceText = await sourceTextForJob(userId, job);
    } catch (error) {
      await processor.failJobBeforeProcessing(job, job.job_type, error).catch(
        () => {},
      );
      return;
    }
    try {
      await processor.processJob(job, {
        jobType: job.job_type,
        sourceText,
        options: generationOptionsFromJob(job.metadata),
      });
    } catch (error) {
      await processor.failJobBeforeProcessing(job, job.job_type, error).catch(
        () => {},
      );
    }
  };

  const edgeWaitUntil =
    (globalThis as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } })
      .EdgeRuntime?.waitUntil;
  if (typeof edgeWaitUntil === "function") {
    edgeWaitUntil(runWork());
    return {
      jobId: job.id,
      status: "processing",
      jobType: job.job_type,
      scheduled: true,
    };
  }

  await runWork();
  const done = await processor.getJobStatus(userId, jobId);
  return {
    jobId: done.id,
    status: done.status,
    jobType: done.job_type,
    inputTokens: done.input_tokens,
    outputTokens: done.output_tokens,
    costEstimate: done.cost_estimate,
  };
}

// Hard cap on the source text fed to a single model call. Large/huge PDFs
// otherwise blow the model context window (OpenAI 400 context_length_exceeded),
// which silently failed the whole job (and meant infographic/podcast media never
// ran). ~200K chars ≈ 55-65K tokens — safe for every routed model with ample room
// left for the system prompt, the JSON contract, and the output budget.
const MAX_SOURCE_CHARS = 200_000;

function capSourceText(text: string): string {
  if (text.length <= MAX_SOURCE_CHARS) return text;
  const head = text.slice(0, MAX_SOURCE_CHARS);
  // Cut on a sentence/line boundary when possible so we don't end mid-word.
  const lastBreak = Math.max(head.lastIndexOf("\n"), head.lastIndexOf(". "));
  const trimmed = lastBreak > MAX_SOURCE_CHARS * 0.6
    ? head.slice(0, lastBreak + 1)
    : head;
  return `${trimmed}\n\n[Kaynak çok uzun olduğu için en yüksek getirili ilk bölümü işlendi.]`;
}

async function sourceTextForJob(userId: string, job: GenerationJob) {
  const metadata = isRecord(job.metadata) ? job.metadata : {};
  const options = isRecord(metadata.generationOptions)
    ? metadata.generationOptions
    : {};
  const sourceIds = sourceIdsFromValue(options.sourceIds ?? options.source_ids);
  if (sourceIds.length > 0) {
    return capSourceText(await sourceTextForSourceIds(userId, sourceIds));
  }
  if (job.source_file_id) {
    return capSourceText(
      (await extractTextFromDriveFile(userId, job.source_file_id)).text,
    );
  }
  const sourceText = sanitizeSourceText(metadata.sourceText?.toString() ?? "");
  if (sourceText.trim()) return capSourceText(sourceText);
  throw new SafeError(
    "SOURCE_TEXT_REQUIRED",
    "Üretim işi için kaynak metin bulunamadı.",
    400,
  );
}

async function sourceTextForSourceIds(userId: string, sourceIds: string[]) {
  const uniqueSourceIds = uniqueIds(sourceIds);
  const parts: string[] = [];
  for (const [index, sourceId] of uniqueSourceIds.entries()) {
    const extraction = await extractTextFromDriveFile(userId, sourceId);
    parts.push(`## Kaynak ${index + 1}\n${extraction.text}`);
  }
  return parts.join("\n\n").trim();
}

async function sourceTextLengthForSourceIds(
  userId: string,
  sourceIds: string[],
) {
  const uniqueSourceIds = uniqueIds(sourceIds);
  if (uniqueSourceIds.length === 0) return 0;
  const supabaseUrl = getSupabaseUrl();
  const serviceKey = getSupabaseServiceRoleKey();
  if (!supabaseUrl || !serviceKey) {
    throw new SafeError(
      "CONFIG_ERROR",
      "Sunucu yapılandırması eksik.",
      500,
    );
  }
  const response = await fetch(
    `${supabaseUrl}/rest/v1/drive_files?id=in.(${
      uniqueSourceIds.join(",")
    })&owner_user_id=eq.${userId}&select=id,size_bytes,page_count,metadata`,
    {
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "accept-profile": "sourcebase",
      },
    },
  );
  if (!response.ok) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }
  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length !== uniqueSourceIds.length) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }
  return rows.reduce((total, row) => total + estimatedTextLength(row), 0);
}

function estimatedTextLength(row: Record<string, unknown>) {
  const metadata = isRecord(row.metadata) ? row.metadata : {};
  const extraction = isRecord(metadata.extraction) ? metadata.extraction : {};
  const extractedLength = numericOption(
    extraction.textLength ?? extraction.text_length,
  );
  if (extractedLength && extractedLength > 0) return extractedLength;
  const pageCount = numericOption(row.page_count);
  if (pageCount && pageCount > 0) return Math.max(1_500, pageCount * 900);
  const sizeBytes = numericOption(row.size_bytes);
  if (sizeBytes && sizeBytes > 0) {
    return Math.max(1_500, Math.min(160_000, Math.ceil(sizeBytes / 180)));
  }
  return 8_000;
}

function generationSourceIds(
  primaryFileId: string | undefined,
  payload: Record<string, unknown>,
) {
  const ids = uniqueIds([
    ...(primaryFileId ? [primaryFileId] : []),
    ...sourceIdsFromValue(
      payload.sourceIds ?? payload.source_ids ??
        payload.selectedSourceIds ?? payload.selected_source_ids,
    ),
  ]);
  if (ids.length > MAX_CONTEXT_FILES) {
    throw new SafeError(
      "TOO_MANY_SOURCE_FILES",
      `En fazla ${MAX_CONTEXT_FILES} kaynak aynı üretimde kullanılabilir.`,
      400,
    );
  }
  return ids;
}

function sourceIdsFromValue(value: unknown) {
  const raw = Array.isArray(value)
    ? value
    : (value?.toString().trim() ?? "")
    ? value!.toString().split(",")
    : [];
  return uniqueIds(raw.map((item) => requireUuid(item, "sourceIds")));
}

function uniqueIds(ids: string[]) {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const id of ids) {
    if (!seen.has(id)) {
      seen.add(id);
      result.push(id);
    }
  }
  return result;
}

function generationOptionsFromJob(
  metadataValue: unknown,
): JobGenerationOptions {
  const metadata = isRecord(metadataValue) ? metadataValue : {};
  const options = isRecord(metadata.generationOptions)
    ? metadata.generationOptions
    : {};
  return {
    count: numericOption(options.count),
    temperature: numericOption(options.temperature),
    maxTokens: numericOption(options.maxTokens),
    sourceIds: sourceIdsFromValue(options.sourceIds ?? options.source_ids),
    routeOptions: isRecord(options.routeOptions) ? options.routeOptions : {},
    pricing: isRecord(metadata.pricing)
      ? metadata.pricing as unknown as McPricingQuote
      : undefined,
    summaryMode: textOption(options.summaryMode),
    lengthTarget: textOption(options.lengthTarget),
    outputFormat: textOption(options.outputFormat),
    cardStyle: textOption(options.cardStyle),
    extractKeyConcepts: booleanOption(options.extractKeyConcepts),
    addHints: booleanOption(options.addHints),
    questionType: textOption(options.questionType),
    explanations: booleanOption(options.explanations),
    algorithmType: textOption(options.algorithmType),
    comparisonType: textOption(options.comparisonType),
    tableFormat: textOption(options.tableFormat),
    detailLevel: textOption(options.detailLevel),
    infographicType: textOption(options.infographicType),
    visualStyle: textOption(options.visualStyle),
    density: textOption(options.density),
    mapType: textOption(options.mapType),
    depth: textOption(options.depth),
    viewMode: textOption(options.viewMode),
    scenarioType: textOption(options.scenarioType),
    difficulty: textOption(options.difficulty),
    planGoal: textOption(options.planGoal),
    dailyTime: textOption(options.dailyTime),
    studyStyle: textOption(options.studyStyle),
    qualityTier: textOption(options.qualityTier),
    modelPolicy: textOption(options.modelPolicy),
    minimumDepth: textOption(options.minimumDepth),
    outputLengthPolicy: textOption(options.outputLengthPolicy),
    imageModelPolicy: textOption(options.imageModelPolicy),
    aiBrief: textOption(options.aiBrief),
    outputContract: textOption(options.outputContract),
    studentContext: textOption(options.studentContext ?? options.student_context),
  };
}

export async function estimateGenerationCost(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const rawJobType = requireString(payload.jobType, "jobType");
  const jobType =
    rawJobType === "central_ai" || rawJobType === "central_ai_chat"
      ? "central_ai"
      : normalizeJobType(rawJobType);
  const fileId = optionalUuid(payload.fileId, "fileId");
  const selectedSourceIds = generationSourceIds(fileId, payload);
  const sourceText = sanitizeSourceText(payload.sourceText?.toString() ?? "");
  const requestedSourceTextLength = sourceText.length ||
    boundedNumber(
      payload.sourceTextLength,
      0,
      0,
      MAX_EXPLICIT_SOURCE_CHARS,
      "sourceTextLength",
      true,
    ) ||
    0;
  const sourceTextLength = requestedSourceTextLength ||
    (selectedSourceIds.length > 0
      ? await sourceTextLengthForSourceIds(userId, selectedSourceIds)
      : 0);
  const maxTokens = boundedNumber(
    payload.maxTokens,
    undefined,
    256,
    8192,
    "maxTokens",
    true,
  );
  const count = boundedNumber(payload.count, undefined, 1, 100, "count", true);
  const qualityTier = normalizeQualityTier(
    payload.quality_tier ?? payload.qualityTier,
  );
  const routingPayload = {
    ...payload,
    sourceIds: selectedSourceIds,
    source_ids: selectedSourceIds,
    sourceCount: selectedSourceIds.length || undefined,
    source_count: selectedSourceIds.length || undefined,
    selectedSourceCount: selectedSourceIds.length || undefined,
    selected_source_count: selectedSourceIds.length || undefined,
  };
  const routeOptions = routeOptionsForQuality(
    qualityTier,
    routeOptionsFromPayload(routingPayload),
  );
  const pricing = estimateGenerationPricing({
    jobType,
    sourceTextLength,
    maxTokens,
    count,
    qualityTier,
    routeOptions,
  });
  const config = createAiConfig();
  const balance = await getWalletBalance({
    supabaseUrl: config.supabaseUrl,
    serviceRoleKey: config.serviceRoleKey,
  }, userId);
  return {
    ...pricing,
    can_afford: balance.balance_units >= pricing.amount_units,
    current_balance: balance.balance_mc,
    balance_after: (balance.balance_units - pricing.amount_units) / 100,
    explanation:
      "AI maliyeti gerçek sağlayıcı tahmini + hedef brüt marj ile hesaplandı.",
  };
}

/**
 * Get job status
 * İş durumunu sorgular
 */
export async function getJobStatus(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireUuid(payload.jobId, "jobId");

  const processor = createJobProcessor();
  const job = await processor.getJobStatus(userId, jobId);

  return {
    jobId: job.id,
    status: job.status,
    jobType: job.job_type,
    inputTokens: job.input_tokens,
    outputTokens: job.output_tokens,
    costEstimate: job.cost_estimate,
    errorMessage: job.error_message,
    errorCode: isRecord(job.metadata) ? job.metadata.errorCode : undefined,
    createdAt: job.created_at,
    updatedAt: job.updated_at,
  };
}

/**
 * Get generated content
 * Üretilen içeriği getirir
 */
export async function getGeneratedContent(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireUuid(payload.jobId, "jobId");

  const processor = createJobProcessor();
  const job = await processor.getJobStatus(userId, jobId);

  if (job.status !== "completed") {
    throw new SafeError(
      "JOB_NOT_COMPLETED",
      "İş henüz tamamlanmadı.",
      400,
    );
  }

  const metadata = isRecord(job.metadata) ? job.metadata : {};
  const content = await signContentAssetUrls(metadata.content ?? null);

  return {
    jobId: job.id,
    jobType: job.job_type,
    content,
    inputTokens: job.input_tokens,
    outputTokens: job.output_tokens,
    costEstimate: job.cost_estimate,
  };
}

const ASSET_READ_URL_TTL_SECONDS = 3600;

/**
 * Generated assets (infografik görseli, podcast sesi) object storage'da private
 * tutulur. İstemci yalnızca http(s) URL oynatabildiği için, okuma anında kısa
 * ömürlü imzalı URL üretip içeriğe gömeriz.
 */
async function signContentAssetUrls(content: unknown): Promise<unknown> {
  if (!isRecord(content)) return content;
  let next = content;

  const image = isRecord(next.image) ? next.image : null;
  const imageObject = image?.storageObjectName?.toString();
  if (image && imageObject) {
    const url = await signAssetUrl(imageObject);
    if (url) next = { ...next, image: { ...image, url, signedUrl: url } };
  }

  const audio = isRecord(next.audio) ? next.audio : null;
  const audioObject = audio?.storageObjectName?.toString();
  if (audio && audioObject) {
    const url = await signAssetUrl(audioObject);
    if (url) {
      next = {
        ...next,
        audio: { ...audio, url, signedUrl: url },
        audioUrl: url,
      };
    }
  }

  return next;
}

async function signAssetUrl(objectName: string): Promise<string | undefined> {
  try {
    return await createSignedReadUrl({
      storage: getObjectStorageConfig(),
      objectName,
      expiresInSeconds: ASSET_READ_URL_TTL_SECONDS,
    });
  } catch (error) {
    const code = error instanceof SafeError ? error.code : "ASSET_SIGN_FAILED";
    console.warn("generated asset url signing skipped:", code);
    return undefined;
  }
}

/**
 * List user jobs
 * Kullanıcının tüm işlerini listeler
 */
export async function listUserJobs(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const limit = boundedNumber(payload.limit, 50, 1, 100, "limit") ?? 50;

  const processor = createJobProcessor();
  const jobs = await processor.listUserJobs(userId, limit);

  return {
    jobs: jobs.map((job) => ({
      jobId: job.id,
      status: job.status,
      jobType: job.job_type,
      inputTokens: job.input_tokens,
      outputTokens: job.output_tokens,
      costEstimate: job.cost_estimate,
      errorMessage: job.error_message,
      createdAt: job.created_at,
      updatedAt: job.updated_at,
    })),
  };
}

/**
 * Cancel job
 * İşi iptal eder
 */
export async function cancelJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireUuid(payload.jobId, "jobId");

  const processor = createJobProcessor();
  await processor.cancelJob(userId, jobId);

  return {
    jobId,
    status: "cancelled",
  };
}

/**
 * Retry job
 * Başarısız işi yeniden dener
 */
export async function retryJob(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const jobId = requireUuid(payload.jobId, "jobId");

  const processor = createJobProcessor();
  const oldJob = await processor.getJobStatus(userId, jobId);
  const retryResult = await createGenerationJob(
    userId,
    retryPayloadFromJob(oldJob),
  );
  const retry = isRecord(retryResult) ? retryResult : {};

  return {
    oldJobId: jobId,
    newJobId: retry.jobId,
    status: retry.status,
  };
}

function retryPayloadFromJob(job: GenerationJob): Record<string, unknown> {
  const metadata = isRecord(job.metadata) ? job.metadata : {};
  const generationOptions = isRecord(metadata.generationOptions)
    ? metadata.generationOptions
    : {};
  const routeOptions = isRecord(generationOptions.routeOptions)
    ? generationOptions.routeOptions
    : {};
  const payload: Record<string, unknown> = {
    ...routeOptions,
    ...generationOptions,
    jobType: job.job_type,
  };
  delete payload.routeOptions;
  delete payload.pricing;

  if (job.source_file_id) {
    payload.fileId = job.source_file_id;
  }
  const sourceIds = sourceIdsFromValue(
    generationOptions.sourceIds ?? generationOptions.source_ids,
  );
  if (sourceIds.length > 0) {
    payload.sourceIds = sourceIds;
  }
  const sourceText = sanitizeSourceText(metadata.sourceText?.toString() ?? "");
  if (!job.source_file_id && sourceText.trim()) {
    payload.sourceText = sourceText;
  }
  return payload;
}

/**
 * Central AI chat
 * Merkezi AI ekranı için doğrudan yanıt üretir.
 */
export async function centralAiChat(
  userId: string,
  payload: Record<string, unknown>,
): Promise<unknown> {
  const message = validateLength(
    requireString(payload.message, "message"),
    MAX_CHAT_MESSAGE_CHARS,
    "message",
  );
  const rawContext = sanitizeSourceText(payload.context?.toString() ?? "");
  const fileContext = await buildOwnedFileContext(userId, payload);
  const context = validateLength(
    [rawContext, fileContext].filter(Boolean).join("\n\n").trim(),
    MAX_CHAT_CONTEXT_CHARS,
    "context",
  );
  const config = createAiConfig();
  const qualityTier = normalizeQualityTier(
    payload.quality_tier ?? payload.qualityTier,
  );
  const routeOptions = routeOptionsForQuality(
    qualityTier,
    routeOptionsFromPayload(payload),
  );
  const pricing = estimateGenerationPricing({
    jobType: "central_ai",
    sourceTextLength: context.length + message.length,
    maxTokens: boundedNumber(
      payload.maxTokens,
      undefined,
      256,
      4096,
      "maxTokens",
      true,
    ),
    qualityTier,
    routeOptions,
  });
  const walletConfig = {
    supabaseUrl: config.supabaseUrl,
    serviceRoleKey: config.serviceRoleKey,
  };
  const balance = await getWalletBalance(walletConfig, userId);
  if (balance.balance_units < pricing.amount_units) {
    throw new SafeError(
      "INSUFFICIENT_MC",
      "Yetersiz MedasiCoin bakiyesi.",
      402,
    );
  }
  const reservation = await reserveMedasiCoin({
    config: walletConfig,
    userId,
    quote: pricing,
    reason: "central_ai_chat",
  });
  const ai = new AITextClient();
  const route = resolveTextRoute(
    "central_ai_chat",
    routeOptions,
    context.length + message.length,
  );
  try {
    const reply = await ai.generateCentralAiReply(message, context, {
      provider: route.provider,
      model: route.model,
    });
    await captureMedasiCoin({
      config: walletConfig,
      userId,
      reason: "central_ai_chat_capture",
      metadata: { pricing, modelRoute: pricing.route },
    });

    return {
      message: reply.content,
      inputTokens: reply.inputTokens,
      outputTokens: reply.outputTokens,
      costEstimate: reply.costEstimate,
      modelRoute: {
        provider: route.provider,
        model: route.model,
        tier: route.tier,
        reason: route.reason,
        fallbackUsed: route.fallbackUsed,
      },
      ...pricing,
      balance_before: reservation.balance_before,
      balance_after_reserve: reservation.balance_after_reserve,
    };
  } catch (error) {
    await refundMedasiCoin({
      config: walletConfig,
      userId,
      amountUnits: pricing.amount_units,
      reason: "central_ai_chat_refund",
      metadata: {
        errorCode: error instanceof SafeError
          ? error.code
          : "CENTRAL_AI_FAILED",
      },
    });
    throw userSafeCentralAiError(error);
  }
}

function userSafeCentralAiError(error: unknown) {
  if (error instanceof SafeError && !isProviderOrRawErrorCode(error.code)) {
    return error;
  }
  return new SafeError(
    "CENTRAL_AI_UNAVAILABLE",
    "Merkezi AI şu anda yanıt üretemedi. Harcanan MC varsa iade edilir.",
    502,
  );
}

function isProviderOrRawErrorCode(code: string) {
  const normalized = code.toUpperCase();
  return normalized.startsWith("OPENAI_") ||
    normalized.startsWith("ANTHROPIC_") ||
    normalized.includes("UPSTREAM") ||
    normalized.includes("PROVIDER") ||
    normalized.includes("AI_FAILED") ||
    normalized.includes("EMPTY_AI_OUTPUT");
}

/**
 * Job processor factory
 */
function createJobProcessor(): JobProcessor {
  return new JobProcessor(createAiConfig());
}

function createAiConfig() {
  const supabaseUrl = getSupabaseUrl();
  const serviceRoleKey = getSupabaseServiceRoleKey();
  if (!supabaseUrl || !serviceRoleKey) {
    throw new SafeError(
      "CONFIG_ERROR",
      "AI üretim yapılandırması eksik.",
      500,
    );
  }
  return { supabaseUrl, serviceRoleKey };
}

function normalizeJobType(jobType: string): GenerationType {
  const normalized = JOB_TYPE_ALIASES[jobType.trim()];
  if (!normalized) {
    throw new SafeError(
      "UNSUPPORTED_JOB_TYPE",
      "Bu üretim türü desteklenmiyor.",
      400,
    );
  }
  return normalized;
}

function requireUuid(value: unknown, name: string) {
  const text = requireString(value, name);
  if (!isUuid(text)) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return text;
}

function optionalUuid(value: unknown, name: string) {
  const text = value?.toString().trim() ?? "";
  if (!text) return undefined;
  if (!isUuid(text)) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return text;
}

function textOption(value: unknown) {
  const text = value?.toString().trim() ?? "";
  return text || undefined;
}

function numericOption(value: unknown) {
  if (value === undefined || value === null || value === "") return undefined;
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : undefined;
}

function booleanOption(value: unknown) {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value === "boolean") return value;
  const text = value.toString().trim().toLowerCase();
  if (text === "true" || text === "1" || text === "yes") return true;
  if (text === "false" || text === "0" || text === "no") return false;
  return undefined;
}

export function defaultMaxTokens(
  jobType: GenerationType,
  sourceTextLength: number,
  outputLengthPolicy?: string,
) {
  const policy = outputLengthPolicy?.toLowerCase() ?? "";
  if (jobType === "summary") {
    if (
      policy.includes("comprehensive") ||
      policy.includes("structured") ||
      policy.includes("not_short") ||
      sourceTextLength >= 16_000
    ) {
      return 4096;
    }
    if (policy.includes("detailed") || sourceTextLength >= 8_000) {
      return 3072;
    }
    return 4096;
  }
  if (
    jobType === "exam_morning_summary" || jobType === "clinical_scenario" ||
    jobType === "podcast" || jobType === "learning_plan" ||
    jobType === "algorithm"
  ) {
    return 4096;
  }
  if (jobType === "infographic" || jobType === "mind_map") {
    return 3072;
  }
  if (jobType === "quiz" || jobType === "flashcard") {
    return 3072;
  }
  return undefined;
}

function defaultSummaryMode(
  jobType: GenerationType,
  outputLengthPolicy?: string,
) {
  if (jobType !== "summary") return undefined;
  const policy = outputLengthPolicy?.toLowerCase() ?? "";
  return policy.includes("comprehensive")
    ? "medical_exam_comprehensive"
    : "medical_exam_high_yield";
}

function defaultLengthTarget(
  jobType: GenerationType,
  sourceTextLength: number,
  outputLengthPolicy?: string,
) {
  if (jobType !== "summary") return undefined;
  const policy = outputLengthPolicy?.toLowerCase() ?? "";
  if (policy.includes("comprehensive") || sourceTextLength >= 16_000) {
    return "700-950_words";
  }
  if (policy.includes("detailed") || sourceTextLength >= 8_000) {
    return "450-650_words";
  }
  return "280-420_words";
}

function defaultOutputFormat(
  jobType: GenerationType,
  outputLengthPolicy?: string,
) {
  if (jobType === "summary") {
    return "bullets+must_know+red_flags+flow+full_text";
  }
  if (jobType === "infographic") {
    return "structured_sections+visual_prompt+fallback_blocks";
  }
  return outputLengthPolicy?.toLowerCase().includes("structured")
    ? "structured"
    : undefined;
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

async function assertDriveFileOwned(userId: string, fileId: string) {
  const supabaseUrl = getSupabaseUrl();
  const serviceKey = getSupabaseServiceRoleKey();
  if (!supabaseUrl || !serviceKey) {
    throw new SafeError(
      "CONFIG_ERROR",
      "Sunucu yapılandırması eksik.",
      500,
    );
  }
  const response = await fetch(
    `${supabaseUrl}/rest/v1/drive_files?id=eq.${fileId}&owner_user_id=eq.${userId}&select=id,status,ai_status,size_bytes&limit=1`,
    {
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "accept-profile": "sourcebase",
      },
    },
  );
  if (!response.ok) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }
  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new SafeError("FILE_NOT_FOUND", "Dosya bulunamadı.", 404);
  }
  const row = rows[0];
  const status = String(row.status ?? "").toLowerCase();
  const aiStatus = String(row.ai_status ?? "").toLowerCase();
  const sizeBytes = Number(row.size_bytes ?? 0);
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0) {
    throw new SafeError(
      "FILE_OBJECT_EMPTY",
      "Yüklenen dosya boş görünüyor.",
      400,
    );
  }
  if (status === "draft" || aiStatus === "draft") {
    throw new SafeError(
      "FILE_NOT_READY",
      "Taslak kaynaklarla üretim başlatılamaz.",
      400,
    );
  }
  if (status === "failed" || aiStatus === "failed" || aiStatus === "error") {
    throw new SafeError(
      "FILE_NOT_READY",
      "Bu dosyada işleme hatası var.",
      400,
    );
  }
  if (aiStatus && aiStatus !== "ready" && aiStatus !== "completed") {
    throw new SafeError(
      "FILE_NOT_READY",
      "Bu dosya henüz işleniyor.",
      400,
    );
  }
  if (!aiStatus && status !== "ready" && status !== "completed") {
    throw new SafeError(
      "FILE_NOT_READY",
      "Bu dosya henüz işleniyor.",
      400,
    );
  }
}

function boundedNumber(
  value: unknown,
  fallback: number | undefined,
  min: number,
  max: number,
  name: string,
  integer = false,
) {
  if (value === undefined || value === null || value === "") return fallback;
  const numberValue = Number(value);
  if (
    !Number.isFinite(numberValue) || numberValue < min || numberValue > max ||
    (integer && !Number.isInteger(numberValue))
  ) {
    throw new SafeError("INVALID_PAYLOAD", `${name} geçersiz.`, 400);
  }
  return numberValue;
}

function validateLength(text: string, maxLength: number, name: string) {
  if (text.length > maxLength) {
    throw new SafeError("INVALID_PAYLOAD", `${name} çok uzun.`, 400);
  }
  return text;
}

async function assertJobCapacity(
  processor: JobProcessor,
  userId: string,
  fileId: string | undefined,
  jobType: GenerationType,
) {
  const jobs = await processor.listUserJobs(userId, 50);
  await failStaleActiveJobs(processor, jobs);
  const activeJobs = jobs.filter((job) =>
    (job.status === "queued" || job.status === "processing") &&
    !isStaleActiveJob(job)
  );
  if (activeJobs.length >= MAX_ACTIVE_USER_JOBS) {
    throw new SafeError(
      "TOO_MANY_ACTIVE_JOBS",
      "Devam eden çok fazla AI işi var.",
      429,
    );
  }
  if (
    fileId &&
    activeJobs.some((job) =>
      job.source_file_id === fileId && job.job_type === jobType
    )
  ) {
    throw new SafeError(
      "JOB_ALREADY_RUNNING",
      "Bu dosya için aynı türde bir üretim işi zaten devam ediyor.",
      409,
    );
  }
}

async function failStaleActiveJobs(
  processor: JobProcessor,
  jobs: GenerationJob[],
) {
  for (const job of jobs.filter(isStaleActiveJob)) {
    await processor.failJobBeforeProcessing(
      job,
      job.job_type,
      staleActiveJobError(job),
    );
  }
}

function isStaleActiveJob(job: GenerationJob) {
  if (job.status !== "queued" && job.status !== "processing") {
    return false;
  }
  const reference = Date.parse(job.updated_at || job.created_at || "");
  if (!Number.isFinite(reference)) return false;
  return Date.now() - reference > STALE_ACTIVE_JOB_MS;
}

function staleActiveJobError(job: GenerationJob) {
  return new SafeError(
    job.status === "processing" ? "JOB_STALE_PROCESSING" : "JOB_STALE_QUEUED",
    "AI işi zaman aşımına uğradı. Lütfen yeniden deneyin.",
    408,
  );
}

async function buildOwnedFileContext(
  userId: string,
  payload: Record<string, unknown>,
) {
  const rawIds = Array.isArray(payload.fileIds)
    ? payload.fileIds
    : Array.isArray(payload.contextFileIds)
    ? payload.contextFileIds
    : [];
  const parsedIds = rawIds
    .map((item) => item?.toString().trim() ?? "")
    .filter((item) => item.length > 0);
  for (const fileId of parsedIds) {
    if (!isUuid(fileId)) {
      throw new SafeError("INVALID_PAYLOAD", "fileIds geçersiz.", 400);
    }
  }
  const fileIds = Array.from(new Set(parsedIds)).slice(0, MAX_CONTEXT_FILES);
  if (fileIds.length === 0) return "";

  const chunks: string[] = [];
  for (const fileId of fileIds) {
    const result = await extractTextFromDriveFile(userId, fileId);
    if (result.text.trim()) {
      chunks.push(result.text);
    }
  }
  return sanitizeSourceText(chunks.join("\n\n")).slice(
    0,
    MAX_CHAT_CONTEXT_CHARS,
  );
}

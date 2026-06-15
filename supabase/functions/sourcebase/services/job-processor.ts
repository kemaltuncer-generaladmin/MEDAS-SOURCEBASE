/**
 * SourceBase Job Processing Service
 *
 * AI generation job'larını yönetir ve işler.
 * AGENTS.md Kural 9.4: Job status tracking
 */

import {
  GenerationJob,
  GenerationType,
  isRecord,
  JobStatus,
  SafeError,
} from "../types.ts";
import { logAiPipeline } from "./ai-logger.ts";
import { storeGeneratedImageFromDataUrl } from "./generated-image-storage.ts";
import { storeGeneratedAudioFromDataUrl } from "./generated-audio-storage.ts";
import {
  buildInfographicImagePrompt,
  generateInfographicImage,
} from "./image-provider.ts";
import { generatePodcastAudio } from "./audio-provider.ts";
import { captureMedasiCoin, refundMedasiCoin } from "./medasicoin-wallet.ts";
import type { McPricingQuote } from "./medasicoin-pricing.ts";
import {
  normalizeQualityTier,
  routeOptionsForQuality,
} from "./medasicoin-pricing.ts";
import {
  resolveTextRoute,
  RouteOptions,
  shouldGenerateInfographicImage,
  shouldGeneratePodcastAudio,
  TextRoute,
} from "./model-router.ts";
import {
  AITextClient,
  GenerationOptions,
  GenerationResult,
} from "./ai-generation-provider.ts";

export interface JobUpdate {
  status?: JobStatus;
  model?: string;
  input_tokens?: number;
  output_tokens?: number;
  cost_estimate?: number;
  error_message?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Job oluştur
 */
export async function createJob(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  jobData: {
    source_file_id?: string;
    source_id?: string;
    deck_id?: string;
    job_type: string;
    model?: string;
    metadata?: Record<string, unknown>;
  },
): Promise<GenerationJob> {
  const response = await fetch(`${supabaseUrl}/rest/v1/generated_jobs`, {
    method: "POST",
    headers: {
      "apikey": serviceRoleKey,
      "authorization": `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
      "accept-profile": "sourcebase",
      "content-profile": "sourcebase",
      "prefer": "return=representation",
    },
    body: JSON.stringify({
      owner_user_id: userId,
      source_file_id: jobData.source_file_id,
      source_id: jobData.source_id,
      deck_id: jobData.deck_id,
      job_type: jobData.job_type,
      status: "queued",
      model: jobData.model,
      metadata: jobData.metadata || {},
    }),
  });

  if (!response.ok) {
    throw new SafeError("JOB_CREATE_FAILED", "İş oluşturulamadı.", 500);
  }

  const jobs = await response.json();
  if (!Array.isArray(jobs) || jobs.length === 0) {
    throw new SafeError("JOB_CREATE_FAILED", "İş oluşturulamadı.", 500);
  }

  return jobs[0] as GenerationJob;
}

/**
 * Job durumunu güncelle
 */
export async function updateJob(
  supabaseUrl: string,
  serviceRoleKey: string,
  jobId: string,
  updates: JobUpdate,
): Promise<void> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/generated_jobs?id=eq.${jobId}`,
    {
      method: "PATCH",
      headers: {
        "apikey": serviceRoleKey,
        "authorization": `Bearer ${serviceRoleKey}`,
        "content-type": "application/json",
        "accept-profile": "sourcebase",
        "content-profile": "sourcebase",
      },
      body: JSON.stringify({
        ...updates,
        updated_at: new Date().toISOString(),
      }),
    },
  );

  if (!response.ok) {
    console.error("Job update failed:", response.status);
  }
}

/**
 * Job'ı getir
 */
export async function getJob(
  supabaseUrl: string,
  serviceRoleKey: string,
  jobId: string,
  userId: string,
): Promise<GenerationJob | null> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/generated_jobs?id=eq.${jobId}&owner_user_id=eq.${userId}&select=*`,
    {
      method: "GET",
      headers: {
        "apikey": serviceRoleKey,
        "authorization": `Bearer ${serviceRoleKey}`,
        "accept-profile": "sourcebase",
        "content-profile": "sourcebase",
      },
    },
  );

  if (!response.ok) {
    return null;
  }

  const jobs = await response.json();
  if (!Array.isArray(jobs) || jobs.length === 0) {
    return null;
  }

  return jobs[0] as GenerationJob;
}

/**
 * Kullanıcının job'larını listele
 */
export async function listJobs(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  limit = 50,
): Promise<GenerationJob[]> {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/generated_jobs?owner_user_id=eq.${userId}&select=*&order=created_at.desc&limit=${limit}`,
    {
      method: "GET",
      headers: {
        "apikey": serviceRoleKey,
        "authorization": `Bearer ${serviceRoleKey}`,
        "accept-profile": "sourcebase",
        "content-profile": "sourcebase",
      },
    },
  );

  if (!response.ok) {
    return [];
  }

  const jobs = await response.json();
  return Array.isArray(jobs) ? jobs : [];
}

/**
 * Job'ı iptal et
 */
export async function cancelJob(
  supabaseUrl: string,
  serviceRoleKey: string,
  jobId: string,
  userId: string,
): Promise<boolean> {
  const job = await getJob(supabaseUrl, serviceRoleKey, jobId, userId);
  if (!job) {
    return false;
  }

  if (job.status === "completed" || job.status === "cancelled") {
    return false;
  }

  await updateJob(supabaseUrl, serviceRoleKey, jobId, {
    status: "cancelled",
  });

  return true;
}

export interface JobProcessorConfig {
  supabaseUrl: string;
  serviceRoleKey: string;
}

export type JobGenerationOptions = {
  count?: number;
  temperature?: number;
  maxTokens?: number;
  sourceTextLength?: number;
  sourceIds?: string[];
  routeOptions?: RouteOptions;
  pricing?: McPricingQuote;
  summaryMode?: string;
  lengthTarget?: string;
  outputFormat?: string;
  cardStyle?: string;
  extractKeyConcepts?: boolean;
  addHints?: boolean;
  questionType?: string;
  explanations?: boolean;
  algorithmType?: string;
  comparisonType?: string;
  tableFormat?: string;
  detailLevel?: string;
  infographicType?: string;
  visualStyle?: string;
  density?: string;
  mapType?: string;
  depth?: string;
  viewMode?: string;
  scenarioType?: string;
  difficulty?: string;
  planGoal?: string;
  dailyTime?: string;
  studyStyle?: string;
  qualityTier?: string;
  modelPolicy?: string;
  minimumDepth?: string;
  outputLengthPolicy?: string;
  imageModelPolicy?: string;
  aiBrief?: string;
  outputContract?: string;
  studentContext?: string;
};

type RoutedGenerationResult<T> = GenerationResult<T> & {
  modelRoute: ReturnType<typeof safeRouteMetadata>;
};

type GeneratedOutputRow = Record<string, unknown>;

export class JobProcessor {
  private ai: AITextClient;

  constructor(private config: JobProcessorConfig) {
    this.ai = new AITextClient();
  }

  async createJob(input: {
    userId: string;
    sourceFileId?: string;
    jobType: GenerationType;
    sourceText: string;
    options?: JobGenerationOptions;
  }): Promise<GenerationJob> {
    const job = await this.createQueuedJob(input);
    return await this.processJob(job, input);
  }

  async createQueuedJob(input: {
    userId: string;
    sourceFileId?: string;
    jobType: GenerationType;
    sourceText: string;
    options?: JobGenerationOptions;
  }): Promise<GenerationJob> {
    const sourceTextLength = input.options?.sourceTextLength ??
      input.sourceText.length;
    const route = resolveTextRoute(
      input.jobType,
      input.options?.routeOptions,
      sourceTextLength,
    );
    const job = await createJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      input.userId,
      {
        source_file_id: input.sourceFileId,
        job_type: input.jobType,
        model: route.model,
        metadata: {
          sourceTextLength,
          modelRoute: safeRouteMetadata(route),
          pricing: input.options?.pricing,
          sourceText: input.sourceFileId ? undefined : input.sourceText,
          generationOptions: {
            count: input.options?.count,
            temperature: input.options?.temperature,
            maxTokens: input.options?.maxTokens,
            sourceTextLength,
            sourceIds: input.options?.sourceIds,
            sourceCount: input.options?.sourceIds?.length,
            routeOptions: input.options?.routeOptions,
            summaryMode: input.options?.summaryMode,
            lengthTarget: input.options?.lengthTarget,
            outputFormat: input.options?.outputFormat,
            cardStyle: input.options?.cardStyle,
            extractKeyConcepts: input.options?.extractKeyConcepts,
            addHints: input.options?.addHints,
            questionType: input.options?.questionType,
            explanations: input.options?.explanations,
            algorithmType: input.options?.algorithmType,
            comparisonType: input.options?.comparisonType,
            tableFormat: input.options?.tableFormat,
            detailLevel: input.options?.detailLevel,
            infographicType: input.options?.infographicType,
            visualStyle: input.options?.visualStyle,
            density: input.options?.density,
            mapType: input.options?.mapType,
            depth: input.options?.depth,
            viewMode: input.options?.viewMode,
            scenarioType: input.options?.scenarioType,
            difficulty: input.options?.difficulty,
            planGoal: input.options?.planGoal,
            dailyTime: input.options?.dailyTime,
            studyStyle: input.options?.studyStyle,
            qualityTier: input.options?.qualityTier,
            modelPolicy: input.options?.modelPolicy,
            minimumDepth: input.options?.minimumDepth,
            outputLengthPolicy: input.options?.outputLengthPolicy,
            imageModelPolicy: input.options?.imageModelPolicy,
            aiBrief: input.options?.aiBrief,
            outputContract: input.options?.outputContract,
          },
        },
      },
    );

    return job;
  }

  async processJob(
    job: GenerationJob,
    input: {
      jobType: GenerationType;
      sourceText: string;
      options?: JobGenerationOptions;
    },
  ): Promise<GenerationJob> {
    await updateJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      job.id,
      {
        status: "processing",
      },
    );
    const route = resolveTextRoute(
      input.jobType,
      input.options?.routeOptions,
      input.sourceText.length,
    );
    logAiPipeline({
      action: "process_generation_job",
      status: "processing",
      jobId: job.id,
      jobType: input.jobType,
      provider: route.provider,
      model: route.model,
    });

    try {
      logAiPipeline({
        action: "process_generation_job",
        status: "provider_start",
        jobId: job.id,
        jobType: input.jobType,
        provider: route.provider,
        model: route.model,
      });
      const result = await this.generate(
        input.jobType,
        input.sourceText,
        input.options ?? {},
      );
      logAiPipeline({
        action: "process_generation_job",
        status: "provider_done",
        jobId: job.id,
        jobType: input.jobType,
        provider: result.modelRoute.provider,
        model: result.modelRoute.model,
      });
      const storedContent = input.jobType === "infographic"
        ? await this.attachInfographicStorage(job, result.content)
        : input.jobType === "podcast"
        ? await this.attachPodcastStorage(job, result.content)
        : result.content;
      // Drop the heavy base64 data URLs once the asset lives in object storage;
      // clients receive freshly signed read URLs at fetch time.
      const content = contentForGeneratedOutput(storedContent);
      const completedAt = new Date().toISOString();
      const completedMetadata = {
        ...job.metadata,
        content,
        modelRoute: result.modelRoute,
        completedAt,
      };
      await persistGeneratedOutput(this.config, {
        job,
        jobType: input.jobType,
        content,
        modelRoute: result.modelRoute,
        completedAt,
      });
      logAiPipeline({
        action: "process_generation_job",
        status: "output_saved",
        jobId: job.id,
        jobType: input.jobType,
        provider: result.modelRoute.provider,
        model: result.modelRoute.model,
      });
      await updateJob(
        this.config.supabaseUrl,
        this.config.serviceRoleKey,
        job.id,
        {
          status: "completed",
          input_tokens: result.inputTokens,
          output_tokens: result.outputTokens,
          cost_estimate: result.costEstimate,
          model: result.modelRoute.model,
          metadata: completedMetadata,
        },
      );
      logAiPipeline({
        action: "process_generation_job",
        status: "completed",
        jobId: job.id,
        jobType: input.jobType,
        provider: result.modelRoute.provider,
        model: result.modelRoute.model,
      });
      try {
        await captureMedasiCoin({
          config: this.config,
          userId: job.owner_user_id,
          jobId: job.id,
          reason: `ai_generation_capture:${input.jobType}`,
          metadata: { modelRoute: result.modelRoute },
        });
      } catch (captureError) {
        const captureErrorCode = captureError instanceof SafeError
          ? captureError.code
          : "WALLET_CAPTURE_FAILED";
        console.warn("MC capture bookkeeping failed:", captureErrorCode);
      }
      return {
        ...job,
        status: "completed",
        input_tokens: result.inputTokens,
        output_tokens: result.outputTokens,
        cost_estimate: result.costEstimate,
        model: result.modelRoute.model,
        metadata: completedMetadata,
      };
    } catch (error) {
      const errorCode = error instanceof SafeError ? error.code : "AI_FAILED";
      logAiPipeline({
        action: "process_generation_job",
        status: "failed",
        jobId: job.id,
        jobType: input.jobType,
        provider: route.provider,
        model: route.model,
        errorCode,
      });
      const pricing = isPricingQuote(job.metadata?.pricing)
        ? job.metadata.pricing
        : undefined;
      await refundMedasiCoin({
        config: this.config,
        userId: job.owner_user_id,
        jobId: job.id,
        amountUnits: pricing?.amount_units ?? 0,
        reason: `ai_generation_refund:${input.jobType}`,
        metadata: {
          errorCode,
        },
      });
      await updateJob(
        this.config.supabaseUrl,
        this.config.serviceRoleKey,
        job.id,
        {
          status: "failed",
          error_message: userMessageForGenerationFailure(error),
          metadata: {
            ...job.metadata,
            errorCode,
            failedAt: new Date().toISOString(),
          },
        },
      );
      throw error;
    }
  }

  async getJobStatus(userId: string, jobId: string): Promise<GenerationJob> {
    const job = await getJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      jobId,
      userId,
    );
    if (!job) {
      throw new SafeError("JOB_NOT_FOUND", "İş bulunamadı.", 404);
    }
    return job;
  }

  listUserJobs(userId: string, limit = 50): Promise<GenerationJob[]> {
    return listJobs(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      userId,
      limit,
    );
  }

  async cancelJob(userId: string, jobId: string): Promise<void> {
    const ok = await cancelJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      jobId,
      userId,
    );
    if (!ok) {
      throw new SafeError("JOB_NOT_CANCELLED", "İş iptal edilemedi.", 400);
    }
  }

  async failJobBeforeProcessing(
    job: GenerationJob,
    jobType: GenerationType,
    error: unknown,
  ): Promise<void> {
    const errorCode = error instanceof SafeError ? error.code : "AI_FAILED";
    logAiPipeline({
      action: "process_generation_job",
      status: "failed",
      jobId: job.id,
      jobType,
      errorCode,
    });
    const pricing = isPricingQuote(job.metadata?.pricing)
      ? job.metadata.pricing
      : undefined;
    await refundMedasiCoin({
      config: this.config,
      userId: job.owner_user_id,
      jobId: job.id,
      amountUnits: pricing?.amount_units ?? 0,
      reason: `ai_generation_refund:${jobType}`,
      metadata: { errorCode },
    });
    await updateJob(
      this.config.supabaseUrl,
      this.config.serviceRoleKey,
      job.id,
      {
        status: "failed",
        error_message: userMessageForGenerationFailure(error),
        metadata: {
          ...job.metadata,
          errorCode,
          failedAt: new Date().toISOString(),
        },
      },
    );
  }

  async retryJob(userId: string, jobId: string): Promise<GenerationJob> {
    const oldJob = await this.getJobStatus(userId, jobId);
    const metadata = oldJob.metadata ?? {};
    const sourceText = metadata.sourceText?.toString() ??
      metadata.sourceTextPreview?.toString() ??
      "";
    if (!sourceText.trim()) {
      throw new SafeError(
        "SOURCE_TEXT_REQUIRED",
        "Yeniden deneme için kaynak metin bulunamadı.",
        400,
      );
    }
    return this.createJob({
      userId,
      sourceFileId: oldJob.source_file_id,
      jobType: oldJob.job_type,
      sourceText,
    });
  }

  private generate(
    jobType: GenerationType,
    sourceText: string,
    options: JobGenerationOptions,
  ) {
    // qualityTier is authoritative: route the actual generation with the same
    // tier-adjusted options the price was quoted from, so the reserved MC and
    // the model that runs always match.
    const routeOptions = routeOptionsForQuality(
      normalizeQualityTier(options.qualityTier),
      options.routeOptions ?? {},
    );
    const route = resolveTextRoute(
      jobType,
      routeOptions,
      sourceText.length,
    );
    const routedOptions: GenerationOptions = {
      temperature: options.temperature,
      maxTokens: options.maxTokens,
      provider: route.provider,
      model: route.model,
      summaryMode: options.summaryMode,
      lengthTarget: options.lengthTarget,
      outputFormat: options.outputFormat,
      cardStyle: options.cardStyle,
      extractKeyConcepts: options.extractKeyConcepts,
      addHints: options.addHints,
      questionType: options.questionType,
      explanations: options.explanations,
      algorithmType: options.algorithmType,
      comparisonType: options.comparisonType,
      tableFormat: options.tableFormat,
      detailLevel: options.detailLevel,
      infographicType: options.infographicType,
      visualStyle: options.visualStyle,
      density: options.density,
      scenarioType: options.scenarioType,
      difficulty: options.difficulty,
      planGoal: options.planGoal,
      dailyTime: options.dailyTime,
      studyStyle: options.studyStyle,
      qualityTier: options.qualityTier,
      modelPolicy: options.modelPolicy,
      minimumDepth: options.minimumDepth,
      outputLengthPolicy: options.outputLengthPolicy,
      imageModelPolicy: options.imageModelPolicy,
      aiBrief: options.aiBrief,
      outputContract: options.outputContract,
      studentContext: options.studentContext,
    };
    switch (jobType) {
      case "flashcard":
        return this.withRoute(
          route,
          this.ai.generateFlashcards(
            sourceText,
            options.count ?? 20,
            routedOptions,
          ),
        );
      case "quiz":
        return this.withRoute(
          route,
          this.ai.generateQuiz(
            sourceText,
            options.count ?? 10,
            routedOptions,
          ),
        );
      case "summary":
        return this.withRoute(
          route,
          this.ai.generateSummary(sourceText, routedOptions),
        );
      case "exam_morning_summary":
        return this.withRoute(
          route,
          this.ai.generateExamMorningSummary(sourceText, routedOptions),
        );
      case "algorithm":
        return this.withRoute(
          route,
          this.ai.generateAlgorithm(sourceText, routedOptions),
        );
      case "comparison":
        return this.withRoute(
          route,
          this.ai.generateComparison(sourceText, routedOptions),
        );
      case "podcast":
        return this.generatePodcastWithAudio(
          sourceText,
          { ...routedOptions, routeOptions },
          route,
        );
      case "clinical_scenario":
        return this.withRoute(
          route,
          this.ai.generateClinicalScenario(sourceText, routedOptions),
        );
      case "learning_plan":
        return this.withRoute(
          route,
          this.ai.generateLearningPlan(sourceText, routedOptions),
        );
      case "infographic":
        return this.generateInfographicWithImage(
          sourceText,
          { ...routedOptions, routeOptions },
          route,
        );
      case "mind_map":
        return this.withRoute(
          route,
          this.ai.generateMindMap(sourceText, routedOptions),
        );
    }
  }

  private async generateInfographicWithImage(
    sourceText: string,
    options: GenerationOptions & { routeOptions?: RouteOptions },
    route: TextRoute,
  ): Promise<RoutedGenerationResult<unknown>> {
    const specResult = await this.ai.generateInfographic(
      sourceText,
      options,
    );
    if (!shouldGenerateInfographicImage(options.routeOptions)) {
      return {
        ...specResult,
        content: {
          ...specResult.content,
          image: {
            status: "deferred",
            prompt: buildInfographicImagePrompt(specResult.content),
          },
        },
        modelRoute: safeRouteMetadata(route),
      };
    }

    let image;
    try {
      image = await generateInfographicImage(
        specResult.content,
        options.routeOptions,
      );
    } catch (error) {
      console.error("Infographic image generation failed:", error);
      return {
        ...specResult,
        content: {
          ...specResult.content,
          image: {
            status: "failed",
            prompt: buildInfographicImagePrompt(specResult.content),
            fallback: "structured_text_blocks",
          },
        },
        modelRoute: safeRouteMetadata(route),
      };
    }

    return {
      ...specResult,
      content: {
        ...specResult.content,
        image: {
          provider: image.provider,
          model: image.model,
          mimeType: image.mimeType,
          dataUrl: image.dataUrl,
          url: image.url,
          prompt: image.prompt,
        },
      },
      modelRoute: safeRouteMetadata(route),
    };
  }

  private async generatePodcastWithAudio(
    sourceText: string,
    options: GenerationOptions & { routeOptions?: RouteOptions },
    route: TextRoute,
  ): Promise<RoutedGenerationResult<unknown>> {
    const scriptResult = await this.ai.generatePodcast(sourceText, options);
    if (!shouldGeneratePodcastAudio(options.routeOptions)) {
      return {
        ...scriptResult,
        content: {
          ...scriptResult.content,
          audio: { status: "deferred" },
        },
        modelRoute: safeRouteMetadata(route),
      };
    }

    let audio;
    try {
      audio = await generatePodcastAudio(
        scriptResult.content,
        options.routeOptions,
      );
    } catch (error) {
      const code = error instanceof SafeError ? error.code : "AUDIO_FAILED";
      console.error("Podcast audio generation failed:", code);
      return {
        ...scriptResult,
        content: {
          ...scriptResult.content,
          audio: { status: "failed", fallback: "transcript_only" },
        },
        modelRoute: safeRouteMetadata(route),
      };
    }

    return {
      ...scriptResult,
      content: {
        ...scriptResult.content,
        audio: {
          status: "ready",
          provider: audio.provider,
          model: audio.model,
          mimeType: audio.mimeType,
          dataUrl: audio.dataUrl,
          voices: audio.voices,
          characterCount: audio.characterCount,
          segmentCount: audio.segmentCount,
          truncated: audio.truncated,
        },
      },
      modelRoute: safeRouteMetadata(route),
    };
  }

  private async attachPodcastStorage(
    job: GenerationJob,
    content: unknown,
  ): Promise<unknown> {
    if (!isRecord(content)) return content;
    const audio = isRecord(content.audio) ? content.audio : null;
    const dataUrl = audio?.dataUrl?.toString();
    if (!audio || !dataUrl) return content;
    const stored = await storeGeneratedAudioFromDataUrl({
      userId: job.owner_user_id,
      jobId: job.id,
      dataUrl,
    });
    if (!stored) return content;
    return {
      ...content,
      audio: {
        ...audio,
        storageUrl: stored.storageUrl,
        storageBucket: stored.bucket,
        storageObjectName: stored.objectName,
      },
    };
  }

  private async attachInfographicStorage(
    job: GenerationJob,
    content: unknown,
  ): Promise<unknown> {
    if (!isRecord(content)) return content;
    const image = isRecord(content.image) ? content.image : {};
    const dataUrl = image.dataUrl?.toString();
    const stored = await storeGeneratedImageFromDataUrl({
      userId: job.owner_user_id,
      jobId: job.id,
      dataUrl,
    });
    if (!stored) return content;
    return {
      ...content,
      image: {
        ...image,
        storageUrl: stored.storageUrl,
        storageBucket: stored.bucket,
        storageObjectName: stored.objectName,
      },
    };
  }

  private async withRoute<T>(
    route: TextRoute,
    result: Promise<GenerationResult<T>>,
  ): Promise<RoutedGenerationResult<T>> {
    return {
      ...await result,
      modelRoute: safeRouteMetadata(route),
    };
  }
}

function safeRouteMetadata(route: TextRoute) {
  return {
    provider: route.provider,
    model: route.model,
    tier: route.tier,
    reason: route.reason,
    fallbackUsed: route.fallbackUsed,
    sourceSizeTier: route.sourceSizeTier,
    signals: route.signals,
  };
}

function userMessageForGenerationFailure(error: unknown) {
  if (error instanceof SafeError && !isProviderOrRawErrorCode(error.code)) {
    return error.message || "AI üretimi tamamlanamadı.";
  }
  return "AI üretimi şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.";
}

function isProviderOrRawErrorCode(code: string) {
  const normalized = code.toUpperCase();
  return normalized.startsWith("OPENAI_") ||
    normalized.startsWith("ANTHROPIC_") ||
    normalized.startsWith("IMAGE_") ||
    normalized.includes("UPSTREAM") ||
    normalized.includes("PROVIDER") ||
    normalized.includes("AI_FAILED") ||
    normalized.includes("EMPTY_AI_OUTPUT");
}

async function persistGeneratedOutput(
  config: Pick<JobProcessorConfig, "supabaseUrl" | "serviceRoleKey">,
  input: {
    job: GenerationJob;
    jobType: GenerationType;
    content: unknown;
    modelRoute: ReturnType<typeof safeRouteMetadata>;
    completedAt: string;
  },
): Promise<GeneratedOutputRow | null> {
  const fileId = input.job.source_file_id?.trim();
  if (!fileId) {
    throw new SafeError(
      "SOURCE_FILE_REQUIRED_FOR_OUTPUT",
      "Üretilen içerik kaydı için kaynak dosya gerekli.",
      400,
    );
  }
  if (isEmptyGeneratedContent(input.content)) {
    throw new SafeError(
      "GENERATED_CONTENT_EMPTY",
      "AI üretim sonucu boş olduğu için kaydedilemedi.",
      500,
    );
  }

  const outputType = outputTypeForJob(input.jobType);
  const existing = await findGeneratedOutputForJob(
    config,
    input.job.owner_user_id,
    fileId,
    outputType,
    input.job.id,
  );
  if (existing) return existing;

  const content = contentForGeneratedOutput(input.content);
  const inserted = await sourcebaseRestJson(config, "generated_outputs", {
    method: "POST",
    headers: { "prefer": "return=representation" },
    body: JSON.stringify([{
      owner_user_id: input.job.owner_user_id,
      source_file_id: fileId,
      output_type: outputType,
      title: generatedOutputTitle(outputType),
      item_count: countGeneratedItems(content) ?? defaultGeneratedCount(
        outputType,
      ),
      status: "ready",
      metadata: {
        mode: "ai_generation",
        jobId: input.job.id,
        jobType: input.jobType,
        content,
        modelRoute: input.modelRoute,
        completedAt: input.completedAt,
      },
    }]),
  });

  if (Array.isArray(inserted) && isRecord(inserted[0])) {
    return inserted[0];
  }
  throw new SafeError(
    "GENERATED_OUTPUT_SAVE_FAILED",
    "Üretilen içerik kaydedilemedi.",
    500,
  );
}

async function findGeneratedOutputForJob(
  config: Pick<JobProcessorConfig, "supabaseUrl" | "serviceRoleKey">,
  userId: string,
  fileId: string,
  outputType: string,
  jobId: string,
): Promise<GeneratedOutputRow | null> {
  const query = [
    `owner_user_id=eq.${encodeURIComponent(userId)}`,
    `source_file_id=eq.${encodeURIComponent(fileId)}`,
    `output_type=eq.${encodeURIComponent(outputType)}`,
    "select=*",
    "order=created_at.desc",
    "limit=50",
  ].join("&");
  const path = `generated_outputs?${query}`;
  const rows = await sourcebaseRestJson(config, path, { method: "GET" });
  if (!Array.isArray(rows)) return null;
  for (const row of rows) {
    if (!isRecord(row)) continue;
    const metadata = isRecord(row.metadata) ? row.metadata : {};
    if (metadata.jobId?.toString() === jobId) return row;
  }
  return null;
}

async function sourcebaseRestJson(
  config: Pick<JobProcessorConfig, "supabaseUrl" | "serviceRoleKey">,
  path: string,
  init: RequestInit,
): Promise<unknown> {
  const response = await fetch(`${config.supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      "apikey": config.serviceRoleKey,
      "authorization": `Bearer ${config.serviceRoleKey}`,
      "content-type": "application/json",
      "accept-profile": "sourcebase",
      "content-profile": "sourcebase",
      ...((init.headers as Record<string, string> | undefined) ?? {}),
    },
  });
  if (!response.ok) {
    throw new SafeError(
      "GENERATED_OUTPUT_SAVE_FAILED",
      "Üretilen içerik kaydedilemedi.",
      500,
    );
  }
  if (response.status === 204) return null;
  return await response.json();
}

function outputTypeForJob(jobType: GenerationType) {
  const mapping: Record<GenerationType, string> = {
    flashcard: "flashcard",
    quiz: "question",
    summary: "summary",
    exam_morning_summary: "exam_morning_summary",
    algorithm: "algorithm",
    comparison: "comparison",
    podcast: "podcast_summary",
    clinical_scenario: "clinical_scenario",
    learning_plan: "learning_plan",
    infographic: "infographic",
    mind_map: "mind_map",
  };
  return mapping[jobType];
}

function generatedOutputTitle(outputType: string) {
  const titles: Record<string, string> = {
    flashcard: "Flashcard Seti",
    question: "Soru Seti",
    summary: "Özet",
    exam_morning_summary: "Sınav Sabahı Özeti",
    algorithm: "Algoritma",
    comparison: "Karşılaştırma",
    clinical_scenario: "Klinik Senaryo",
    learning_plan: "Öğrenme Planı",
    podcast: "Podcast Özeti",
    podcast_summary: "Podcast Özeti",
    infographic: "İnfografik",
    table: "Tablo",
    mindMap: "Zihin Haritası",
    mind_map: "Zihin Haritası",
  };
  return titles[outputType] ?? "Üretilen İçerik";
}

function defaultGeneratedCount(outputType: string) {
  const counts: Record<string, number> = {
    flashcard: 20,
    question: 10,
    summary: 1,
    exam_morning_summary: 1,
    algorithm: 1,
    comparison: 1,
    clinical_scenario: 1,
    learning_plan: 1,
    podcast: 1,
    podcast_summary: 1,
    infographic: 1,
    table: 1,
    mindMap: 1,
    mind_map: 1,
  };
  return counts[outputType] ?? 1;
}

function isEmptyGeneratedContent(content: unknown) {
  if (Array.isArray(content)) return content.length === 0;
  if (isRecord(content)) return Object.keys(content).length === 0;
  if (typeof content === "string") return content.trim().length === 0;
  return content === null || content === undefined;
}

function countGeneratedItems(content: unknown): number | undefined {
  if (Array.isArray(content)) return content.length || undefined;
  if (!isRecord(content)) return undefined;
  for (
    const key of [
      "cards",
      "flashcards",
      "questions",
      "bulletPoints",
      "must_know",
      "commonly_confused",
      "clinical_tus_tips",
      "self_check",
      "steps",
      "rows",
      "segments",
      "chapters",
      "days",
      "nodes",
      "branches",
      "sections",
      "teachingPoints",
      "objectives",
      "sessions",
    ]
  ) {
    const value = content[key];
    if (Array.isArray(value) && value.length > 0) return value.length;
  }
  return 1;
}

function contentForGeneratedOutput(content: unknown): unknown {
  if (!isRecord(content)) return content;
  let next = content;
  const image = isRecord(next.image) ? next.image : null;
  if (image && image.storageUrl) {
    const { dataUrl: _imageDataUrl, ...safeImage } = image;
    next = { ...next, image: safeImage };
  }
  const audio = isRecord(next.audio) ? next.audio : null;
  if (audio && audio.dataUrl) {
    const { dataUrl: _audioDataUrl, ...safeAudio } = audio;
    next = { ...next, audio: safeAudio };
  }
  return next;
}

function isPricingQuote(value: unknown): value is McPricingQuote {
  return typeof value === "object" && value !== null &&
    typeof (value as { amount_units?: unknown }).amount_units === "number";
}

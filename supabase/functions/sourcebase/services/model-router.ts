import { GenerationType } from "../types.ts";

export type TextProvider = "openai" | "anthropic";
export type ImageProviderName = "openai" | "stability";
export type TextTier = "cheap" | "standard" | "reasoning" | "reviewer";
export type SourceSizeTier = "tiny" | "short" | "medium" | "large" | "huge";

export interface TextRoute {
  provider: TextProvider;
  model: string;
  tier: TextTier;
  reason: string;
  fallbackUsed: boolean;
  sourceSizeTier: SourceSizeTier;
  signals: string[];
}

export interface ImageRoute {
  provider: ImageProviderName;
  model: string;
  fallbackProvider: ImageProviderName;
  fallbackModel: string;
  quality: "draft" | "standard" | "premium";
}

export interface RouteOptions {
  premium?: boolean;
  clinical?: boolean;
  hard?: boolean;
  cheap?: boolean;
  short?: boolean;
  structured?: boolean;
  personalized?: boolean;
  naturalNarration?: boolean;
  complex?: boolean;
  reviewer?: boolean;
  longContext?: boolean;
  textModel?: string;
  imageQuality?: "draft" | "standard" | "premium" | "low";
  imageModel?: string;
  imageRequired?: boolean;
  audioRequired?: boolean;
  sourceCount?: number;
}

export interface PodcastAudioRoute {
  provider: "openai";
  model: string;
  hostVoice: string;
  expertVoice: string;
  narratorVoice: string;
  format: "mp3";
}

type RouteJobType = GenerationType | "central_ai_chat" | "infographic_spec";

interface ModelSet {
  cheap: string;
  standard: string;
  centralAi: string;
  reasoning: string;
  reviewer: string;
}

interface RouteProfile {
  defaultTier: TextTier;
  premiumTier: TextTier;
  complexTier: TextTier;
  cheapAllowed: boolean;
  reviewerOnPremium?: boolean;
  reviewerOnHuge?: boolean;
}

const DEFAULT_TEXT_PROVIDER: TextProvider = "openai";
const HUGE_SOURCE_CHARS = 160_000;
const LARGE_SOURCE_CHARS = 80_000;
const MEDIUM_SOURCE_CHARS = 15_000;
const SHORT_SOURCE_CHARS = 1_500;

const ROUTE_PROFILES: Record<RouteJobType, RouteProfile> = {
  flashcard: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: true,
  },
  quiz: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: false,
  },
  summary: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: true,
  },
  exam_morning_summary: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: false,
  },
  algorithm: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: false,
  },
  comparison: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: false,
    reviewerOnHuge: true,
  },
  clinical_scenario: {
    defaultTier: "reasoning",
    premiumTier: "reviewer",
    complexTier: "reviewer",
    cheapAllowed: false,
    reviewerOnPremium: true,
    reviewerOnHuge: true,
  },
  learning_plan: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: false,
  },
  podcast: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: false,
  },
  infographic: {
    defaultTier: "reasoning",
    premiumTier: "reviewer",
    complexTier: "reviewer",
    cheapAllowed: false,
    reviewerOnPremium: true,
    reviewerOnHuge: true,
  },
  mind_map: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: false,
  },
  central_ai_chat: {
    defaultTier: "standard",
    premiumTier: "reasoning",
    complexTier: "reasoning",
    cheapAllowed: true,
  },
  infographic_spec: {
    defaultTier: "reasoning",
    premiumTier: "reviewer",
    complexTier: "reviewer",
    cheapAllowed: false,
    reviewerOnPremium: true,
    reviewerOnHuge: true,
  },
};

export function resolveTextRoute(
  jobType: RouteJobType,
  options: RouteOptions = {},
  sourceTextLength = 0,
): TextRoute {
  const modelSet = currentModelSet();
  const sourceSizeTier = classifySourceSize(sourceTextLength);
  const signals = routeSignals(jobType, options, sourceSizeTier);
  const configuredDefault = textProviderEnv("TEXT_PROVIDER_DEFAULT") ??
    DEFAULT_TEXT_PROVIDER;
  const explicitModel = explicitTextModel(options);
  const desiredTier = explicitModel
    ? tierForExplicitModel(options, explicitModel)
    : desiredTextTier(jobType, options, sourceSizeTier, signals);
  const selectedModel = explicitModel ??
    modelForJobTier(jobType, desiredTier, modelSet);
  const desiredProvider = providerForModel(selectedModel, configuredDefault);
  const baseReason = `${jobType}:${desiredTier}:${signals.join("+") || "base"}`;

  if (isTextProviderAvailable(desiredProvider)) {
    return {
      provider: desiredProvider,
      model: selectedModel,
      tier: desiredTier,
      reason: explicitModel ? `${baseReason}:explicit_model` : baseReason,
      fallbackUsed: false,
      sourceSizeTier,
      signals,
    };
  }

  const fallbackModel = fallbackTextModelForTier(desiredTier, modelSet);
  const fallbackProvider = providerForModel(fallbackModel, "anthropic");
  if (isTextProviderAvailable(fallbackProvider)) {
    return {
      provider: fallbackProvider,
      model: fallbackModel,
      tier: fallbackTierForModel(fallbackModel, desiredTier, modelSet),
      reason: `${baseReason}:provider_fallback:${desiredProvider}_unavailable`,
      fallbackUsed: true,
      sourceSizeTier,
      signals: [...signals, "provider_fallback"],
    };
  }

  return {
    provider: desiredProvider,
    model: selectedModel,
    tier: desiredTier,
    reason: `${baseReason}:hard_fallback`,
    fallbackUsed: true,
    sourceSizeTier,
    signals: [...signals, "hard_fallback"],
  };
}

export function resolveImageRoute(
  quality: RouteOptions["imageQuality"] = "standard",
  requestedModel?: string,
): ImageRoute {
  const normalizedQuality = quality === "low" ? "draft" : quality ?? "standard";
  const defaultModel = normalizedQuality === "draft"
    ? imageModel("IMAGE_MODEL_DRAFT", "gpt-image-1-mini")
    : normalizedQuality === "premium"
    ? imageModel("IMAGE_MODEL_PREMIUM", "gpt-image-2")
    : imageModel("IMAGE_MODEL_STANDARD", "gpt-image-1.5");
  const selectedModel = requestedModel?.trim() || defaultModel;
  const defaultProvider = imageProviderEnv("IMAGE_PROVIDER_DEFAULT") ??
    "openai";
  return {
    provider: imageProviderForModel(selectedModel, defaultProvider),
    model: selectedModel,
    fallbackProvider: imageProviderEnv("IMAGE_PROVIDER_FALLBACK") ??
      "stability",
    fallbackModel: imageModel(
      "IMAGE_MODEL_FALLBACK",
      "stable-image-ultra",
    ),
    quality: normalizedQuality,
  };
}

export function routeOptionsFromPayload(
  value: Record<string, unknown> | undefined,
): RouteOptions {
  const options = value ?? {};
  const modelPolicy = optionText(options.modelPolicy ?? options.model_policy);
  const minimumDepth = optionText(
    options.minimumDepth ?? options.minimum_depth,
  );
  const outputLengthPolicy = optionText(
    options.outputLengthPolicy ?? options.output_length_policy,
  );
  const preferredTier = optionText(
    options.preferredModelTier ?? options.preferred_model_tier,
  );
  const mode = optionText(options.mode);
  const detailLevel = optionText(options.detailLevel ?? options.detail_level);
  const difficulty = optionText(options.difficulty);
  const style = optionText(options.style);
  const format = optionText(
    options.outputFormat ?? options.output_format ?? options.tableFormat ??
      options.table_format,
  );
  const sourceCount = Math.max(
    numericOption(
      options.sourceCount ?? options.source_count ??
        options.selectedSourceCount ?? options.selected_source_count,
    ),
    sourceIdCount(options.sourceIds ?? options.source_ids),
  );
  const requestedImageModel = rawOptionText(
    options.imageModelPolicy ??
      options.image_model_policy ??
      options.gptImageModel ??
      options.gpt_image_model ??
      options.openaiImageModel ??
      options.openai_image_model ??
      options.imageModel ??
      options.image_model,
  );
  const visualOutputContract = optionText(
    options.visualOutputContract ??
      options.visual_output_contract ??
      options.shareableAssetPolicy ??
      options.shareable_asset_policy,
  );
  const requestedTextModel = rawOptionText(
    options.textModel ??
      options.text_model ??
      options.openaiTextModel ??
      options.openai_text_model ??
      options.preferredModel ??
      options.preferred_model,
  );
  return {
    premium: truthy(options.premium) || options.tier === "premium" ||
      optionText(options.qualityTier ?? options.quality_tier).includes(
        "premium",
      ) ||
      modelPolicy.includes("premium") ||
      preferredTier.includes("premium") ||
      outputLengthPolicy.includes("comprehensive"),
    clinical: truthy(options.clinical) || style.includes("clinical") ||
      style.includes("klinik") ||
      mode.includes("clinical") ||
      mode.includes("klinik") ||
      modelPolicy.includes("clinical") ||
      minimumDepth.includes("clinical") ||
      detailLevel.includes("clinical") ||
      detailLevel.includes("klinik"),
    hard: truthy(options.hard) ||
      difficulty.includes("hard") ||
      difficulty.includes("zor") ||
      difficulty.includes("tus") ||
      difficulty.includes("exam") ||
      difficulty.includes("sınav") ||
      modelPolicy.includes("assessment") ||
      mode.includes("tus") ||
      mode.includes("exam") ||
      mode.includes("sınav"),
    cheap: truthy(options.cheap) || options.tier === "cheap" ||
      optionText(options.qualityTier ?? options.quality_tier).includes(
        "economy",
      ) ||
      mode.includes("ekonomik"),
    short: truthy(options.short) ||
      mode.includes("short") ||
      mode.includes("kısa") ||
      mode.includes("ultra kısa") ||
      outputLengthPolicy.includes("compact"),
    structured: truthy(options.structured) ||
      mode.includes("structured") ||
      mode.includes("exam-morning") ||
      format.includes("table") ||
      format.includes("tablo") ||
      format.includes("matrix") ||
      outputLengthPolicy.includes("detailed") ||
      outputLengthPolicy.includes("structured") ||
      outputLengthPolicy.includes("longform"),
    personalized: truthy(options.personalized) ||
      truthy(options.adaptive) ||
      optionText(options.planGoal ?? options.plan_goal).length > 0 ||
      optionText(options.dailyTime ?? options.daily_time).length > 0,
    naturalNarration: truthy(options.naturalNarration) ||
      truthy(options.natural_narration) ||
      optionText(options.voiceStyle ?? options.voice_style).length > 0 ||
      mode.includes("anlatıcı") ||
      mode.includes("narration"),
    complex: truthy(options.complex) ||
      truthy(options.complexity) ||
      minimumDepth.includes("high") ||
      minimumDepth.includes("deep") ||
      minimumDepth.includes("derin") ||
      outputLengthPolicy.includes("longform") ||
      outputLengthPolicy.includes("comprehensive") ||
      preferredTier.includes("high_reasoning") ||
      sourceCount > 1,
    reviewer: truthy(options.reviewer) ||
      truthy(options.reviewBeforeReturn ?? options.review_before_return) ||
      modelPolicy.includes("review") ||
      modelPolicy.includes("flagship") ||
      preferredTier.includes("reviewer") ||
      preferredTier.includes("gpt-5.5") ||
      optionText(options.reasoningEffort ?? options.reasoning_effort).includes(
        "xhigh",
      ),
    longContext: truthy(options.longContext) ||
      truthy(options.long_context) ||
      modelPolicy.includes("long_context") ||
      preferredTier.includes("long_context") ||
      minimumDepth.includes("full_source") ||
      outputLengthPolicy.includes("longform"),
    textModel: trustedTextModelOverride(requestedTextModel),
    imageQuality: imageQuality(options.imageQuality ?? options.image_quality),
    imageModel: requestedImageModel,
    imageRequired: truthy(
      options.visualAssetRequired ??
        options.visual_asset_required ??
        options.imageRequired ??
        options.image_required,
    ) ||
      visualOutputContract.includes("image_url") ||
      visualOutputContract.includes("remote_image") ||
      visualOutputContract.includes("shareable") ||
      visualOutputContract.includes("visual"),
    audioRequired: truthy(
      options.audioAssetRequired ??
        options.audio_asset_required ??
        options.audioRequired ??
        options.audio_required,
    ) ||
      optionText(
        options.podcastOutputContract ?? options.podcast_output_contract,
      ).includes("audio"),
    sourceCount,
  };
}

export function isImageProviderAvailable(provider: ImageProviderName) {
  if (provider === "openai") return Boolean(Deno.env.get("OPENAI_API_KEY"));
  return Boolean(Deno.env.get("STABILITY_API_KEY"));
}

export function isImageRouteAvailable(route: ImageRoute) {
  return isImageProviderAvailable(route.provider) ||
    isImageProviderAvailable(route.fallbackProvider);
}

export function syncInfographicImageEnabled() {
  const value = (Deno.env.get("SOURCEBASE_SYNC_INFOGRAPHIC_IMAGE_ENABLED") ??
    Deno.env.get("INFOGRAPHIC_SYNC_IMAGE_ENABLED") ??
    "")
    .trim()
    .toLowerCase();
  return value === "1" || value === "true" || value === "yes" ||
    value === "on";
}

export function shouldGenerateInfographicImage(options?: RouteOptions) {
  return syncInfographicImageEnabled() || Boolean(options?.imageRequired);
}

export function isAudioProviderAvailable() {
  return Boolean(Deno.env.get("OPENAI_API_KEY"));
}

export function shouldGeneratePodcastAudio(options?: RouteOptions) {
  if (!isAudioProviderAvailable()) return false;
  return podcastAudioEnabled() || Boolean(options?.audioRequired);
}

function podcastAudioEnabled() {
  const value = (Deno.env.get("SOURCEBASE_PODCAST_AUDIO_ENABLED") ??
    Deno.env.get("PODCAST_AUDIO_ENABLED") ??
    "true")
    .trim()
    .toLowerCase();
  return value === "1" || value === "true" || value === "yes" ||
    value === "on";
}

export function resolvePodcastAudioRoute(
  options?: RouteOptions,
): PodcastAudioRoute {
  const model = textModel("AUDIO_MODEL_TTS", "gpt-4o-mini-tts");
  return {
    provider: "openai",
    model,
    hostVoice: textModel("AUDIO_VOICE_HOST", "alloy"),
    expertVoice: textModel("AUDIO_VOICE_EXPERT", "onyx"),
    narratorVoice: textModel("AUDIO_VOICE_NARRATOR", "alloy"),
    format: "mp3",
  };
}

function desiredTextTier(
  jobType: RouteJobType,
  options: RouteOptions,
  sourceSizeTier: SourceSizeTier,
  signals: string[],
): TextTier {
  const profile = ROUTE_PROFILES[jobType] ?? ROUTE_PROFILES.summary;
  if (options.cheap && profile.cheapAllowed && !qualityProtected(options)) {
    return "cheap";
  }
  if (options.reviewer || signals.includes("reviewer_requested")) {
    return "reviewer";
  }
  if (
    profile.reviewerOnPremium && options.premium &&
    (options.clinical || options.hard || options.complex ||
      sourceSizeTier === "large" || sourceSizeTier === "huge")
  ) {
    return "reviewer";
  }
  if (profile.reviewerOnHuge && sourceSizeTier === "huge") {
    return "reviewer";
  }
  if (sourceSizeTier === "huge" && highImpactJob(jobType)) {
    return "reviewer";
  }
  if (
    options.premium || options.clinical || options.hard || options.complex ||
    options.personalized || options.naturalNarration || options.longContext ||
    sourceSizeTier === "large" || sourceSizeTier === "huge"
  ) {
    if (sourceSizeTier === "huge" && profile.complexTier === "reviewer") {
      return "reviewer";
    }
    return options.premium ? profile.premiumTier : profile.complexTier;
  }
  if (jobType === "summary" && options.short) {
    return "cheap";
  }
  return profile.defaultTier;
}

function routeSignals(
  jobType: RouteJobType,
  options: RouteOptions,
  sourceSizeTier: SourceSizeTier,
) {
  const signals: string[] = [sourceSizeTier];
  if (options.cheap) signals.push("cheap_requested");
  if (options.premium) signals.push("premium");
  if (options.clinical) signals.push("clinical");
  if (options.hard) signals.push("assessment_hard");
  if (options.short) signals.push("short");
  if (options.structured) signals.push("structured");
  if (options.personalized) signals.push("personalized");
  if (options.naturalNarration) signals.push("narration");
  if (options.complex) signals.push("complex");
  if (options.longContext) signals.push("long_context");
  if (options.reviewer) signals.push("reviewer_requested");
  if ((options.sourceCount ?? 0) > 1) signals.push("multi_source");
  if (jobType === "infographic" || jobType === "infographic_spec") {
    signals.push("visual_spec");
  }
  if (jobType === "clinical_scenario") signals.push("clinical_case");
  if (jobType === "comparison") signals.push("matrix");
  return signals;
}

function currentModelSet(): ModelSet {
  return {
    cheap: textModel("TEXT_MODEL_CHEAP", "gpt-5.4-mini"),
    standard: textModel("TEXT_MODEL_STANDARD", "gpt-5.4-mini"),
    centralAi: textModel("TEXT_MODEL_CENTRAL_AI", "gpt-4o-mini"),
    reasoning: textModel("TEXT_MODEL_REASONING", "gpt-5.4"),
    reviewer: textModel("TEXT_MODEL_REVIEWER", "gpt-5.5"),
  };
}

function modelForTier(tier: TextTier, modelSet: ModelSet) {
  switch (tier) {
    case "cheap":
      return modelSet.cheap;
    case "reviewer":
      return modelSet.reviewer;
    case "reasoning":
      return modelSet.reasoning;
    case "standard":
      return modelSet.standard;
  }
}

function modelForJobTier(
  jobType: RouteJobType,
  tier: TextTier,
  modelSet: ModelSet,
) {
  if (jobType === "central_ai_chat" && tier === "standard") {
    return modelSet.centralAi;
  }
  return modelForTier(tier, modelSet);
}

function fallbackTextModelForTier(tier: TextTier, modelSet: ModelSet) {
  const envFallback = Deno.env.get("TEXT_MODEL_FALLBACK")?.trim();
  if (envFallback) return envFallback;
  const anthropicFallback = Deno.env.get("TEXT_MODEL_ANTHROPIC_FALLBACK")
    ?.trim();
  if (anthropicFallback) return anthropicFallback;
  if (tier === "cheap") return modelSet.cheap || modelSet.standard;
  if (tier === "reviewer" || tier === "reasoning") {
    return Deno.env.get("TEXT_MODEL_REASONING_FALLBACK")?.trim() ||
      modelSet.standard;
  }
  return modelSet.standard;
}

function fallbackTierForModel(
  model: string,
  desiredTier: TextTier,
  modelSet: ModelSet,
): TextTier {
  if (model === modelSet.cheap) return "cheap";
  if (model === modelSet.reviewer) return "reviewer";
  if (model === modelSet.reasoning) return "reasoning";
  if (model === modelSet.standard) return "standard";
  return desiredTier === "cheap" ? "cheap" : "standard";
}

function tierForExplicitModel(
  options: RouteOptions,
  model: string,
): TextTier {
  const normalized = model.toLowerCase();
  if (options.reviewer || normalized.includes("5.5")) return "reviewer";
  if (
    options.cheap || normalized.includes("lite") || normalized.includes("nano")
  ) {
    return "cheap";
  }
  if (
    options.premium || options.clinical || options.hard ||
    normalized.includes("5.4") || normalized.includes("reason")
  ) {
    return "reasoning";
  }
  return "standard";
}

function explicitTextModel(options: RouteOptions) {
  return options.textModel?.trim() || undefined;
}

function trustedTextModelOverride(model: string | undefined) {
  if (!model) return undefined;
  if (!truthy(Deno.env.get("SOURCEBASE_ALLOW_CLIENT_TEXT_MODEL"))) {
    return undefined;
  }
  return model;
}

function qualityProtected(options: RouteOptions) {
  return Boolean(
    options.premium || options.clinical || options.hard || options.complex ||
      options.reviewer || options.longContext,
  );
}

function highImpactJob(jobType: RouteJobType) {
  return jobType === "clinical_scenario" ||
    jobType === "comparison" ||
    jobType === "infographic" ||
    jobType === "infographic_spec" ||
    jobType === "podcast";
}

function classifySourceSize(length: number): SourceSizeTier {
  if (length < SHORT_SOURCE_CHARS) return "tiny";
  if (length < MEDIUM_SOURCE_CHARS) return "short";
  if (length < LARGE_SOURCE_CHARS) return "medium";
  if (length < HUGE_SOURCE_CHARS) return "large";
  return "huge";
}

function isTextProviderAvailable(provider: TextProvider) {
  if (provider === "openai") return Boolean(Deno.env.get("OPENAI_API_KEY"));
  return Boolean(Deno.env.get("ANTHROPIC_API_KEY"));
}

function providerForModel(model: string, fallback: TextProvider): TextProvider {
  const normalized = model.toLowerCase();
  if (normalized.startsWith("gpt-") || normalized.startsWith("o")) {
    return "openai";
  }
  if (normalized.includes("claude")) return "anthropic";
  return fallback;
}

function imageProviderForModel(
  model: string,
  fallback: ImageProviderName,
): ImageProviderName {
  const normalized = model.toLowerCase();
  if (normalized.startsWith("gpt-image") || normalized.startsWith("dall-e")) {
    return "openai";
  }
  if (normalized.includes("stability") || normalized.includes("stable")) {
    return "stability";
  }
  return fallback;
}

function textModel(name: string, fallback: string) {
  return Deno.env.get(name)?.trim() || fallback;
}

function imageModel(name: string, fallback: string) {
  return Deno.env.get(name)?.trim() || fallback;
}

function textProviderEnv(name: string): TextProvider | undefined {
  const value = Deno.env.get(name)?.trim().toLowerCase();
  return value === "openai" || value === "anthropic" ? value : undefined;
}

function imageProviderEnv(name: string): ImageProviderName | undefined {
  const value = Deno.env.get(name)?.trim().toLowerCase();
  return value === "openai" || value === "stability" ? value : undefined;
}

function truthy(value: unknown) {
  const text = value?.toString().trim().toLowerCase();
  return value === true || text === "true" || text === "1" || text === "yes" ||
    text === "on";
}

function numericOption(value: unknown) {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : 0;
}

function sourceIdCount(value: unknown) {
  if (Array.isArray(value)) {
    return value
      .map((item) => item?.toString().trim() ?? "")
      .filter((item) => item.length > 0).length;
  }
  const text = value?.toString().trim() ?? "";
  if (!text) return 0;
  return text.split(",").map((item) => item.trim()).filter(Boolean).length;
}

function optionText(value: unknown) {
  return value?.toString().trim().toLowerCase() ?? "";
}

function rawOptionText(value: unknown) {
  const text = value?.toString().trim() ?? "";
  return text || undefined;
}

function imageQuality(value: unknown): RouteOptions["imageQuality"] {
  const text = value?.toString().trim().toLowerCase();
  if (
    text === "draft" || text === "standard" || text === "premium" ||
    text === "low"
  ) {
    return text;
  }
  if (text === "medium") return "standard";
  if (text === "high") return "premium";
  return undefined;
}

import { GenerationType, SafeError } from "../types.ts";
import {
  isImageProviderAvailable,
  isImageRouteAvailable,
  resolveImageRoute,
  resolveTextRoute,
  RouteOptions,
  shouldGenerateInfographicImage,
} from "./model-router.ts";

export type QualityTier = "economy" | "standard" | "premium";
export type SourceSizeTier = "tiny" | "short" | "medium" | "large" | "huge";

export interface McPricingQuote {
  estimated_provider_cost_tl: number;
  target_margin: number;
  estimated_revenue_tl: number;
  raw_mc_cost: number;
  final_mc_cost: number;
  amount_units: number;
  mc_unit: number;
  quality_tier: QualityTier;
  model_tier: string;
  source_size_tier: SourceSizeTier;
  reserved_mc: number;
  image_route?: {
    provider: string;
    model: string;
    quality: string;
    provider_quality?: string;
  };
  route: {
    provider: string;
    model: string;
    tier: string;
    reason: string;
    fallbackUsed: boolean;
  };
}

const MC_UNITS_PER_MC = 100;
const FALLBACK_MC_TL_VALUE_CENTS = 350;
const FALLBACK_COST_RATIO_BPS = 3000;
const FALLBACK_MARGIN = 0.7;

const SOURCE_MULTIPLIER_BPS: Record<SourceSizeTier, number> = {
  tiny: 10_000,
  short: 10_000,
  medium: 11_500,
  large: 13_500,
  huge: 17_500,
};

const MIN_UNITS: Record<string, Record<QualityTier, number>> = {
  central_ai: { economy: 5, standard: 10, premium: 200 },
  summary: { economy: 25, standard: 50, premium: 100 },
  exam_morning_summary: { economy: 50, standard: 100, premium: 200 },
  flashcard: { economy: 25, standard: 75, premium: 150 },
  quiz: { economy: 50, standard: 100, premium: 200 },
  algorithm: { economy: 100, standard: 100, premium: 200 },
  comparison: { economy: 100, standard: 100, premium: 200 },
  mind_map: { economy: 100, standard: 100, premium: 200 },
  clinical_scenario: { economy: 200, standard: 200, premium: 400 },
  learning_plan: { economy: 150, standard: 150, premium: 300 },
  podcast: { economy: 150, standard: 150, premium: 300 },
  infographic: { economy: 25, standard: 50, premium: 100 },
};

const MODEL_COST_MICRO_TL: Record<string, { input: number; output: number }> = {
  "gpt-4o-mini": { input: 30, output: 120 },
  "gpt-5.4-mini": { input: 35, output: 207 },
  "gpt-5.4": { input: 115, output: 690 },
  "gpt-5.5": { input: 230, output: 1380 },
  "claude-sonnet-4-5": { input: 115, output: 690 },
};

const IMAGE_COST_USD: Record<string, Record<ImageQuality, number>> = {
  "gpt-image-2": { draft: 0.006, standard: 0.053, premium: 0.211 },
  "gpt-image-1.5": { draft: 0.009, standard: 0.034, premium: 0.133 },
  "gpt-image-1": { draft: 0.011, standard: 0.042, premium: 0.167 },
  "gpt-image-1-mini": { draft: 0.005, standard: 0.011, premium: 0.036 },
  "stable-image-ultra": { draft: 0.08, standard: 0.08, premium: 0.08 },
};
type ImageQuality = "draft" | "standard" | "premium";

export function normalizeQualityTier(value: unknown): QualityTier {
  const text = value?.toString().trim().toLowerCase();
  if (text === "economy" || text === "standard" || text === "premium") {
    return text;
  }
  return "standard";
}

/**
 * The user-selected quality tier is authoritative for model + price. The client
 * floods premium-leaning policy strings (modelPolicy "premium_…",
 * outputLengthPolicy "comprehensive_…", longContext, etc.) on every request, so
 * without this override every tier would route to the reasoning model and cost
 * the same. Here qualityTier wins:
 *  - economy  → cheap model, draft images; promotion signals stripped
 *  - standard → standard model, standard images; only source SIZE still
 *               promotes to reasoning (large/huge sources need it)
 *  - premium  → reasoning/reviewer, premium images; keep all signals
 */
export function routeOptionsForQuality(
  qualityTier: QualityTier,
  options: RouteOptions,
): RouteOptions {
  if (qualityTier === "premium") {
    return { ...options, cheap: false, premium: true, imageQuality: "premium" };
  }
  const base: RouteOptions = {
    ...options,
    premium: false,
    reviewer: false,
    complex: false,
    longContext: false,
    personalized: false,
    naturalNarration: false,
    hard: false,
  };
  if (qualityTier === "economy") {
    return { ...base, cheap: true, imageQuality: "draft" };
  }
  return {
    ...base,
    cheap: false,
    imageQuality: options.imageQuality === "premium"
      ? "standard"
      : options.imageQuality ?? "standard",
  };
}

export function estimateGenerationPricing(input: {
  jobType: GenerationType | "central_ai";
  sourceTextLength: number;
  maxTokens?: number;
  count?: number;
  qualityTier: QualityTier;
  routeOptions?: RouteOptions;
}): McPricingQuote {
  const sourceSizeTier = classifySourceSize(input.sourceTextLength);
  const routeOptions = routeOptionsForQuality(
    input.qualityTier,
    input.routeOptions ?? {},
  );
  const route = resolveTextRoute(
    input.jobType === "central_ai" ? "central_ai_chat" : input.jobType,
    routeOptions,
    input.sourceTextLength,
  );
  const modelCost = modelCostMicroTl(route.model);
  const inputTokens = Math.max(1, Math.ceil(input.sourceTextLength / 4));
  const outputTokens = Math.max(
    256,
    input.maxTokens ?? defaultOutputTokens(input.jobType, input.count),
  );
  let providerCostMicroTl = inputTokens * modelCost.input +
    outputTokens * modelCost.output;
  providerCostMicroTl = Math.ceil(
    providerCostMicroTl * SOURCE_MULTIPLIER_BPS[sourceSizeTier] / 10_000,
  );

  let imageRoute: McPricingQuote["image_route"];
  if (
    input.jobType === "infographic" &&
    shouldGenerateInfographicImage(routeOptions)
  ) {
    const resolvedImageRoute = resolveImageRoute(
      routeOptions.imageQuality,
      routeOptions.imageModel,
    );
    if (isImageRouteAvailable(resolvedImageRoute)) {
      const selectedImageRoute = isImageProviderAvailable(
          resolvedImageRoute.provider,
        )
        ? {
          provider: resolvedImageRoute.provider,
          model: resolvedImageRoute.model,
        }
        : {
          provider: resolvedImageRoute.fallbackProvider,
          model: resolvedImageRoute.fallbackModel,
        };
      providerCostMicroTl += imageCostMicroTl(
        selectedImageRoute.model,
        resolvedImageRoute.quality,
      );
      imageRoute = {
        ...selectedImageRoute,
        quality: resolvedImageRoute.quality,
        provider_quality: providerImageQuality(
          selectedImageRoute.model,
          resolvedImageRoute.quality,
        ),
      };
    }
  }

  const calculatedUnits = costMicroTlToMcUnits(providerCostMicroTl);
  const minimumUnits = minUnits(input.jobType, input.qualityTier);
  const finalUnits = roundUpUnitsToStep(
    Math.max(calculatedUnits, minimumUnits),
  );
  const standardUnits = input.qualityTier === "premium"
    ? estimateGenerationPricing({
      ...input,
      qualityTier: "standard",
      routeOptions: {
        ...(input.routeOptions ?? {}),
        premium: false,
        imageQuality: "standard",
        imageModel: undefined,
      },
    }).amount_units
    : undefined;
  const amountUnits = input.jobType !== "infographic" &&
      input.qualityTier === "premium" && standardUnits
    ? roundUpUnitsToStep(Math.max(finalUnits, standardUnits * 2))
    : finalUnits;
  const discountedAmountUnits = input.jobType === "infographic"
    ? Math.max(minUnitAsUnits(), amountUnits - infographicDiscountUnits())
    : amountUnits;
  const tierAdjustedAmountUnits = input.jobType === "infographic" &&
      input.qualityTier === "premium" && standardUnits
    ? roundUpUnitsToStep(
      Math.max(discountedAmountUnits, standardUnits + minUnitAsUnits()),
    )
    : discountedAmountUnits;

  // App-wide loyalty benefit: charge 15% fewer MC units than computed so coins
  // deplete ~15% slower in SourceBase. Applied after all tier/min/discount logic.
  const benefitAdjustedUnits = roundUpUnitsToStep(
    Math.max(minUnitAsUnits(), Math.floor(tierAdjustedAmountUnits * 0.85)),
  );

  return quoteFromUnits({
    providerCostMicroTl,
    amountUnits: benefitAdjustedUnits,
    qualityTier: input.qualityTier,
    sourceSizeTier,
    route,
    imageRoute,
  });
}

export function formatMc(units: number) {
  const whole = Math.trunc(units / MC_UNITS_PER_MC);
  const cents = units % MC_UNITS_PER_MC;
  if (cents === 0) return `${whole}`;
  return `${whole}.${String(cents).padStart(2, "0").replace(/0+$/, "")}`;
}

function quoteFromUnits(input: {
  providerCostMicroTl: number;
  amountUnits: number;
  qualityTier: QualityTier;
  sourceSizeTier: SourceSizeTier;
  route: ReturnType<typeof resolveTextRoute>;
  imageRoute?: McPricingQuote["image_route"];
}): McPricingQuote {
  const providerCostTl = input.providerCostMicroTl / 1_000_000;
  const revenueTl = providerCostTl / costRatio();
  const rawMc = revenueTl / mcTlValue();
  const finalMc = input.amountUnits / MC_UNITS_PER_MC;
  return {
    estimated_provider_cost_tl: roundMoney(providerCostTl),
    target_margin: targetMargin(),
    estimated_revenue_tl: roundMoney(revenueTl),
    raw_mc_cost: roundMc(rawMc),
    final_mc_cost: finalMc,
    amount_units: input.amountUnits,
    mc_unit: minMcUnit(),
    quality_tier: input.qualityTier,
    model_tier: input.route.tier,
    source_size_tier: input.sourceSizeTier,
    reserved_mc: finalMc,
    image_route: input.imageRoute,
    route: {
      provider: input.route.provider,
      model: input.route.model,
      tier: input.route.tier,
      reason: input.route.reason,
      fallbackUsed: input.route.fallbackUsed,
    },
  };
}

function costMicroTlToMcUnits(providerCostMicroTl: number) {
  const mcTlCents = mcTlValueCents();
  const costRatioBps = costRatioBasisPoints();
  const denominator = costRatioBps * mcTlCents;
  const numerator = providerCostMicroTl * 100;
  return roundUpUnitsToStep(Math.ceil(numerator / denominator));
}

function minUnits(jobType: GenerationType | "central_ai", tier: QualityTier) {
  return MIN_UNITS[jobType]?.[tier] ?? MIN_UNITS.summary[tier];
}

function modelCostMicroTl(model: string) {
  return MODEL_COST_MICRO_TL[model] ?? MODEL_COST_MICRO_TL[
    Deno.env.get("TEXT_MODEL_STANDARD")?.trim() || "gpt-5.4-mini"
  ] ?? MODEL_COST_MICRO_TL["gpt-5.4-mini"];
}

function imageCostMicroTl(model: string, quality: ImageQuality) {
  const usd = IMAGE_COST_USD[model]?.[providerImageQuality(model, quality)];
  if (typeof usd === "number") {
    return Math.ceil(usd * usdTryRate() * 1_000_000);
  }
  return 3_000_000;
}

function providerImageQuality(model: string, quality: ImageQuality) {
  return quality;
}

function classifySourceSize(length: number): SourceSizeTier {
  if (length < 1_500) return "tiny";
  if (length < 15_000) return "short";
  if (length < 90_000) return "medium";
  if (length < 300_000) return "large";
  return "huge";
}

function defaultOutputTokens(
  jobType: GenerationType | "central_ai",
  count?: number,
) {
  switch (jobType) {
    case "flashcard":
      return Math.max(1024, (count ?? 20) * 90);
    case "quiz":
      return Math.max(1200, (count ?? 10) * 140);
    case "summary":
      return 1200;
    case "exam_morning_summary":
      return 1500;
    case "infographic":
      return 1600;
    case "central_ai":
      return 900;
    default:
      return 1500;
  }
}

function roundUpUnitsToStep(units: number) {
  const step = minUnitAsUnits();
  return Math.ceil(units / step) * step;
}

function mcTlValue() {
  return mcTlValueCents() / 100;
}

function mcTlValueCents() {
  return Math.round(
    Number(Deno.env.get("MC_TL_VALUE") ?? "3.5") * 100,
  ) || FALLBACK_MC_TL_VALUE_CENTS;
}

function targetMargin() {
  return Number(Deno.env.get("TARGET_GROSS_MARGIN") ?? "0.70") ||
    FALLBACK_MARGIN;
}

function costRatio() {
  return costRatioBasisPoints() / 10_000;
}

function costRatioBasisPoints() {
  return Math.round((1 - targetMargin()) * 10_000) ||
    FALLBACK_COST_RATIO_BPS;
}

function minMcUnit() {
  return Number(Deno.env.get("MIN_MC_UNIT") ?? "0.05") || 0.05;
}

function minUnitAsUnits() {
  return Math.max(1, Math.round(minMcUnit() * MC_UNITS_PER_MC));
}

function usdTryRate() {
  return Number(Deno.env.get("USD_TRY_RATE") ?? "46") || 46;
}

function infographicDiscountUnits() {
  return Math.max(
    0,
    Math.round(Number(Deno.env.get("INFOGRAPHIC_MC_DISCOUNT") ?? "1") * 100),
  );
}

function roundMoney(value: number) {
  return Math.round(value * 10_000) / 10_000;
}

function roundMc(value: number) {
  return Math.round(value * 10_000) / 10_000;
}

export function insufficientBalance(
  balanceUnits: number,
  quote: McPricingQuote,
) {
  return new SafeError(
    "INSUFFICIENT_MC",
    `Yetersiz MedasiCoin bakiyesi. Gerekli: ${
      formatMc(quote.amount_units)
    } MC.`,
    402,
  );
}

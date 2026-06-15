import {
  isImageProviderAvailable,
  resolveImageRoute,
  resolveTextRoute,
  routeOptionsFromPayload,
  shouldGenerateInfographicImage,
} from "./model-router.ts";

Deno.test("router keeps lightweight summaries on cheap model when requested", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    TEXT_MODEL_CHEAP: undefined,
    TEXT_MODEL_STANDARD: undefined,
  }, () => {
    const route = resolveTextRoute("summary", { short: true }, 900);

    assertEquals(route.provider, "openai");
    assertEquals(route.model, "gpt-5.4-mini");
    assertEquals(route.tier, "cheap");
    assert(route.signals.includes("short"));
  });
});

Deno.test("router promotes premium clinical scenarios to reviewer model", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    TEXT_MODEL_REVIEWER: undefined,
  }, () => {
    const route = resolveTextRoute(
      "clinical_scenario",
      { premium: true, clinical: true },
      20_000,
    );

    assertEquals(route.provider, "openai");
    assertEquals(route.model, "gpt-5.5");
    assertEquals(route.tier, "reviewer");
    assert(route.signals.includes("clinical_case"));
  });
});

Deno.test("router falls back to configured Anthropic model when OpenAI is unavailable", () => {
  withEnv({
    OPENAI_API_KEY: undefined,
    ANTHROPIC_API_KEY: "test-key",
    TEXT_MODEL_ANTHROPIC_FALLBACK: "claude-sonnet-4-5",
    TEXT_MODEL_REASONING: undefined,
    TEXT_MODEL_STANDARD: undefined,
  }, () => {
    const route = resolveTextRoute(
      "comparison",
      { premium: true, complex: true, longContext: true },
      190_000,
    );

    assertEquals(route.provider, "anthropic");
    assertEquals(route.model, "claude-sonnet-4-5");
    assertEquals(route.fallbackUsed, true);
    assertEquals(route.sourceSizeTier, "huge");
    assert(route.reason.includes("provider_fallback"));
  });
});

Deno.test("central AI uses dedicated OpenAI chat model when available", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    TEXT_MODEL_CENTRAL_AI: undefined,
  }, () => {
    const route = resolveTextRoute("central_ai_chat", {}, 2_000);

    assertEquals(route.provider, "openai");
    assertEquals(route.model, "gpt-4o-mini");
    assertEquals(route.tier, "standard");
  });
});

Deno.test("payload route options understand Turkish clinical exam signals", () => {
  const options = routeOptionsFromPayload({
    mode: "Klinik TUS sınav odaklı",
    quality_tier: "Premium",
    output_length_policy: "comprehensive_structured_not_short",
    sourceCount: 2,
    review_before_return: "true",
  });

  assertEquals(options.premium, true);
  assertEquals(options.clinical, true);
  assertEquals(options.hard, true);
  assertEquals(options.structured, true);
  assertEquals(options.complex, true);
  assertEquals(options.reviewer, true);
  assertEquals(options.sourceCount, 2);
});

Deno.test("payload route options infer multi source count from sourceIds", () => {
  const options = routeOptionsFromPayload({
    sourceIds: [
      "11111111-1111-4111-8111-111111111111",
      "22222222-2222-4222-8222-222222222222",
    ],
    imageQuality: "high",
  });
  const route = resolveTextRoute("comparison", options, 6_000);

  assertEquals(options.sourceCount, 2);
  assertEquals(options.complex, true);
  assertEquals(options.imageQuality, "premium");
  assertEquals(route.signals.includes("multi_source"), true);
});

Deno.test("payload route options keep explicit infographic visual asset request", () => {
  withEnv({
    SOURCEBASE_SYNC_INFOGRAPHIC_IMAGE_ENABLED: undefined,
  }, () => {
    const options = routeOptionsFromPayload({
      visualAssetRequired: "true",
      visualOutputContract: "return_image_url_or_renderable_sections",
    });

    assertEquals(options.imageRequired, true);
    assertEquals(shouldGenerateInfographicImage(options), true);
  });
});

Deno.test("client text model override is ignored unless explicitly enabled", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    SOURCEBASE_ALLOW_CLIENT_TEXT_MODEL: undefined,
  }, () => {
    const options = routeOptionsFromPayload({
      textModel: "gpt-5.5",
    });
    const route = resolveTextRoute("summary", options, 4_000);

    assertEquals(options.textModel, undefined);
    assertEquals(route.model, "gpt-5.4-mini");
  });
});

Deno.test("trusted text model override routes through matching provider", () => {
  withEnv({
    OPENAI_API_KEY: "test-key",
    SOURCEBASE_ALLOW_CLIENT_TEXT_MODEL: "true",
  }, () => {
    const options = routeOptionsFromPayload({
      textModel: "gpt-5.5",
      review_before_return: "true",
    });
    const route = resolveTextRoute("summary", options, 4_000);

    assertEquals(options.textModel, "gpt-5.5");
    assertEquals(route.provider, "openai");
    assertEquals(route.model, "gpt-5.5");
    assertEquals(route.tier, "reviewer");
  });
});

Deno.test("image router maps draft standard and premium to current GPT image models", () => {
  withEnv({
    IMAGE_MODEL_DRAFT: undefined,
    IMAGE_MODEL_STANDARD: undefined,
    IMAGE_MODEL_PREMIUM: undefined,
  }, () => {
    assertEquals(resolveImageRoute("draft").model, "gpt-image-1-mini");
    assertEquals(resolveImageRoute("standard").model, "gpt-image-1.5");
    assertEquals(resolveImageRoute("premium").model, "gpt-image-2");
  });
});

Deno.test("image route falls back to Stability when OpenAI image provider is absent", () => {
  withEnv({
    OPENAI_API_KEY: undefined,
    STABILITY_API_KEY: "test-key",
    IMAGE_PROVIDER_FALLBACK: undefined,
    IMAGE_MODEL_FALLBACK: undefined,
  }, () => {
    const route = resolveImageRoute("standard");

    assertEquals(route.provider, "openai");
    assertEquals(route.model, "gpt-image-1.5");
    assertEquals(route.fallbackProvider, "stability");
    assertEquals(route.fallbackModel, "stable-image-ultra");
    assertEquals(isImageProviderAvailable(route.provider), false);
    assertEquals(isImageProviderAvailable(route.fallbackProvider), true);
  });
});

Deno.test("image provider only reports configured OpenAI or Stability keys", () => {
  withEnv({
    OPENAI_API_KEY: undefined,
    STABILITY_API_KEY: undefined,
  }, () => {
    assertEquals(isImageProviderAvailable("openai"), false);
    assertEquals(isImageProviderAvailable("stability"), false);
  });
});

Deno.test("custom stability image model routes through stability provider", () => {
  withEnv({
    IMAGE_PROVIDER_DEFAULT: undefined,
  }, () => {
    const route = resolveImageRoute("premium", "stable-image-ultra");

    assertEquals(route.provider, "stability");
    assertEquals(route.model, "stable-image-ultra");
  });
});

function withEnv(
  updates: Record<string, string | undefined>,
  run: () => void,
) {
  const previous = new Map<string, string | undefined>();
  for (const [key, value] of Object.entries(updates)) {
    previous.set(key, Deno.env.get(key));
    if (value === undefined) Deno.env.delete(key);
    else Deno.env.set(key, value);
  }
  try {
    run();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

function assert(condition: boolean) {
  if (!condition) throw new Error("Expected condition to be true.");
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}

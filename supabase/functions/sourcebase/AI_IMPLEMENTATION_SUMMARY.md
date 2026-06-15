# SourceBase AI Implementation Summary

SourceBase AI generation now routes through the local router and provider
adapters only:

- Text generation: OpenAI by default, Anthropic only when configured as a
  fallback or explicit route.
- Image generation: OpenAI Images by default, Stability only as configured
  fallback.
- File storage: Hetzner Object Storage through S3-compatible signed URLs.

## Runtime Files

- `services/model-router.ts`: chooses text and image model routes.
- `services/ai-generation-provider.ts`: delegates text generation to OpenAI or
  Anthropic.
- `services/image-provider.ts`: generates infographic images with OpenAI or
  Stability.
- `services/job-processor.ts`: runs queued production jobs and persists output.

## Required AI Secrets

```bash
OPENAI_API_KEY=...
ANTHROPIC_API_KEY=... # optional fallback
STABILITY_API_KEY=... # optional image fallback
```

Object Storage credentials are used only for SourceBase Drive storage and stay
server-side.

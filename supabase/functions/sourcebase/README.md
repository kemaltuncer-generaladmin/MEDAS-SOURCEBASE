# SourceBase Edge Function

This function belongs only to SourceBase. Do not merge it with the existing
Qlinik Edge Function.

## Actions

- `drive_bootstrap`: checks SourceBase Drive server readiness.
- `create_upload_session`: creates a short-lived S3-compatible signed PUT URL
  for Hetzner Object Storage.
- `complete_upload`: validates that the uploaded object belongs to the
  authenticated user and returns the next processing step.

## Required Server Environment

Set these in the SourceBase Supabase/Coolify server environment only:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` for future DB writes, never in Flutter
- `STORAGE_DRIVER=s3`
- `S3_ENDPOINT=https://nbg1.your-objectstorage.com`
- `S3_REGION=nbg1`
- `S3_BUCKET=medasistorage`
- `S3_ACCESS_KEY`
- `S3_SECRET_KEY`
- `SOURCEBASE_ALLOWED_ORIGIN`
- `OPENAI_API_KEY` server-side only
- `TEXT_PROVIDER_DEFAULT`
- `TEXT_MODEL_CHEAP`
- `TEXT_MODEL_STANDARD`
- `TEXT_MODEL_REASONING`
- `TEXT_MODEL_REVIEWER`
- `IMAGE_PROVIDER_DEFAULT`
- `IMAGE_MODEL_DRAFT`
- `IMAGE_MODEL_STANDARD`
- `IMAGE_MODEL_PREMIUM`
- `IMAGE_PROVIDER_FALLBACK`
- `IMAGE_MODEL_FALLBACK`
- `ANTHROPIC_API_KEY` optional, server-side only
- `STABILITY_API_KEY` optional, server-side only
- `MC_TL_VALUE` default `3.5`
- `TARGET_GROSS_MARGIN` default `0.70`
- `MIN_MC_UNIT` default `0.05`
- `USD_TRY_RATE` default `46`, used for image provider cost estimates
- `INFOGRAPHIC_MC_DISCOUNT` default `1`
- `MC_MICRO_PRICING_ENABLED` default `true`

S3 keys must stay server-side. Keep them out of Git and out of Flutter build
args. AI provider keys must stay server-side and must not be passed to Flutter
build args.

## Object Storage CORS

The bucket must allow SourceBase web origins to send `PUT` with `Content-Type`
to signed URLs. Example policy:

```json
[
  {
    "origin": ["https://sourcebase.medasi.com.tr", "http://localhost:8088"],
    "method": ["PUT", "GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

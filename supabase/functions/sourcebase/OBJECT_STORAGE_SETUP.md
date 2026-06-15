# SourceBase Object Storage Edge Configuration

This setup is server-side only. Do not pass these values to Flutter build args.

## Required Environment

Set these on the Coolify/Supabase service that hosts the `sourcebase` Edge
Function:

```bash
STORAGE_DRIVER=s3
S3_ENDPOINT=https://nbg1.your-objectstorage.com
S3_REGION=nbg1
S3_BUCKET=medasistorage
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
SOURCEBASE_ALLOWED_ORIGIN=https://sourcebase.medasi.com.tr
```

## Object Naming

SourceBase files live under the app-owned prefix:

```text
sourcebase/users/{userId}/uploads/{yyyy}/{mm}/{uuid}-{safeFileName}
sourcebase/users/{userId}/profile/{uuid}-{safeFileName}
sourcebase/users/{userId}/generated/infographics/{jobId}.{extension}
```

## CORS

The bucket must allow SourceBase clients to send browser `PUT` uploads to signed
URLs:

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

## Runtime Check

Call the `runtime_config` action with an authenticated user token. It returns
only booleans and provider names, never secret values.

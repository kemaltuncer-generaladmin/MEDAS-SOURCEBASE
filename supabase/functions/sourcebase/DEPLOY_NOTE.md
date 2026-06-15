# sourcebase edge function (live)

This is the **live, deployed** Supabase edge function that is the real SourceBase
backend (the apps call `${SUPABASE_URL}/functions/v1/sourcebase`). Pulled from
the running self-hosted Supabase edge-runtime on 2026-06-15.

Depends on `../_shared/appstore_jws.ts` and the function-root `import_map.json`
(both included). Secrets are read from `Deno.env` at runtime — none are stored
here.

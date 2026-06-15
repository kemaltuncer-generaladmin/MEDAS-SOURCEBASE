import { GenerationType } from "../types.ts";

export type AiPipelineStatus =
  | "received"
  | "queued"
  | "processing"
  | "provider_start"
  | "provider_done"
  | "output_saved"
  | "completed"
  | "failed";

export function logAiPipeline(event: {
  action: string;
  status: AiPipelineStatus;
  jobId?: string;
  jobType?: GenerationType | string;
  provider?: string;
  model?: string;
  errorCode?: string;
}) {
  console.log(JSON.stringify({
    event: "sourcebase_ai_pipeline",
    action: event.action,
    job_id: event.jobId,
    job_type: event.jobType,
    status: event.status,
    provider: event.provider,
    model: event.model,
    error_code: event.errorCode,
  }));
}

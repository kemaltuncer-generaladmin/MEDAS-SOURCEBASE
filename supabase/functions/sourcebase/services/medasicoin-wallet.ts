import { SafeError } from "../types.ts";
import { formatMc, McPricingQuote } from "./medasicoin-pricing.ts";

export interface WalletConfig {
  supabaseUrl: string;
  serviceRoleKey: string;
}

export interface WalletBalance {
  balance_units: number;
  balance_mc: number;
}

export async function getWalletBalance(
  config: WalletConfig,
  userId: string,
): Promise<WalletBalance> {
  const synced = await walletRpc(config, "sync_wallet_profile", {
    p_user_id: userId,
  });
  const balanceMc = moneyNumber(synced?.wallet_balance);
  return balanceFromMc(balanceMc);
}

export async function reserveMedasiCoin(input: {
  config: WalletConfig;
  userId: string;
  jobId?: string;
  quote: McPricingQuote;
  reason: string;
}) {
  const before = await getWalletBalance(input.config, input.userId);
  if (before.balance_units < input.quote.amount_units) {
    throw new SafeError(
      "INSUFFICIENT_MC",
      `Yetersiz MedasiCoin bakiyesi. Gerekli: ${
        formatMc(input.quote.amount_units)
      } MC.`,
      402,
    );
  }
  const afterMc = await walletRpc(input.config, "consume_ai_credits", {
    p_user_id: input.userId,
    p_amount: unitsToMc(input.quote.amount_units),
  });
  const after = balanceFromMc(moneyNumber(afterMc));
  return {
    balance_before: before.balance_mc,
    balance_after_reserve: after.balance_mc,
    reserved_mc: unitsToMc(input.quote.amount_units),
  };
}

export async function captureMedasiCoin(input: {
  config: WalletConfig;
  userId: string;
  jobId?: string;
  reason: string;
  metadata?: Record<string, unknown>;
}) {
  await getWalletBalance(input.config, input.userId);
}

export async function refundMedasiCoin(input: {
  config: WalletConfig;
  userId: string;
  jobId?: string;
  amountUnits: number;
  reason: string;
  metadata?: Record<string, unknown>;
}) {
  if (input.amountUnits <= 0) return;
  await walletRpc(input.config, "refund_ai_credits", {
    p_user_id: input.userId,
    p_amount: unitsToMc(input.amountUnits),
  });
}

function unitsToMc(units: number) {
  return Math.round(units) / 100;
}

function moneyNumber(value: unknown) {
  const numberValue = Number(value ?? 0);
  return Number.isFinite(numberValue) ? Math.round(numberValue * 100) / 100 : 0;
}

function balanceFromMc(balanceMc: number): WalletBalance {
  return {
    balance_units: Math.round(balanceMc * 100),
    balance_mc: balanceMc,
  };
}

async function walletRpc(
  config: WalletConfig,
  rpcName: string,
  body: Record<string, unknown>,
) {
  const response = await walletFetch(config, `rpc/${rpcName}`, {
    method: "POST",
    body: JSON.stringify(body),
  });
  return await response.json().catch(() => null);
}

async function walletFetch(
  config: WalletConfig,
  path: string,
  init: RequestInit = {},
) {
  const response = await fetch(`${config.supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: config.serviceRoleKey,
      authorization: `Bearer ${config.serviceRoleKey}`,
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    console.error("Wallet operation failed:", response.status);
    if (
      response.status === 400 &&
      body.toLowerCase().includes("not sufficient")
    ) {
      throw new SafeError(
        "INSUFFICIENT_MC",
        "Yetersiz MedasiCoin bakiyesi.",
        402,
      );
    }
    throw new SafeError(
      "WALLET_ERROR",
      "MedasiCoin işlemi tamamlanamadı.",
      500,
    );
  }
  return response;
}

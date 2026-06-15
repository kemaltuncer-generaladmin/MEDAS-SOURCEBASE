import {
  getWalletBalance,
  refundMedasiCoin,
  reserveMedasiCoin,
} from "./medasicoin-wallet.ts";
import type { McPricingQuote } from "./medasicoin-pricing.ts";

Deno.test("wallet uses ecosystem RPCs instead of sourcebase wallet ledger", async () => {
  const calls: Array<{ url: string; body: Record<string, unknown> }> = [];
  await withFetch(async (url, init) => {
    const body = init && "body" in init ? init.body : undefined;
    calls.push({
      url: url.toString(),
      body: JSON.parse(body?.toString() || "{}"),
    });
    if (url.toString().endsWith("/rpc/sync_wallet_profile")) {
      return jsonResponse({ wallet_balance: 1500 });
    }
    if (url.toString().endsWith("/rpc/consume_ai_credits")) {
      return jsonResponse(1499.4);
    }
    if (url.toString().endsWith("/rpc/refund_ai_credits")) {
      return jsonResponse(1500);
    }
    return jsonResponse({ message: "unexpected" }, 404);
  }, async () => {
    const config = {
      supabaseUrl: "https://medasi.test",
      serviceRoleKey: "service-role",
    };
    const userId = "00000000-0000-4000-8000-000000000001";
    const quote = {
      amount_units: 60,
      final_mc_cost: 0.6,
    } as McPricingQuote;

    const balance = await getWalletBalance(config, userId);
    const reservation = await reserveMedasiCoin({
      config,
      userId,
      quote,
      reason: "test",
    });
    await refundMedasiCoin({
      config,
      userId,
      amountUnits: quote.amount_units,
      reason: "test_refund",
    });

    assertEquals(balance.balance_mc, 1500);
    assertEquals(reservation.balance_after_reserve, 1499.4);
    assert(
      calls.every((call) => !call.url.includes("wallet_transactions")),
      "old sourcebase wallet ledger should not be called",
    );
    assert(
      calls.some((call) => call.url.endsWith("/rpc/consume_ai_credits")),
      "consume_ai_credits RPC should be used",
    );
    const consumeCall = calls.find((call) =>
      call.url.endsWith("/rpc/consume_ai_credits")
    );
    assertEquals(consumeCall?.body.p_amount, 0.6);
  });
});

async function withFetch(
  fetchImpl: typeof fetch,
  run: () => Promise<void>,
) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = fetchImpl;
  try {
    await run();
  } finally {
    globalThis.fetch = originalFetch;
  }
}

function jsonResponse(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}

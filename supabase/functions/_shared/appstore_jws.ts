import { Buffer } from "node:buffer";
import { compactVerify } from "npm:jose@5.9.6";
import { X509Certificate as PeculiarX509 } from "npm:@peculiar/x509@1.12.3";
import { defaultAppleRootCertificates } from "./apple_root_certificates.ts";

// Shared StoreKit 2 signed-transaction (JWS) verifier.
//
// Mirrors the proven logic in `praticase-storekit-verify`: walk the embedded
// x5c chain back to a trusted Apple root, then verify the JWS signature with the
// leaf key. Pure-JS (jose + @peculiar/x509) because the Supabase Edge Runtime's
// node:crypto X509 stub is incomplete. The caller is responsible for checking
// bundleId / productId on the returned payload.

type JsonMap = Record<string, unknown>;

/// Apple root anchors: env override (comma-separated base64) or the bundled set.
export function appleRootCertificates(): Buffer[] {
  const encoded = (Deno.env.get("PRATICASE_APPLE_ROOT_CA_CERTIFICATES_BASE64") ??
    Deno.env.get("APPLE_ROOT_CA_CERTIFICATES_BASE64") ?? "").trim();
  if (encoded) {
    const parsed = encoded
      .split(",")
      .map((certificate) => certificate.trim())
      .filter(Boolean)
      .map((certificate) => Buffer.from(certificate, "base64"));
    if (parsed.length > 0) return parsed;
  }
  return defaultAppleRootCertificates();
}

/// Verify an Apple-signed JWS and return its decoded payload.
export async function verifyAndDecodeAppleJws(
  jws: string,
  rootCertificates: Buffer[],
): Promise<JsonMap> {
  const parts = jws.split(".");
  if (parts.length !== 3) {
    throw new Error("Malformed JWS: expected 3 segments");
  }
  const header = JSON.parse(b64UrlDecode(parts[0])) as {
    alg?: string;
    x5c?: unknown;
  };
  if (header.alg !== "ES256") {
    throw new Error(`Unsupported JWS algorithm: ${header.alg}`);
  }
  if (!Array.isArray(header.x5c) || header.x5c.length === 0) {
    throw new Error("JWS header missing x5c certificate chain");
  }
  const chain = (header.x5c as string[]).map((b64) => {
    const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    return new PeculiarX509(der);
  });

  // 1) Each cert must be signed by the next in the chain.
  for (let i = 0; i < chain.length - 1; i++) {
    const ok = await chain[i].verify({
      publicKey: await chain[i + 1].publicKey.export(),
    });
    if (!ok) {
      throw new Error(`Chain link ${i} is not signed by the next certificate`);
    }
  }

  // 2) The final cert must byte-equal one of the trusted Apple roots.
  const rootDer = new Uint8Array(chain[chain.length - 1].rawData);
  const trusted = rootCertificates.some((apple) =>
    bytesEqual(rootDer, new Uint8Array(apple))
  );
  if (!trusted) {
    throw new Error(
      "Certificate chain does not terminate at a trusted Apple root",
    );
  }

  // 3) Verify the JWS itself with the leaf certificate's public key.
  const leafKey = await chain[0].publicKey.export();
  let payloadBytes: Uint8Array;
  try {
    const result = await compactVerify(jws, leafKey, { algorithms: ["ES256"] });
    payloadBytes = result.payload;
  } catch (error) {
    throw new Error(
      `JWS signature failed leaf verification: ${
        error instanceof Error ? error.message : String(error)
      }`,
    );
  }

  return JSON.parse(new TextDecoder().decode(payloadBytes)) as JsonMap;
}

function b64UrlDecode(segment: string): string {
  const padLength = segment.length % 4 === 0 ? 0 : 4 - (segment.length % 4);
  const base64 = segment.replace(/-/g, "+").replace(/_/g, "/") +
    "=".repeat(padLength);
  return new TextDecoder().decode(
    Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)),
  );
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

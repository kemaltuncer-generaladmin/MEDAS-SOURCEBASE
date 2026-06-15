import { validateInfographicSpec } from "./schema-validator.ts";

Deno.test("validateInfographicSpec accepts panel based output variants", () => {
  const spec = validateInfographicSpec({
    headline: "Akut Koroner Sendrom",
    panels: [
      {
        title: "İlk 10 dakika",
        points: [
          "12 derivasyonlu EKG çek.",
          "Aspirin kontrendikasyonunu kontrol et.",
        ],
      },
      {
        label: "Risk",
        description: "ST elevasyonu acil reperfüzyon gerektirir.",
      },
    ],
  });

  assertEquals(spec.title, "Akut Koroner Sendrom");
  assertEquals(spec.sections.length, 2);
  assertEquals(spec.sections[0].heading, "İlk 10 dakika");
  assertEquals(
    spec.sections[1].bullets[0],
    "ST elevasyonu acil reperfüzyon gerektirir.",
  );
});

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}

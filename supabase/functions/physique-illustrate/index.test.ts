import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { stub } from "https://deno.land/std@0.224.0/testing/mock.ts";
import { handlePhysiqueIllustrateRequest } from "./index.ts";
import {
  allowlistedMuscleDisplayNames,
  buildPhysiqueIllustratePrompt,
  type PhysiqueIllustrateRequest,
  validatePhysiqueIllustrateRequest,
} from "../_shared/physiqueIllustrateSchemas.ts";

const sampleImageBase64 = btoa("fake-jpeg-bytes");

function sampleRequest(): PhysiqueIllustrateRequest {
  return {
    assessmentId: crypto.randomUUID(),
    imageBase64: sampleImageBase64,
    priorityMuscles: ["lateralDelts", "lats"],
    directionGenericLabels: ["Classic athletic"],
  };
}

function illustrateRequest(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("http://localhost/physique-illustrate", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

Deno.test("rejects missing auth", async () => {
  const prior = Deno.env.get("OPENAI_API_KEY");
  Deno.env.set("OPENAI_API_KEY", "test-key");
  try {
    const response = await handlePhysiqueIllustrateRequest(illustrateRequest(sampleRequest()));
    assertEquals(response.status, 401);
  } finally {
    if (prior) Deno.env.set("OPENAI_API_KEY", prior);
    else Deno.env.delete("OPENAI_API_KEY");
  }
});

Deno.test("rejects missing OPENAI_API_KEY", async () => {
  const prior = Deno.env.get("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_API_KEY");
  try {
    const response = await handlePhysiqueIllustrateRequest(
      illustrateRequest(sampleRequest(), { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 503);
    const payload = await response.json();
    assertMatch(payload.error, /OPENAI_API_KEY/i);
  } finally {
    if (prior) Deno.env.set("OPENAI_API_KEY", prior);
  }
});

Deno.test("validate rejects empty image", () => {
  assertEquals(
    validatePhysiqueIllustrateRequest({
      assessmentId: crypto.randomUUID(),
      imageBase64: "",
      priorityMuscles: ["lateralDelts"],
      directionGenericLabels: [],
    }),
    "imageBase64 is required.",
  );
});

Deno.test("validate filters unknown muscles and caps at 3", () => {
  const body: PhysiqueIllustrateRequest = {
    assessmentId: crypto.randomUUID(),
    imageBase64: sampleImageBase64,
    priorityMuscles: [
      "lateralDelts",
      "unknownMuscle",
      "lats",
      "upperChest",
      "traps",
      "chest",
    ],
    directionGenericLabels: [],
  };
  assertEquals(validatePhysiqueIllustrateRequest(body), null);
  assertEquals(allowlistedMuscleDisplayNames(body.priorityMuscles), [
    "Lateral Delts",
    "Lats",
    "Upper Chest",
  ]);

  assertEquals(
    validatePhysiqueIllustrateRequest({
      assessmentId: crypto.randomUUID(),
      imageBase64: sampleImageBase64,
      priorityMuscles: ["unknownMuscle", "alsoBad"],
      directionGenericLabels: [],
    }),
    "priorityMuscles must include at least one allowlisted muscle.",
  );
});

Deno.test("validate rejects banned direction labels", () => {
  assertEquals(
    validatePhysiqueIllustrateRequest({
      assessmentId: crypto.randomUUID(),
      imageBase64: sampleImageBase64,
      priorityMuscles: ["lateralDelts"],
      directionGenericLabels: ["You look like Brad Pitt"],
    }),
    "directionGenericLabels contains disallowed content.",
  );
});

Deno.test("prompt excludes celebrity names and includes subtle emphasis rules", () => {
  const prompt = buildPhysiqueIllustratePrompt({
    priorityMuscles: ["lateralDelts", "lats"],
    directionGenericLabels: ["Classic athletic"],
  });
  assertMatch(prompt, /subtle/i);
  assertMatch(prompt, /not a prediction|illustration/i);
  assertEquals(prompt.toLowerCase().includes("brad"), false);
  assertEquals(prompt.toLowerCase().includes("pitt"), false);
  assertMatch(prompt, /Lateral Delts/i);
  assertMatch(prompt, /Classic athletic/i);
});

Deno.test("handler returns image when OpenAI stubbed", async () => {
  const priorKey = Deno.env.get("OPENAI_API_KEY");
  const priorUrl = Deno.env.get("SUPABASE_URL");
  const priorAnon = Deno.env.get("SUPABASE_ANON_KEY");
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const stubImageB64 = btoa("generated-png-bytes");
  let openaiCallCount = 0;

  const fetchStub = stub(globalThis, "fetch", (input, init) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        new Response(JSON.stringify({ id: "user-1", aud: "authenticated" }), { status: 200 }),
      );
    }
    if (url.includes("api.openai.com/v1/images/edits")) {
      openaiCallCount += 1;
      assertEquals(init?.method, "POST");
      const headers = init?.headers as Record<string, string> | Headers | undefined;
      const auth = headers instanceof Headers
        ? headers.get("Authorization")
        : headers?.Authorization;
      assertEquals(auth, "Bearer test-key");
      return Promise.resolve(new Response(JSON.stringify({
        data: [{ b64_json: stubImageB64 }],
      }), { status: 200 }));
    }
    return Promise.resolve(new Response("unexpected", { status: 500 }));
  });

  try {
    const response = await handlePhysiqueIllustrateRequest(
      illustrateRequest(sampleRequest(), { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 200);
    assertEquals(openaiCallCount, 1);
    const payload = await response.json();
    assertEquals(payload.imageBase64, stubImageB64);
    assertEquals(payload.contentType, "image/png");
  } finally {
    fetchStub.restore();
    if (priorKey) Deno.env.set("OPENAI_API_KEY", priorKey);
    else Deno.env.delete("OPENAI_API_KEY");
    if (priorUrl) Deno.env.set("SUPABASE_URL", priorUrl);
    else Deno.env.delete("SUPABASE_URL");
    if (priorAnon) Deno.env.set("SUPABASE_ANON_KEY", priorAnon);
    else Deno.env.delete("SUPABASE_ANON_KEY");
  }
});

Deno.test("handler OPTIONS returns ok", async () => {
  const response = await handlePhysiqueIllustrateRequest(
    new Request("http://localhost", { method: "OPTIONS" }),
  );
  assertEquals(response.status, 200);
  assertEquals(await response.text(), "ok");
});

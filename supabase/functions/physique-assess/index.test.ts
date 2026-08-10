import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { stub } from "https://deno.land/std@0.224.0/testing/mock.ts";
import { handlePhysiqueAssessRequest, json } from "./index.ts";
import type { PhysiqueAssessRequest } from "../_shared/physiqueSchemas.ts";

function sampleMetrics() {
  return {
    poseConfidence: 0.8,
    lightingScore: 0.75,
    framingScore: 0.8,
    shoulderWidthEstimate: 1.2,
    waistWidthEstimate: 0.9,
    hipWidthEstimate: 1.0,
    shoulderWaistRatio: 1.35,
    postureNotes: [],
    comparisonSummary: null,
    limitations: [],
  };
}

function sampleRequest(): PhysiqueAssessRequest {
  return {
    metrics: {
      front: sampleMetrics(),
      back: { ...sampleMetrics(), shoulderWaistRatio: null },
    },
    anglesAvailable: ["front", "back"],
    profile: {
      goal: "buildMuscle",
      experienceLevel: "intermediate",
      limitations: [],
    },
  };
}

function physiqueRequest(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("http://localhost/physique-assess", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

const validAssessment = {
  photoQuality: {
    anglesAvailable: ["front", "back"],
    lightingQuality: "Even",
    overallConfidence: 0.72,
  },
  physique: {
    overallArchetype: "Athletic build with moderate shoulder-to-waist contrast",
    frameSize: "Medium",
    shoulderToWaist: "Moderate contrast",
    waist: "Defined",
    torso: "Balanced",
    muscularity: "Moderate",
    leanness: "Moderate",
  },
  muscleEntries: [
    {
      muscle: "lateralDelts",
      current: "Moderate side delt development",
      priorityRank: 1,
      notes: "Visible from front angle",
      confidence: "high",
    },
  ],
  developmentPriorities: [
    { muscle: "lateralDelts", reason: "Side delt width improves shoulder line." },
  ],
  trainingBias: {
    preferredMuscleGroups: ["shoulders", "back", "chest"],
    rationale: "Prioritize shoulder width and back width.",
  },
  limitations: ["Visual estimate only — not a medical assessment."],
  confidenceBands: {
    high: ["Front shoulder line"],
    medium: ["Back lat spread"],
    low: [],
  },
  whyTodaySummary: "Bias shoulders and back for frame balance.",
};

Deno.test("json helper sets CORS and content type", async () => {
  const response = json({ ok: true }, 201);
  assertEquals(response.status, 201);
  assertEquals(response.headers.get("Content-Type"), "application/json");
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  assertEquals(await response.json(), { ok: true });
});

Deno.test("handlePhysiqueAssessRequest OPTIONS returns ok", async () => {
  const response = await handlePhysiqueAssessRequest(
    new Request("http://localhost", { method: "OPTIONS" }),
  );
  assertEquals(response.status, 200);
  assertEquals(await response.text(), "ok");
});

Deno.test("handlePhysiqueAssessRequest returns 503 without OpenAI key", async () => {
  const prior = Deno.env.get("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_API_KEY");
  try {
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(sampleRequest(), { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 503);
    const payload = await response.json();
    assertMatch(payload.error, /OPENAI_API_KEY/i);
  } finally {
    if (prior) Deno.env.set("OPENAI_API_KEY", prior);
  }
});

Deno.test("handlePhysiqueAssessRequest returns 401 without Authorization", async () => {
  const prior = Deno.env.get("OPENAI_API_KEY");
  Deno.env.set("OPENAI_API_KEY", "test-key");
  try {
    const response = await handlePhysiqueAssessRequest(physiqueRequest(sampleRequest()));
    assertEquals(response.status, 401);
  } finally {
    if (prior) Deno.env.set("OPENAI_API_KEY", prior);
    else Deno.env.delete("OPENAI_API_KEY");
  }
});

Deno.test("handlePhysiqueAssessRequest returns 400 for missing back metrics", async () => {
  const priorKey = Deno.env.get("OPENAI_API_KEY");
  const priorUrl = Deno.env.get("SUPABASE_URL");
  const priorAnon = Deno.env.get("SUPABASE_ANON_KEY");
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const fetchStub = stub(globalThis, "fetch", (input) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(new Response(JSON.stringify({ id: "user-1" }), { status: 200 }));
    }
    return Promise.resolve(new Response("unexpected", { status: 500 }));
  });

  try {
    const body = sampleRequest();
    // @ts-expect-error intentional invalid payload for validation test
    delete body.metrics.back;
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(body, { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 400);
    const payload = await response.json();
    assertMatch(payload.error, /metrics\.front and metrics\.back/i);
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

Deno.test("handlePhysiqueAssessRequest returns 401 for invalid Supabase user", async () => {
  const priorKey = Deno.env.get("OPENAI_API_KEY");
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const fetchStub = stub(globalThis, "fetch", (input) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        new Response(JSON.stringify({ error: "invalid" }), { status: 401 }),
      );
    }
    return Promise.resolve(new Response("unexpected", { status: 500 }));
  });

  try {
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(sampleRequest(), { Authorization: "Bearer bad" }),
    );
    assertEquals(response.status, 401);
  } finally {
    fetchStub.restore();
    if (priorKey) Deno.env.set("OPENAI_API_KEY", priorKey);
    else Deno.env.delete("OPENAI_API_KEY");
  }
});

Deno.test("handlePhysiqueAssessRequest returns 502 when OpenAI fails", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const fetchStub = stub(globalThis, "fetch", (input) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        new Response(JSON.stringify({ id: "user-1", aud: "authenticated" }), { status: 200 }),
      );
    }
    if (url.includes("api.openai.com")) {
      return Promise.resolve(new Response("provider down", { status: 500 }));
    }
    return Promise.resolve(new Response("[]", { status: 200 }));
  });

  try {
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(sampleRequest(), { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 502);
  } finally {
    fetchStub.restore();
  }
});

Deno.test("handlePhysiqueAssessRequest returns valid assessment payload", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const fetchStub = stub(globalThis, "fetch", (input) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        new Response(JSON.stringify({ id: "user-1", aud: "authenticated" }), { status: 200 }),
      );
    }
    if (url.includes("api.openai.com")) {
      return Promise.resolve(new Response(JSON.stringify({
        choices: [{ message: { content: JSON.stringify(validAssessment) } }],
      }), { status: 200 }));
    }
    return Promise.resolve(new Response("[]", { status: 200 }));
  });

  try {
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(sampleRequest(), { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 200);
    const payload = await response.json();
    assertEquals(payload.developmentPriorities[0].muscle, "lateralDelts");
    assertEquals(payload.source, undefined);
  } finally {
    fetchStub.restore();
  }
});

Deno.test("handlePhysiqueAssessRequest returns 502 for empty AI content", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const fetchStub = stub(globalThis, "fetch", (input) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        new Response(JSON.stringify({ id: "user-1", aud: "authenticated" }), { status: 200 }),
      );
    }
    if (url.includes("api.openai.com")) {
      return Promise.resolve(new Response(JSON.stringify({ choices: [{}] }), { status: 200 }));
    }
    return Promise.resolve(new Response("[]", { status: 200 }));
  });

  try {
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(sampleRequest(), { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 502);
  } finally {
    fetchStub.restore();
  }
});

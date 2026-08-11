import {
  assertEquals,
  assertMatch,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { stub } from "https://deno.land/std@0.224.0/testing/mock.ts";
import { handlePhysiqueAssessRequest, json } from "./index.ts";
import {
  buildPhysiqueSystemPrompt,
  type PhysiqueAssessRequest,
  PHYSIQUE_ASSESS_RESPONSE_SCHEMA,
} from "../_shared/physiqueSchemas.ts";

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

function sampleAllowedArchetypes() {
  return [
    { id: "classic_athletic", genericLabel: "Classic athletic", tags: ["lean", "athletic"] },
    { id: "lean_fighter", genericLabel: "Lean fighter", tags: ["lean", "compact"] },
    { id: "mens_physique", genericLabel: "Men's physique direction", tags: ["v_taper"] },
  ];
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
    allowedArchetypes: sampleAllowedArchetypes(),
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
  physiqueDirections: [
    {
      archetypeId: "classic_athletic",
      rank: 1,
      similarityDimension: "Moderate V-taper with defined shoulders",
      confidence: "high",
    },
    {
      archetypeId: "lean_fighter",
      rank: 2,
      similarityDimension: "Compact lean silhouette",
      confidence: "medium",
    },
  ],
};

Deno.test("PHYSIQUE_ASSESS_RESPONSE_SCHEMA requires physiqueDirections", () => {
  assertEquals(
    PHYSIQUE_ASSESS_RESPONSE_SCHEMA.required.includes("physiqueDirections"),
    true,
  );
  const directionItem = PHYSIQUE_ASSESS_RESPONSE_SCHEMA.properties.physiqueDirections.items;
  assertEquals(directionItem.required, ["archetypeId", "rank", "similarityDimension", "confidence"]);
});

Deno.test("handlePhysiqueAssessRequest returns 400 without allowedArchetypes", async () => {
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
    delete body.allowedArchetypes;
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(body, { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 400);
    const payload = await response.json();
    assertMatch(payload.error, /allowedArchetypes/i);
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

Deno.test("handlePhysiqueAssessRequest returns 400 for empty allowedArchetypes", async () => {
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
    body.allowedArchetypes = [];
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(body, { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 400);
    const payload = await response.json();
    assertMatch(payload.error, /allowedArchetypes/i);
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

Deno.test("handlePhysiqueAssessRequest filters unknown physique direction ids", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const assessmentWithUnknown = {
    ...validAssessment,
    physiqueDirections: [
      ...validAssessment.physiqueDirections,
      {
        archetypeId: "not_in_catalog",
        rank: 3,
        similarityDimension: "Unknown silhouette",
        confidence: "low",
      },
    ],
  };

  const fetchStub = stub(globalThis, "fetch", (input) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        new Response(JSON.stringify({ id: "user-1", aud: "authenticated" }), { status: 200 }),
      );
    }
    if (url.includes("api.openai.com")) {
      return Promise.resolve(new Response(JSON.stringify({
        choices: [{ message: { content: JSON.stringify(assessmentWithUnknown) } }],
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
    assertEquals(payload.physiqueDirections.length, 2);
    assertEquals(
      payload.physiqueDirections.every((d: { archetypeId: string }) =>
        sampleAllowedArchetypes().some((a) => a.id === d.archetypeId)
      ),
      true,
    );
    assertEquals(
      payload.physiqueDirections.some((d: { archetypeId: string }) => d.archetypeId === "not_in_catalog"),
      false,
    );
  } finally {
    fetchStub.restore();
  }
});

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

Deno.test("handlePhysiqueAssessRequest accepts front-only metrics", async () => {
  const priorKey = Deno.env.get("OPENAI_API_KEY");
  const priorUrl = Deno.env.get("SUPABASE_URL");
  const priorAnon = Deno.env.get("SUPABASE_ANON_KEY");
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
        choices: [{ message: { content: JSON.stringify({
          ...validAssessment,
          photoQuality: {
            ...validAssessment.photoQuality,
            anglesAvailable: ["front"],
          },
        }) } }],
      }), { status: 200 }));
    }
    return Promise.resolve(new Response("[]", { status: 200 }));
  });

  try {
    const body = sampleRequest();
    delete body.metrics.back;
    body.anglesAvailable = ["front"];
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(body, { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 200);
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

Deno.test("handlePhysiqueAssessRequest returns 400 when back listed without metrics", async () => {
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
    delete body.metrics.back;
    body.anglesAvailable = ["front", "back"];
    const response = await handlePhysiqueAssessRequest(
      physiqueRequest(body, { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 400);
    const payload = await response.json();
    assertMatch(payload.error, /back/i);
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
    assertEquals(payload.physiqueDirections.length, 2);
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

Deno.test("handlePhysiqueAssessRequest returns generic 500 on handler failure", async () => {
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
    return Promise.resolve(new Response("[]", { status: 200 }));
  });

  try {
    const response = await handlePhysiqueAssessRequest(
      new Request("http://localhost/physique-assess", {
        method: "POST",
        headers: {
          Authorization: "Bearer token",
          "Content-Type": "application/json",
        },
        body: "{not-json",
      }),
    );
    assertEquals(response.status, 500);
    const payload = await response.json();
    assertEquals(payload.error, "Internal server error.");
  } finally {
    fetchStub.restore();
  }
});

Deno.test("buildPhysiqueSystemPrompt forbids inventing back metrics without back angle", () => {
  const prompt = buildPhysiqueSystemPrompt();
  assertStringIncludes(prompt, 'anglesAvailable lacks "back"');
});

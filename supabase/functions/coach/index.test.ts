import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { stub } from "https://deno.land/std@0.224.0/testing/mock.ts";
import { handleCoachRequest, json } from "./index.ts";
import type { CoachContextPayload } from "../_shared/schemas.ts";

function sampleContext(): CoachContextPayload {
  return {
    userProfile: {
      goal: "buildMuscle",
      experienceLevel: "intermediate",
      proteinGoalGrams: 160,
    },
    recentWorkouts: [],
    exerciseStats: [],
    proteinSummary: { todayGrams: 80, goalGrams: 160, streakDays: 1 },
    recovery: {},
    limitations: [],
    allowedExerciseIds: ["bench_press", "dumbbell_press", "push_up", "cable_fly"],
    availableEquipment: ["barbell"],
    targetDurationMinutes: 45,
  };
}

function coachRequest(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("http://localhost/coach", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

Deno.test("json helper sets CORS and content type", async () => {
  const response = json({ ok: true }, 201);
  assertEquals(response.status, 201);
  assertEquals(response.headers.get("Content-Type"), "application/json");
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  assertEquals(await response.json(), { ok: true });
});

Deno.test("handleCoachRequest OPTIONS returns ok", async () => {
  const response = await handleCoachRequest(new Request("http://localhost", { method: "OPTIONS" }));
  assertEquals(response.status, 200);
  assertEquals(await response.text(), "ok");
});

Deno.test("handleCoachRequest returns 503 without OpenAI key", async () => {
  const prior = Deno.env.get("OPENAI_API_KEY");
  Deno.env.delete("OPENAI_API_KEY");
  try {
    const response = await handleCoachRequest(
      coachRequest({ message: "hi", context: sampleContext() }, { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 503);
    const payload = await response.json();
    assertMatch(payload.error, /OPENAI_API_KEY/i);
  } finally {
    if (prior) Deno.env.set("OPENAI_API_KEY", prior);
  }
});

Deno.test("handleCoachRequest returns 401 without Authorization", async () => {
  const prior = Deno.env.get("OPENAI_API_KEY");
  Deno.env.set("OPENAI_API_KEY", "test-key");
  try {
    const response = await handleCoachRequest(
      coachRequest({ message: "hi", context: sampleContext() }),
    );
    assertEquals(response.status, 401);
  } finally {
    if (prior) Deno.env.set("OPENAI_API_KEY", prior);
    else Deno.env.delete("OPENAI_API_KEY");
  }
});

Deno.test("handleCoachRequest returns 400 for empty message", async () => {
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
    const response = await handleCoachRequest(
      coachRequest({ message: "   ", context: sampleContext() }, { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 400);
    const payload = await response.json();
    assertMatch(payload.error, /message is required/i);
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

Deno.test("handleCoachRequest returns 401 for invalid Supabase user", async () => {
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
    const response = await handleCoachRequest(
      coachRequest({ message: "hello", context: sampleContext() }, { Authorization: "Bearer bad" }),
    );
    assertEquals(response.status, 401);
  } finally {
    fetchStub.restore();
    if (priorKey) Deno.env.set("OPENAI_API_KEY", priorKey);
    else Deno.env.delete("OPENAI_API_KEY");
  }
});

Deno.test("handleCoachRequest returns 502 when OpenAI fails", async () => {
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
    const response = await handleCoachRequest(
      coachRequest({ message: "explain workout", context: sampleContext() }, {
        Authorization: "Bearer token",
      }),
    );
    assertEquals(response.status, 502);
  } finally {
    fetchStub.restore();
  }
});

Deno.test("handleCoachRequest strips invalid proposed workout", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const invalidWorkout = {
    intent: "modifyWorkout",
    content: "Here is a shorter session.",
    proposedWorkout: {
      title: "Too Small",
      estimatedDurationMinutes: 20,
      focus: ["chest"],
      rationale: "test",
      safetyNotes: [],
      exercises: [
        { exerciseId: "bench_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
      ],
    },
    safetyNotes: [],
  };

  const fetchStub = stub(globalThis, "fetch", (input, init) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        new Response(JSON.stringify({ id: "user-1", aud: "authenticated" }), { status: 200 }),
      );
    }
    if (url.includes("api.openai.com")) {
      return Promise.resolve(new Response(JSON.stringify({
        choices: [{ message: { content: JSON.stringify(invalidWorkout) } }],
      }), { status: 200 }));
    }
    if (url.includes("/rest/v1/coach_messages") && init?.method === "POST") {
      return Promise.resolve(new Response("[]", { status: 201 }));
    }
    return Promise.resolve(new Response("[]", { status: 200 }));
  });

  try {
    const response = await handleCoachRequest(
      coachRequest({ message: "make it shorter", context: sampleContext() }, {
        Authorization: "Bearer token",
      }),
    );
    assertEquals(response.status, 200);
    const payload = await response.json();
    assertEquals(payload.proposedWorkout, null);
    assertMatch(payload.content, /Could not apply workout changes/i);
    assertEquals(payload.validation?.isValid, false);
  } finally {
    fetchStub.restore();
  }
});

Deno.test("handleCoachRequest returns valid workout when proposal passes validation", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "anon-key");

  const validWorkout = {
    intent: "modifyWorkout",
    content: "Compressed session ready.",
    proposedWorkout: {
      title: "Upper Push",
      estimatedDurationMinutes: 40,
      focus: ["chest"],
      rationale: "test",
      safetyNotes: [],
      exercises: [
        { exerciseId: "bench_press", sets: [{ targetRepsMin: 6, targetRepsMax: 8 }] },
        { exerciseId: "dumbbell_press", sets: [{ targetRepsMin: 8, targetRepsMax: 10 }] },
        { exerciseId: "push_up", sets: [{ targetRepsMin: 10, targetRepsMax: 12 }] },
        { exerciseId: "cable_fly", sets: [{ targetRepsMin: 12, targetRepsMax: 15 }] },
      ],
    },
    safetyNotes: [],
  };

  const fetchStub = stub(globalThis, "fetch", (input, init) => {
    const url = String(input);
    if (url.includes("/auth/v1/user")) {
      return Promise.resolve(
        new Response(JSON.stringify({ id: "user-1", aud: "authenticated" }), { status: 200 }),
      );
    }
    if (url.includes("api.openai.com")) {
      return Promise.resolve(new Response(JSON.stringify({
        choices: [{ message: { content: JSON.stringify(validWorkout) } }],
      }), { status: 200 }));
    }
    if (url.includes("/rest/v1/coach_messages") && init?.method === "POST") {
      return Promise.resolve(new Response("[]", { status: 201 }));
    }
    return Promise.resolve(new Response("[]", { status: 200 }));
  });

  try {
    const response = await handleCoachRequest(
      coachRequest({ message: "adjust workout", context: sampleContext() }, {
        Authorization: "Bearer token",
      }),
    );
    assertEquals(response.status, 200);
    const payload = await response.json();
    assertEquals(payload.proposedWorkout?.title, "Upper Push");
    assertEquals(payload.validation?.isValid, true);
  } finally {
    fetchStub.restore();
  }
});

Deno.test("handleCoachRequest returns 502 for empty AI content", async () => {
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
    const response = await handleCoachRequest(
      coachRequest({ message: "hello", context: sampleContext() }, { Authorization: "Bearer token" }),
    );
    assertEquals(response.status, 502);
  } finally {
    fetchStub.restore();
  }
});

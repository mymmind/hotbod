// Paste this entire file into Supabase Dashboard → Edge Functions → coach → index.ts
// Dashboard: https://supabase.com/dashboard/project/sikeiypsiewbznqwynpd/functions
// Enable "Verify JWT". Add secret OPENAI_API_KEY under Edge Functions → Secrets.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const COACH_RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["intent", "content", "proposedWorkout", "safetyNotes"],
  properties: {
    intent: {
      type: "string",
      enum: [
        "explainWorkout",
        "modifyWorkout",
        "generateWorkout",
        "analyzePlateau",
        "proteinHelp",
        "progressPhotoInsight",
        "generalTrainingQuestion",
        "motivation",
        "unknown",
      ],
    },
    content: { type: "string" },
    proposedWorkout: {
      anyOf: [
        { type: "null" },
        {
          type: "object",
          additionalProperties: false,
          required: ["title", "estimatedDurationMinutes", "focus", "exercises", "rationale", "safetyNotes"],
          properties: {
            title: { type: "string" },
            estimatedDurationMinutes: { type: "number" },
            focus: { type: "array", items: { type: "string" } },
            rationale: { type: "string" },
            safetyNotes: { type: "array", items: { type: "string" } },
            exercises: {
              type: "array",
              items: {
                type: "object",
                additionalProperties: false,
                required: ["exerciseId", "sets"],
                properties: {
                  exerciseId: { type: "string" },
                  reason: { type: "string" },
                  restSeconds: { type: "number" },
                  sets: {
                    type: "array",
                    items: {
                      type: "object",
                      additionalProperties: false,
                      required: ["targetRepsMin", "targetRepsMax"],
                      properties: {
                        targetRepsMin: { type: "number" },
                        targetRepsMax: { type: "number" },
                        targetWeightKg: { type: "number" },
                        rpeTarget: { type: "number" },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      ],
    },
    safetyNotes: { type: "array", items: { type: "string" } },
  },
};

function validateWorkout(workout: any, context: any) {
  const errors: string[] = [];
  const warnings: string[] = [];
  const allowed = new Set(context.allowedExerciseIds ?? []);
  const seen = new Set<string>();

  if (!workout.exercises || workout.exercises.length < 4) {
    errors.push("Workout has fewer than 4 exercises.");
  }

  for (const planned of workout.exercises ?? []) {
    if (seen.has(planned.exerciseId)) errors.push(`Duplicate exercise: ${planned.exerciseId}`);
    seen.add(planned.exerciseId);
    if (!allowed.has(planned.exerciseId)) {
      errors.push(`Unknown or disallowed exercise: ${planned.exerciseId}`);
    }
    for (const set of planned.sets ?? []) {
      if (set.targetRepsMin < 1 || set.targetRepsMax > 30 || set.targetRepsMin > set.targetRepsMax) {
        errors.push(`Invalid rep range for ${planned.exerciseId}.`);
      }
    }
  }

  const totalSets = (workout.exercises ?? []).reduce((sum: number, ex: any) => sum + (ex.sets?.length ?? 0), 0);
  if (totalSets > 30) warnings.push(`High total set count (${totalSets}).`);
  if (workout.estimatedDurationMinutes > (context.targetDurationMinutes ?? 45) + 20) {
    warnings.push("Workout may exceed target duration.");
  }
  if (context.limitations?.includes("severe")) {
    warnings.push("Severe soreness context — reduce intensity.");
  }

  return { isValid: errors.length === 0, errors, warnings };
}

function buildSystemPrompt(context: any): string {
  const exerciseList = (context.allowedExerciseIds ?? []).slice(0, 120).join(", ");
  return `You are HotBod coach — a premium strength training assistant.

RULES:
- Never diagnose injuries or prescribe medical rehab.
- Never invent exercises. Only use exerciseId values from ALLOWED_EXERCISES.
- Never claim exact body fat from photos.
- No steroid or drug advice.
- Be direct, non-cheesy, brutalist tone. Short paragraphs.
- When modifying or generating workouts, output proposedWorkout JSON matching schema.
- Keep sets/reps sane (1-30 reps). Respect equipment and limitations.
- For explain/protein/plateau questions, set proposedWorkout to null.

ALLOWED_EXERCISES: ${exerciseList}

AVAILABLE_EQUIPMENT: ${(context.availableEquipment ?? []).join(", ")}
TARGET_DURATION_MINUTES: ${context.targetDurationMinutes ?? 45}
LIMITATIONS: ${(context.limitations ?? []).join(", ") || "none"}
GOAL: ${context.userProfile?.goal ?? "buildMuscle"}
EXPERIENCE: ${context.userProfile?.experienceLevel ?? "intermediate"}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const openaiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openaiKey) {
      return json({ error: "OPENAI_API_KEY not configured on server." }, 503);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header." }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: "Unauthorized." }, 401);
    }

    const body = await req.json();
    if (!body.message?.trim()) {
      return json({ error: "message is required." }, 400);
    }

    const systemPrompt = buildSystemPrompt(body.context);
    const userPayload = JSON.stringify({
      message: body.message,
      context: {
        currentWorkout: body.context?.currentWorkout,
        recovery: body.context?.recovery,
        proteinSummary: body.context?.proteinSummary,
        recentWorkouts: body.context?.recentWorkouts?.slice(0, 5),
        exerciseStats: body.context?.exerciseStats?.slice(0, 20),
      },
    });

    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini",
        temperature: 0.4,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "coach_response",
            strict: true,
            schema: COACH_RESPONSE_SCHEMA,
          },
        },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPayload },
        ],
      }),
    });

    if (!openaiResponse.ok) {
      const errText = await openaiResponse.text();
      console.error("OpenAI error:", errText);
      return json({ error: "AI provider error." }, 502);
    }

    const completion = await openaiResponse.json();
    const rawContent = completion?.choices?.[0]?.message?.content;
    if (!rawContent) {
      return json({ error: "Empty AI response." }, 502);
    }

    const parsed = JSON.parse(rawContent);
    let validation = null;

    if (parsed.proposedWorkout) {
      validation = validateWorkout(parsed.proposedWorkout, body.context);
      if (!validation.isValid) {
        parsed.proposedWorkout = null;
        parsed.content += `\n\nCould not apply workout changes: ${validation.errors.join(" ")}`;
        parsed.safetyNotes = [...(parsed.safetyNotes ?? []), ...validation.errors];
      } else if (validation.warnings.length > 0) {
        parsed.safetyNotes = [...(parsed.safetyNotes ?? []), ...validation.warnings];
      }
    }

    const userId = userData.user.id;
    await supabase.from("coach_messages").insert([
      { user_id: userId, role: "user", content: body.message },
      { user_id: userId, role: "assistant", content: parsed.content, intent: parsed.intent },
    ]);

    return json({
      intent: parsed.intent,
      content: parsed.content,
      proposedWorkout: parsed.proposedWorkout ?? null,
      safetyNotes: parsed.safetyNotes ?? [],
      validation,
    });
  } catch (error) {
    console.error(error);
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  type CoachRequest,
  type CoachResponsePayload,
  COACH_RESPONSE_SCHEMA,
} from "../_shared/schemas.ts";
import { buildSystemPrompt, validateWorkout } from "../_shared/validate.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

    const body = (await req.json()) as CoachRequest;
    if (!body.message?.trim()) {
      return json({ error: "message is required." }, 400);
    }

    const systemPrompt = buildSystemPrompt(body.context);
    const userPayload = JSON.stringify({
      message: body.message,
      context: {
        currentWorkout: body.context.currentWorkout,
        recovery: body.context.recovery,
        proteinSummary: body.context.proteinSummary,
        recentWorkouts: body.context.recentWorkouts?.slice(0, 5),
        exerciseStats: body.context.exerciseStats?.slice(0, 20),
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

    const parsed = JSON.parse(rawContent) as CoachResponsePayload;
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

    // Persist coach exchange (best-effort)
    const userId = userData.user.id;
    await supabase.from("coach_messages").insert([
      { user_id: userId, role: "user", content: body.message },
      {
        user_id: userId,
        role: "assistant",
        content: parsed.content,
        intent: parsed.intent,
      },
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

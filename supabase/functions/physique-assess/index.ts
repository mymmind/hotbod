import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  buildPhysiqueSystemPrompt,
  type PhysiqueAssessRequest,
  type PhysiqueAssessResponsePayload,
  PHYSIQUE_ASSESS_RESPONSE_SCHEMA,
  validatePhysiqueRequest,
} from "../_shared/physiqueSchemas.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export async function handlePhysiqueAssessRequest(req: Request): Promise<Response> {
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

    const body = (await req.json()) as PhysiqueAssessRequest;
    const validationError = validatePhysiqueRequest(body);
    if (validationError) {
      return json({ error: validationError }, 400);
    }

    const systemPrompt = buildPhysiqueSystemPrompt();
    const userPayload = JSON.stringify({
      metrics: body.metrics,
      anglesAvailable: body.anglesAvailable,
      profile: {
        goal: body.profile.goal,
        experienceLevel: body.profile.experienceLevel,
        limitations: body.profile.limitations ?? [],
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
        temperature: 0.3,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "physique_assessment",
            strict: true,
            schema: PHYSIQUE_ASSESS_RESPONSE_SCHEMA,
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
      console.error("OpenAI physique-assess error:", errText.slice(0, 500));
      return json({ error: "AI provider error." }, 502);
    }

    const completion = await openaiResponse.json();
    const rawContent = completion?.choices?.[0]?.message?.content;
    if (!rawContent) {
      return json({ error: "Empty AI response." }, 502);
    }

    const parsed = JSON.parse(rawContent) as PhysiqueAssessResponsePayload;
    return json(parsed);
  } catch (error) {
    console.error("physique-assess handler error:", error instanceof Error ? error.message : error);
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
}

if (import.meta.main) {
  Deno.serve(handlePhysiqueAssessRequest);
}

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  buildPhysiqueIllustratePrompt,
  decodeIllustrateImage,
  type PhysiqueIllustrateRequest,
  sanitizedIllustrateInput,
  validatePhysiqueIllustrateRequest,
} from "../_shared/physiqueIllustrateSchemas.ts";

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

export async function handlePhysiqueIllustrateRequest(req: Request): Promise<Response> {
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

    const body = (await req.json()) as PhysiqueIllustrateRequest;
    const validationError = validatePhysiqueIllustrateRequest(body);
    if (validationError) {
      return json({ error: validationError }, 400);
    }

    const { priorityMuscles, directionGenericLabels } = sanitizedIllustrateInput(body);
    const prompt = buildPhysiqueIllustratePrompt({ priorityMuscles, directionGenericLabels });
    const imageBlob = new Blob([decodeIllustrateImage(body.imageBase64)], { type: "image/jpeg" });

    const formData = new FormData();
    formData.append("model", Deno.env.get("OPENAI_IMAGE_MODEL") ?? "gpt-image-1");
    formData.append("image", imageBlob, "front.jpg");
    formData.append("prompt", prompt);
    formData.append("size", "1024x1024");

    const openaiResponse = await fetch("https://api.openai.com/v1/images/edits", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openaiKey}`,
      },
      body: formData,
    });

    if (!openaiResponse.ok) {
      const errText = await openaiResponse.text();
      console.error("OpenAI physique-illustrate error:", errText.slice(0, 500));
      return json({ error: "AI provider error." }, 502);
    }

    const completion = await openaiResponse.json();
    const imageBase64 = completion?.data?.[0]?.b64_json;
    if (!imageBase64) {
      return json({ error: "Empty AI response." }, 502);
    }

    return json({
      imageBase64,
      contentType: "image/png",
    });
  } catch (error) {
    console.error("physique-illustrate handler error:", error instanceof Error ? error.message : error);
    return json({ error: "Internal server error." }, 500);
  }
}

if (import.meta.main) {
  Deno.serve(handlePhysiqueIllustrateRequest);
}

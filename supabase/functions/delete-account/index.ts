import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

export async function handleDeleteAccountRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing Authorization header." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "Server misconfigured." }, 503);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "Unauthorized." }, 401);
  }

  const userId = userData.user.id;
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  try {
    const storageError = await removeBodyProgressStorage(adminClient, userId);
    if (storageError) {
      return json({ error: storageError }, 500);
    }

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) {
      return json({ error: deleteError.message }, 500);
    }

    return json({ success: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Delete failed.";
    return json({ error: message }, 500);
  }
}

export async function removeBodyProgressStorage(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
): Promise<string | null> {
  const { data: objects, error: listError } = await adminClient.storage
    .from("body-progress")
    .list(userId);

  if (listError) {
    console.error("delete-account storage list failed", listError.message);
    return `Failed to list stored photos: ${listError.message}`;
  }

  if (!objects?.length) {
    return null;
  }

  const paths = objects.map((object) => `${userId}/${object.name}`);
  const { error: removeError } = await adminClient.storage
    .from("body-progress")
    .remove(paths);

  if (removeError) {
    console.error("delete-account storage remove failed", removeError.message);
    return `Failed to delete stored photos: ${removeError.message}`;
  }

  return null;
}

if (import.meta.main) {
  Deno.serve(handleDeleteAccountRequest);
}

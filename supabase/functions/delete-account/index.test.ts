import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleDeleteAccountRequest, json } from "./index.ts";

Deno.test("delete-account OPTIONS returns ok", async () => {
  const response = await handleDeleteAccountRequest(
    new Request("http://localhost/delete-account", { method: "OPTIONS" }),
  );
  assertEquals(response.status, 200);
});

Deno.test("delete-account rejects missing auth header", async () => {
  const response = await handleDeleteAccountRequest(
    new Request("http://localhost/delete-account", { method: "POST" }),
  );
  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body.error, "Missing Authorization header.");
});

Deno.test("delete-account json helper sets content type", async () => {
  const response = json({ success: true });
  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Content-Type"), "application/json");
});

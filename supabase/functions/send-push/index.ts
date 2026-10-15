import { createClient } from "npm:@supabase/supabase-js@2.99.1";
// @deno-types="npm:@types/web-push@3.6.4"
import webpush from "npm:web-push@3.6.7";
import { isPushEndpoint, validateMessage } from "./validation.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (status: number, body: object) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST") return json(405, { error: "Use POST." });
  try {
    const required = (name: string) => {
      const value = Deno.env.get(name);
      if (!value) throw new Error(`Missing server configuration: ${name}`);
      return value;
    };
    const client = createClient(required("SUPABASE_URL"), required("SUPABASE_SERVICE_ROLE_KEY"), {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const token = request.headers.get("Authorization")?.match(/^Bearer (.+)$/i)?.[1];
    if (!token) return json(401, { error: "Sign in to send notifications." });
    const { data: { user }, error: authError } = await client.auth.getUser(token);
    if (authError || !user) return json(401, { error: "Invalid or expired session." });
    if (user.app_metadata.role !== "admin") return json(403, { error: "Admin access is required." });

    const appUrl = required("PUSH_APP_URL");
    const base = new URL(appUrl);
    if (base.protocol !== "https:" || !base.pathname.endsWith("/")) {
      throw new Error("PUSH_APP_URL must be an HTTPS URL with a trailing slash.");
    }
    let message;
    try {
      message = validateMessage(await request.json(), appUrl);
    } catch (error) {
      return json(400, { error: error instanceof Error ? error.message : "Invalid notification." });
    }
    webpush.setVapidDetails(required("VAPID_SUBJECT"), required("VAPID_PUBLIC_KEY"), required("VAPID_PRIVATE_KEY"));
    const payload = JSON.stringify(message);
    let sent = 0;
    let failed = 0;
    let removed = 0;
    let cursor: string | undefined;
    // Keyset pagination avoids skipping rows when expired subscriptions are deleted.
    while (true) {
      let query = client.from("web_push_subscriptions").select("id, endpoint, p256dh, auth").order("id").limit(100);
      if (cursor) query = query.gt("id", cursor);
      const { data: subscriptions, error } = await query;
      if (error) throw error;
      if (!subscriptions.length) break;
      for (let offset = 0; offset < subscriptions.length; offset += 10) {
        await Promise.all(subscriptions.slice(offset, offset + 10).map(async (subscription) => {
          if (!isPushEndpoint(subscription.endpoint)) {
            failed++;
            console.error("Unsupported push endpoint for subscription", subscription.id);
            return;
          }
          try {
            await webpush.sendNotification({
              endpoint: subscription.endpoint,
              keys: { p256dh: subscription.p256dh, auth: subscription.auth },
            }, payload, { TTL: 86400, timeout: 10000 });
            sent++;
          } catch (error) {
            const status = error instanceof Error && "statusCode" in error ? error.statusCode : undefined;
            if (status === 404 || status === 410) {
              const { error: deleteError } = await client.from("web_push_subscriptions").delete().eq("id", subscription.id);
              if (deleteError) throw deleteError;
              removed++;
            } else {
              failed++;
              console.error("Push delivery failed", subscription.id, status);
            }
          }
        }));
      }
      cursor = subscriptions[subscriptions.length - 1].id;
    }
    return json(200, { sent, failed, removed });
  } catch (error) {
    console.error("Push broadcast failed", error);
    return json(500, { error: "Broadcast did not complete. Some notifications may already have been sent. Check the function logs before retrying." });
  }
});

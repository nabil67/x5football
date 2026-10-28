// Edge Function `purge-avatars` : supprime les photos des comptes purgés.
//
// Appelée par la tâche planifiée `cleanup-deleted-avatars` (pg_cron + pg_net), jamais par
// l'application. Authentifiée par l'en-tête `x-cleanup-secret` (secret serveur CLEANUP_SECRET),
// d'où `verify_jwt = false` dans config.toml. La clé service_role, fournie par la plateforme,
// ne quitte jamais le serveur.
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { avatarPaths, BUCKET, isAuthorized } from "./cleanup.ts";

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { code: "METHOD_NOT_ALLOWED" });
  if (!isAuthorized(req.headers.get("x-cleanup-secret"), Deno.env.get("CLEANUP_SECRET"))) {
    return json(401, { code: "UNAUTHORIZED" });
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  const { data: userIds, error } = await admin.rpc("claim_storage_cleanup", { p_limit: 20 });
  if (error) {
    console.error("claim_storage_cleanup", error.code);
    return json(500, { code: "SERVER_ERROR" });
  }

  let cleaned = 0;
  let failed = 0;
  for (const userId of (userIds ?? []) as string[]) {
    try {
      const storage = admin.storage.from(BUCKET);
      const { data: files, error: listError } = await storage.list(userId);
      if (listError) throw listError;
      const paths = avatarPaths(userId, files ?? []);
      if (paths.length > 0) {
        const { error: removeError } = await storage.remove(paths);
        if (removeError) throw removeError;
      }
      const { error: doneError } = await admin.rpc("complete_storage_cleanup", { p_user_id: userId });
      if (doneError) throw doneError;
      cleaned++;
    } catch (_) {
      // Reste dans la file : nouvelle tentative au prochain passage.
      failed++;
    }
  }
  return json(200, { cleaned, failed });
});

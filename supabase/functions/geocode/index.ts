// Edge Function `geocode` : convertit une adresse ou un lieu en coordonnées.
//
// POST { "query": "Stade Jean Bouin, Paris" } → { "places": [{ name, label, latitude, longitude }] }
// Erreurs : { "code": "...", "message": "..." } avec le statut HTTP correspondant.
//
// L'appel exige un utilisateur connecté actif ; chaque appel au fournisseur consomme son quota
// (RPC consume_geocode_quota, avec le jeton de l'utilisateur : aucune clé secrète n'est utilisée).
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { buildSearchUrl, GeocodeError, normalizeQuery, parsePlaces, type Place } from "./nominatim.ts";

const USER_AGENT = Deno.env.get("GEOCODER_USER_AGENT") ?? "x5football-dev/0.1 (developpement local)";
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const CACHE_MAX_ENTRIES = 500;
const cache = new Map<string, { expiresAt: number; places: Place[] }>();

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function fromCache(key: string): Place[] | undefined {
  const entry = cache.get(key);
  if (!entry) return undefined;
  if (entry.expiresAt < Date.now()) {
    cache.delete(key);
    return undefined;
  }
  return entry.places;
}

function remember(key: string, places: Place[]) {
  if (cache.size >= CACHE_MAX_ENTRIES) cache.delete(cache.keys().next().value!);
  cache.set(key, { expiresAt: Date.now() + CACHE_TTL_MS, places });
}

async function consumeQuota(authorization: string) {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  for (let attempt = 0; ; attempt++) {
    const { error } = await supabase.rpc("consume_geocode_quota");
    if (!error) return;
    // Limite globale d'une requête par seconde : on patiente une fois avant d'abandonner.
    if (error.message === "GEOCODE_BUSY" && attempt === 0) {
      await new Promise((resolve) => setTimeout(resolve, 1100));
      continue;
    }
    const isBusiness = error.code?.startsWith("PT") && error.hint;
    throw new GeocodeError(
      isBusiness ? Number(error.code.slice(2)) : 500,
      isBusiness ? error.message : "SERVER_ERROR",
      isBusiness ? error.hint : "Une erreur est survenue. Réessayez dans un instant.",
    );
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") throw new GeocodeError(405, "METHOD_NOT_ALLOWED", "Méthode non autorisée.");
    const authorization = req.headers.get("Authorization");
    if (!authorization) throw new GeocodeError(401, "AUTH_REQUIRED", "Connectez-vous pour continuer.");

    const body = await req.json().catch(() => ({}));
    const query = normalizeQuery(body?.query);
    const language = body?.language === "en" ? "en" : "fr";
    const key = `${language}:${query.toLowerCase()}`;

    const cached = fromCache(key);
    if (cached) return json(200, { places: cached });

    await consumeQuota(authorization);

    const response = await fetch(buildSearchUrl(query, language), {
      headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) {
      console.error("Nominatim", response.status);
      throw new GeocodeError(503, "GEOCODER_UNAVAILABLE", "La recherche d'adresse est indisponible. Réessayez plus tard.");
    }
    const places = parsePlaces(await response.json());
    remember(key, places);
    return json(200, { places });
  } catch (e) {
    if (e instanceof GeocodeError) return json(e.status, { code: e.code, message: e.message });
    console.error("geocode", e instanceof Error ? e.name : "inconnu");
    return json(503, {
      code: "GEOCODER_UNAVAILABLE",
      message: "La recherche d'adresse est indisponible. Réessayez plus tard.",
    });
  }
});

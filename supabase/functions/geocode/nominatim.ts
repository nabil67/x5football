// Recherche d'adresses via OpenStreetMap Nominatim (gratuit, couverture mondiale).
// Règles d'usage : https://operations.osmfoundation.org/policies/nominatim/
// (1 requête/seconde au plus, User-Agent identifiant l'application, attribution « © OpenStreetMap »,
// pas d'autocomplétion à chaque frappe).

export const NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
export const MAX_RESULTS = 5;

export type Place = {
  /** Nom court (ex. « Stade Jean Bouin »), à proposer comme nom du terrain. */
  name: string;
  /** Adresse complète lisible. */
  label: string;
  latitude: number;
  longitude: number;
};

export class GeocodeError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

/** Valide et normalise la saisie ; lève une GeocodeError 400 si elle est inexploitable. */
export function normalizeQuery(input: unknown): string {
  const query = typeof input === "string"
    ? input.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim()
    : "";
  if (query.length < 3 || query.length > 200) {
    throw new GeocodeError(
      400,
      "INVALID_QUERY",
      "Saisissez une adresse ou un lieu (3 à 200 caractères).",
    );
  }
  return query;
}

export function buildSearchUrl(query: string, language: string): URL {
  const url = new URL(NOMINATIM_URL);
  url.searchParams.set("q", query);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("limit", String(MAX_RESULTS));
  url.searchParams.set("accept-language", language);
  return url;
}

/** Convertit la réponse Nominatim en lieux exploitables, en ignorant les entrées invalides. */
export function parsePlaces(body: unknown): Place[] {
  if (!Array.isArray(body)) return [];
  const places: Place[] = [];
  for (const item of body.slice(0, MAX_RESULTS)) {
    const latitude = Number(item?.lat);
    const longitude = Number(item?.lon);
    const label = typeof item?.display_name === "string" ? item.display_name.trim() : "";
    if (!label || !Number.isFinite(latitude) || !Number.isFinite(longitude)) continue;
    if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) continue;
    // Une ville et sa région portent souvent la même adresse : un seul choix suffit.
    if (places.some((p) => p.label === label)) continue;
    const name = (typeof item?.name === "string" && item.name.trim()) || label.split(",")[0].trim();
    places.push({ name: name.slice(0, 120), label, latitude, longitude });
  }
  return places;
}

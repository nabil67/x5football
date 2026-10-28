// deno test supabase/functions/geocode
import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.13";
import { buildSearchUrl, GeocodeError, normalizeQuery, parsePlaces } from "./nominatim.ts";

Deno.test("la saisie est nettoyée", () => {
  assertEquals(normalizeQuery("  Stade\n Jean   Bouin "), "Stade Jean Bouin");
});

Deno.test("une saisie trop courte, trop longue ou absente est refusée", () => {
  for (const input of ["ab", "x".repeat(201), undefined, 42]) {
    const error = assertThrows(() => normalizeQuery(input), GeocodeError);
    assertEquals(error.status, 400);
    assertEquals(error.code, "INVALID_QUERY");
  }
});

Deno.test("la requête respecte le format et la limite de résultats", () => {
  const url = buildSearchUrl("Tours", "fr");
  assertEquals(url.origin, "https://nominatim.openstreetmap.org");
  assertEquals(url.searchParams.get("q"), "Tours");
  assertEquals(url.searchParams.get("format"), "jsonv2");
  assertEquals(url.searchParams.get("limit"), "5");
  assertEquals(url.searchParams.get("accept-language"), "fr");
});

Deno.test("les résultats sont convertis et les entrées invalides ignorées", () => {
  const places = parsePlaces([
    { lat: "48.8430", lon: "2.2528", name: "Stade Jean Bouin", display_name: "Stade Jean Bouin, Paris, France" },
    { lat: "35.68", lon: "139.76", name: "", display_name: "Tokyo, Japon" },
    { lat: "abc", lon: "2", display_name: "Invalide" },
    { lat: "95", lon: "2", display_name: "Hors limites" },
    { lat: "1", lon: "2" },
  ]);
  assertEquals(places, [
    { name: "Stade Jean Bouin", label: "Stade Jean Bouin, Paris, France", latitude: 48.843, longitude: 2.2528 },
    { name: "Tokyo", label: "Tokyo, Japon", latitude: 35.68, longitude: 139.76 },
  ]);
});

Deno.test("les doublons d'adresse sont retirés", () => {
  const places = parsePlaces([
    { lat: "-22.91", lon: "-43.21", name: "Rio de Janeiro", display_name: "Rio de Janeiro, Brésil" },
    { lat: "-22.5", lon: "-43.0", name: "Rio de Janeiro", display_name: "Rio de Janeiro, Brésil" },
  ]);
  assertEquals(places.length, 1);
  assertEquals(places[0].latitude, -22.91);
});

Deno.test("une réponse inattendue donne une liste vide", () => {
  assertEquals(parsePlaces({ error: "x" }), []);
});

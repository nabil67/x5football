// deno test supabase/functions/purge-avatars
import { assertEquals } from "jsr:@std/assert@1.0.13";
import { avatarPaths, isAuthorized } from "./cleanup.ts";

const secret = "s".repeat(40);

Deno.test("seul le bon secret est accepté", () => {
  assertEquals(isAuthorized(secret, secret), true);
  assertEquals(isAuthorized(secret + "x", secret), false);
  assertEquals(isAuthorized("s".repeat(39), secret), false);
  assertEquals(isAuthorized(null, secret), false);
});

Deno.test("un secret serveur absent ou trop court refuse tout", () => {
  assertEquals(isAuthorized("", undefined), false);
  assertEquals(isAuthorized("court", "court"), false);
});

Deno.test("chemins limités au dossier de la personne", () => {
  assertEquals(
    avatarPaths("u1", [{ name: "avatar-1.jpg" }, { name: "avatar-2.png" }, { name: "" }, { name: "../autre" }]),
    ["u1/avatar-1.jpg", "u1/avatar-2.png"],
  );
});

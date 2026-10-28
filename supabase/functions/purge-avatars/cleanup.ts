// Logique pure de l'Edge Function `purge-avatars` (testée sans réseau).

export const BUCKET = "avatars";

/** Comparaison en temps constant ; un secret absent ou trop court refuse tout. */
export function isAuthorized(provided: string | null, expected: string | undefined): boolean {
  if (!expected || expected.length < 32 || !provided) return false;
  const a = new TextEncoder().encode(provided);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < b.length; i++) diff |= (a[i] ?? 0) ^ b[i];
  return diff === 0;
}

/** Chemins à supprimer dans le dossier personnel `<userId>/`. */
export function avatarPaths(userId: string, files: { name: string }[]): string[] {
  return files.filter((f) => f.name && !f.name.includes("/")).map((f) => `${userId}/${f.name}`);
}

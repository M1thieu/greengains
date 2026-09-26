// Enforces the project's l10n rule: every message key exists in BOTH app_en.arb and app_fr.arb,
// and a translation keeps the same {placeholders} as the English source.
// No dependencies, so it runs on a bare CI runner. Exit code 1 on any violation.
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', 'lib', 'l10n');
const load = (name) => JSON.parse(readFileSync(join(dir, name), 'utf8'));

const en = load('app_en.arb');
const fr = load('app_fr.arb');

// Keys starting with "@" are metadata (descriptions, placeholder types), not messages.
const messages = (arb) => Object.entries(arb).filter(([k]) => !k.startsWith('@'));
const enMessages = new Map(messages(en));
const frMessages = new Map(messages(fr));

const problems = [];
for (const key of enMessages.keys()) if (!frMessages.has(key)) problems.push(`missing in app_fr.arb: ${key}`);
for (const key of frMessages.keys()) if (!enMessages.has(key)) problems.push(`missing in app_en.arb (template): ${key}`);

// A placeholder the English source declares (@key.placeholders) AND uses must also appear in the
// French text; otherwise the user sees a blank or a literal "{count}". (Placeholders a
// translation invents are already rejected by `flutter gen-l10n`, which CI also runs.)
const uses = (text, name) => new RegExp(String.raw`\{\s*${name}\s*[,}]`).test(text);
for (const [key, enText] of enMessages) {
  const frText = frMessages.get(key);
  if (frText === undefined) continue;
  for (const name of Object.keys(en['@' + key]?.placeholders ?? {})) {
    if (uses(enText, name) && !uses(frText, name)) {
      problems.push(`${key}: French does not use declared placeholder {${name}}`);
    }
  }
}

if (problems.length) {
  console.error(`l10n check failed (${problems.length}):`);
  for (const p of problems) console.error(`  - ${p}`);
  process.exit(1);
}
console.log(`l10n OK: ${enMessages.size} messages, EN and FR in sync.`);

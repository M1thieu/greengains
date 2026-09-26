// Runs every src/**/*.test.ts with the built-in node:test runner, via tsx for TypeScript.
//
// A script instead of `tsx --test "src/**/*.test.ts"` because glob expansion differs between
// cmd.exe, bash and Node 20 (which only globs from v21), and this must behave the same on a
// developer's Windows machine and on the CI runner.
import { readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

// Config is validated when a module imports it, so tests need syntactically valid values.
// They are fakes: nothing here opens a connection, and real values in the environment win.
process.env.DATABASE_URL ??= 'postgres://test:test@localhost:5432/test';
process.env.API_KEY ??= 'test-api-key-not-a-secret';
process.env.HASH_SECRET ??= 'test-hash-secret-not-a-secret-0123456789';

const files = readdirSync(join(root, 'src'), { recursive: true })
  .map(String)
  .filter((f) => f.endsWith('.test.ts'))
  .map((f) => join('src', f))
  .sort();

if (files.length === 0) {
  console.error('No *.test.ts files found under src/');
  process.exit(1);
}

const run = spawnSync(process.execPath, ['--import', 'tsx', '--test', ...files], {
  cwd: root,
  stdio: 'inherit',
});
process.exit(run.status ?? 1);

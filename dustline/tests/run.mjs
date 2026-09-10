import { build } from 'esbuild';
import { mkdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
await mkdir('.tests', { recursive: true });
await build({entryPoints:['tests/game.test.ts'],bundle:true,platform:'node',format:'esm',outfile:'.tests/game.test.mjs',logLevel:'silent'});
const result=spawnSync(process.execPath,['--test','.tests/game.test.mjs'],{stdio:'inherit'});
process.exit(result.status ?? 1);

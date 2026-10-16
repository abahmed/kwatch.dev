#!/usr/bin/env node
// Reads the kwatch feature catalog (v2) and writes src/data/feature-tiers.json.
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const sourceIndex = args.indexOf('--source');
const source = sourceIndex >= 0 ? args[sourceIndex + 1] : '../../../kwatch/deploy';
const file = path.join(source, 'feature-catalog.tsv');
const lines = fs.readFileSync(file, 'utf8').split('\n').filter(Boolean);

if (lines[0].trim() !== '# kwatch feature catalog v2') {
  console.error(`${file}: expected "# kwatch feature catalog v2" header`);
  process.exit(1);
}

const features = lines
  .filter((line) => !line.startsWith('#'))
  .map((line) => {
    const [id, lifecycle, description, deps = '', tier] = line.split('|');
    if (!id || !description || !['community', 'pro'].includes(tier)) {
      console.error(`${file}: invalid row: ${line}`);
      process.exit(1);
    }
    return {
      id,
      lifecycle,
      description,
      deps: deps ? deps.split(',') : [],
      tier,
    };
  });

const out = path.resolve('src/data/feature-tiers.json');
fs.mkdirSync(path.dirname(out), {recursive: true});
fs.writeFileSync(out, `${JSON.stringify(features, null, 2)}\n`);
console.log(`wrote ${features.length} features to ${out}`);

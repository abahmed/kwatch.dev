#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const source = process.env.KWATCH_SOURCE;
if (!source) {
  console.error('KWATCH_SOURCE must point to the Kwatch repository');
  process.exit(2);
}

const result = spawnSync(
  process.execPath,
  [
    path.resolve('scripts/generate-kwatch-reference.mjs'),
    '--source',
    path.join(source, 'deploy'),
  ],
  {stdio: 'inherit'},
);
if (result.status !== 0) process.exit(result.status ?? 1);

const required = [
  'configuration.md',
  'providers.md',
  'features.md',
];
for (const file of required) {
  const target = path.resolve('docs/reference/generated', file);
  if (!fs.existsSync(target)) {
    console.error(`missing generated reference page: ${target}`);
    process.exit(1);
  }
}

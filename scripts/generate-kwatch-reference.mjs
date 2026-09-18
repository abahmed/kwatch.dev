#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const sourceIndex = args.indexOf('--source');
const source = sourceIndex >= 0 ? args[sourceIndex + 1] : null;

if (!source) {
  console.error('usage: generate-kwatch-reference.mjs --source <deploy-dir>');
  process.exit(2);
}

const outputRoot = path.resolve('docs/reference/generated');
fs.mkdirSync(outputRoot, {recursive: true});

function readCatalog(name) {
  const file = path.join(source, name);
  const content = fs.readFileSync(file, 'utf8');
  return content
    .split('\n')
    .filter((line) => line && !line.startsWith('#'))
    .map((line) => line.split('|'));
}

function escapeCell(value) {
  return String(value ?? '').replaceAll('|', '\\|').replaceAll('\n', ' ');
}

function codeCell(value) {
  return `\`${escapeCell(value).replaceAll('`', '\\`')}\``;
}

function write(name, content) {
  fs.writeFileSync(path.join(outputRoot, name), `${content.trim()}\n`);
}

const configRows = readCatalog('config-catalog.tsv');
const configByCategory = new Map();
for (const row of configRows) {
  const [field, type, defaultValue, category, description, status] = row;
  if (!configByCategory.has(category)) configByCategory.set(category, []);
  configByCategory.get(category).push({
    field,
    type,
    defaultValue,
    description,
    status,
  });
}

let configuration = `---
title: Configuration reference
description: Generated configuration fields and defaults for kwatch.
sidebar_position: 1
generated: true
---

# Configuration reference

> This page is generated from the Kwatch configuration catalog. Edit the Go
> configuration source and catalog metadata instead of editing this page.

`;
for (const [category, rows] of configByCategory) {
  configuration += `## ${category}\n\n`;
  configuration += '| Field | Type | Default | Status | Description |\n';
  configuration += '| --- | --- | --- | --- | --- |\n';
  for (const row of rows) {
    configuration += `| ${codeCell(row.field)} | ${escapeCell(row.type)} | ${codeCell(row.defaultValue)} | ${escapeCell(row.status)} | ${escapeCell(row.description)} |\n`;
  }
  configuration += '\n';
}
write('configuration.md', configuration);

const providerRows = readCatalog('provider-catalog.tsv');
const providerNames = [...new Set(providerRows.map((row) => row[0]))].sort();
let providers = `---
title: Provider reference
description: Generated notification provider configuration metadata.
sidebar_position: 2
generated: true
---

# Provider reference

> This page is generated from the Kwatch provider catalog. Provider setup
> instructions remain in the provider-specific guides.

`;
for (const provider of providerNames) {
  providers += `## ${provider}\n\n`;
  providers += '| Field | Type | Required | Secret | Default | Description |\n';
  providers += '| --- | --- | --- | --- | --- | --- |\n';
  for (const row of providerRows.filter((item) => item[0] === provider)) {
    const [, displayName, field, type, required, secret, , defaultValue, description] = row;
    providers += `| ${codeCell(field)} | ${escapeCell(type)} | ${escapeCell(required)} | ${escapeCell(secret)} | ${codeCell(defaultValue)} | ${escapeCell(description)} |\n`;
  }
  providers += '\n';
}
write('providers.md', providers);

const featureRows = readCatalog('feature-catalog.tsv');
let features = `---
title: Feature reference
description: Generated Kwatch capability catalog and dependencies.
sidebar_position: 3
generated: true
---

# Feature reference

> This page is generated from the Kwatch feature catalog. Feature IDs are
> stable product vocabulary and should not be renamed without a migration.

| Feature ID | Lifecycle | Description | Dependencies |\n`;
features += '| --- | --- | --- | --- |\n';
for (const [id, lifecycle, description, dependencies = ''] of featureRows) {
  features += `| ${codeCell(id)} | ${escapeCell(lifecycle)} | ${escapeCell(description)} | ${codeCell(dependencies || 'none')} |\n`;
}
write('features.md', features);

console.log(`generated reference pages in ${outputRoot}`);

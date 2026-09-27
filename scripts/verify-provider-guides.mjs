import fs from 'node:fs';
import path from 'node:path';

const directory = path.resolve('docs/channels/provider-guides');
const files = fs.readdirSync(directory).filter((name) => name.endsWith('.md'));
const errors = [];

for (const name of files) {
  const content = fs.readFileSync(path.join(directory, name), 'utf8');
  const example = content.match(/## Minimal example\s+```yaml\n([\s\S]*?)\n```/);
  if (!example) {
    errors.push(`${name}: missing YAML minimal example`);
    continue;
  }

  const required = [...content.matchAll(
    /^\| `([^`]+)` \|[^\n]*?\| yes \| (yes|no) \|/gm,
  )];
  for (const [, field, secret] of required) {
    const line = example[1].split('\n').find((entry) =>
      entry.trimStart().startsWith(`${field}:`),
    );
    if (!line) {
      errors.push(`${name}: minimal example omits required ${field}`);
    } else if (secret === 'yes' && !line.includes('${file:/')) {
      errors.push(`${name}: ${field} needs a file-backed Secret example`);
    }
  }
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}

console.log(`Provider guide verification passed: ${files.length} guides.`);

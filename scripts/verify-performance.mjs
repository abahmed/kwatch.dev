import fs from 'node:fs';
import path from 'node:path';

const buildRoot = path.resolve('build');
const maxJavaScriptBytes = 4 * 1024 * 1024;
const maxSearchIndexBytes = 600 * 1024;

function filesIn(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? filesIn(file) : [file];
  });
}

const scripts = filesIn(path.join(buildRoot, 'assets/js'))
  .filter((file) => file.endsWith('.js'));
const scriptBytes = scripts.reduce((sum, file) =>
  sum + fs.statSync(file).size, 0);
const indexBytes = fs.statSync(path.join(buildRoot, 'search-index.json')).size;

if (scriptBytes > maxJavaScriptBytes) {
  throw new Error(`JavaScript exceeds 4 MiB: ${scriptBytes} bytes`);
}
if (indexBytes > maxSearchIndexBytes) {
  throw new Error(`Search index exceeds 600 KiB: ${indexBytes} bytes`);
}

console.log(
  `Performance budget passed: ${Math.round(scriptBytes / 1024)} KiB JS, ` +
  `${Math.round(indexBytes / 1024)} KiB search index.`,
);

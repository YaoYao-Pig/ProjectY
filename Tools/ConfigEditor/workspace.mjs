import fs from 'node:fs';
import path from 'node:path';
import { emptyCatalog, validateCatalog, validateFolder } from './definitions.mjs';

export function readCatalog(root) {
  const filename = path.join(root, 'Config/Catalog.json');
  return fs.existsSync(filename) ? validateCatalog(JSON.parse(fs.readFileSync(filename, 'utf8'))) : emptyCatalog();
}
export function atomicJson(filename, value) {
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  fs.writeFileSync(filename + '.tmp', JSON.stringify(value, null, 2) + '\n');
  fs.renameSync(filename + '.tmp', filename);
}
export function tableDirectory(root, folder = '') {
  validateFolder(folder);
  const base = path.resolve(root, 'Config/Tables');
  // Do not allow a symlink/junction to redirect source reads or writes outside the workspace.
  for (const directory of [base, ...folder.split('/').filter(Boolean).map((_, i, all) => path.join(base, ...all.slice(0, i + 1)))]) {
    if (fs.existsSync(directory) && fs.lstatSync(directory).isSymbolicLink()) throw new Error('Linked source folders are not supported');
  }
  return path.join(base, folder);
}
export function scanSources(directory) {
  const entries = [], folders = [''];
  if (!fs.existsSync(directory)) return { entries, folders };
  function scan(folder) {
    const current = path.join(directory, folder);
    if (fs.lstatSync(current).isSymbolicLink()) throw new Error('Linked source folders are not supported');
    for (const entry of fs.readdirSync(current, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name, 'en'))) {
      if (entry.isSymbolicLink()) throw new Error(`Linked source files are not supported: ${entry.name}`);
      if (entry.isDirectory()) {
        const child = folder ? folder + '/' + entry.name : entry.name;
        validateFolder(child); folders.push(child); scan(child);
      } else if (entry.name.endsWith('.json')) {
        const filename = path.join(current, entry.name);
        const table = JSON.parse(fs.readFileSync(filename, 'utf8'));
        if (entry.name !== table.name + '.json') throw new Error(`File '${entry.name}' must match table name '${table.name}'`);
        entries.push({ table, folder, filename });
      }
    }
  }
  scan('');
  const keys = new Set();
  for (const folder of folders) {
    if (keys.has(folder.toLowerCase())) throw new Error(`Case-colliding folders: ${folder}`);
    keys.add(folder.toLowerCase());
  }
  return { entries, folders };
}

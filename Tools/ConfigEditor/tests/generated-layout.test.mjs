// 只验证配表目录迁移与清单所有权，不启动 Unity，也不触碰真实工程资产。
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { exportTables, generatedPaths } from '../exporter.mjs';

const inputs = [{ version: 1, name: 'LayoutTest', key: 'id', fields: [{name:'id',type:'int'}], rows: [{id:1}] }];
function workspace(t) {
  const temporary = path.resolve(os.tmpdir()), root = fs.mkdtempSync(path.join(temporary, 'project-y-gen-layout-'));
  t.after(() => {
    assert.equal(path.dirname(path.resolve(root)),temporary);
    assert.ok(path.basename(root).startsWith('project-y-gen-layout-'));
    fs.rmSync(root,{recursive:true,force:true});
  });
  return root;
}
function write(root, relative, value) {
  const filename=path.join(root,relative);fs.mkdirSync(path.dirname(filename),{recursive:true});fs.writeFileSync(filename,value);
}
function legacy(root) {
  const result=exportTables({root,inputs});
  const entries=JSON.parse(fs.readFileSync(path.join(root,generatedPaths.manifest),'utf8'));
  const old=[];
  for (const relative of entries) {
    const destination=relative.replace(generatedPaths.binary,'Assets/GameFramework/Resources/Config').replace(generatedPaths.lua,'Lua/Generated');
    fs.mkdirSync(path.dirname(path.join(root,destination)),{recursive:true});fs.renameSync(path.join(root,relative),path.join(root,destination));old.push(destination);
  }
  fs.rmSync(path.join(root,generatedPaths.manifest));
  write(root,'Config/export-manifest.json',JSON.stringify(old));
  return result;
}

test('export migrates registered outputs and Unity GUIDs into _Gen and remains idempotent', t => {
  const root=workspace(t);legacy(root);
  const meta='fileFormatVersion: 2\nguid: 1234567890abcdef1234567890abcdef\n';
  const folder='fileFormatVersion: 2\nguid: abcdef1234567890abcdef1234567890\nfolderAsset: yes\n';
  write(root,'Assets/GameFramework/Resources/Config/LayoutTest.bytes.meta',meta);
  write(root,'Assets/GameFramework/Resources/Config.meta',folder);
  const bytes=fs.readFileSync(path.join(root,'Assets/GameFramework/Resources/Config/LayoutTest.bytes'));
  const result=exportTables({root,inputs});
  assert.equal(result.written.length,4);
  assert.deepEqual(fs.readFileSync(path.join(root,generatedPaths.binary,'LayoutTest.bytes')),bytes);
  assert.equal(fs.readFileSync(path.join(root,generatedPaths.binary,'LayoutTest.bytes.meta'),'utf8'),meta);
  assert.equal(fs.readFileSync(path.join(root,generatedPaths.binary+'.meta'),'utf8'),folder);
  for (const old of ['Lua/Generated','Assets/GameFramework/Resources/Config','Config/export-manifest.json']) assert.ok(!fs.existsSync(path.join(root,old)));
  const manifest=JSON.parse(fs.readFileSync(path.join(root,generatedPaths.manifest),'utf8'));
  assert.ok(manifest.every(file=>file.includes('/_Gen/')));
  assert.equal(exportTables({root,inputs}).written.length,0);
});

test('migration preserves unregistered files and stale cleanup owns only recorded outputs', t => {
  const root=workspace(t);legacy(root);
  write(root,'Lua/Generated/Manual.lua','return "keep"');
  write(root,'Assets/GameFramework/Resources/Config/manual.txt','keep');
  exportTables({root,inputs});
  assert.equal(fs.readFileSync(path.join(root,'Lua/Generated/Manual.lua'),'utf8'),'return "keep"');
  assert.equal(fs.readFileSync(path.join(root,'Assets/GameFramework/Resources/Config/manual.txt'),'utf8'),'keep');
  write(root,generatedPaths.binary+'/LayoutTest.bytes.meta','original metadata');
  const replacement=structuredClone(inputs);replacement[0].name='Replacement';
  exportTables({root,inputs:replacement});
  assert.ok(!fs.existsSync(path.join(root,generatedPaths.binary,'LayoutTest.bytes')));
  assert.ok(!fs.existsSync(path.join(root,generatedPaths.binary,'LayoutTest.bytes.meta')));
  assert.ok(!fs.existsSync(path.join(root,generatedPaths.lua,'LayoutTest.lua')));
});

test('invalid manifests and conflicting asset identities fail before writing generated data', t => {
  const root=workspace(t);legacy(root);
  const before=fs.readFileSync(path.join(root,'Lua/Generated/LayoutTest.lua'));
  write(root,'Config/export-manifest.json',JSON.stringify(['../outside.lua']));
  assert.throws(()=>exportTables({root,inputs}),/Unsafe generated manifest/);
  assert.deepEqual(fs.readFileSync(path.join(root,'Lua/Generated/LayoutTest.lua')),before);
  assert.ok(!fs.existsSync(path.join(root,generatedPaths.lua,'LayoutTest.lua')));
  write(root,'Config/export-manifest.json',JSON.stringify(['Assets/GameFramework/Resources/Config/LayoutTest.bytes']));
  write(root,'Assets/GameFramework/Resources/Config/LayoutTest.bytes.meta','old identity');
  write(root,generatedPaths.binary+'/LayoutTest.bytes.meta','new identity');
  assert.throws(()=>exportTables({root,inputs}),/Conflicting generated asset metadata/);
  assert.equal(fs.readFileSync(path.join(root,generatedPaths.binary,'LayoutTest.bytes.meta'),'utf8'),'new identity');
});

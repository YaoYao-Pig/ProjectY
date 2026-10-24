import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {parseLanguage} from '../ConfigEditor/language.mjs';
const entries=parseLanguage(fs.readFileSync('Lua/Language.lua','utf8'));
const defaults=new Map(entries.map(row=>[row.id,row.txt]));
const table=JSON.parse(fs.readFileSync('Config/Tables/Localization/LuaTxt.json','utf8'));
const exported=new Map(table.rows.map(row=>[row.id,row.txt]));
const report=JSON.parse(fs.readFileSync('Art/Localization/migration-report.json','utf8'));
for(const row of report.keys)assert(exported.has(row.id),'Missing exported key '+row.id);
const files=[...report.files.map(row=>row.file),'Lua/Game/MapArea/MapAreaSystem.lua','Lua/Game/Battle/GameEffects.lua'];
for(const file of files){
 const source=fs.readFileSync(file,'utf8');
 for(const [,key] of source.matchAll(/LuaLanguage\.([A-Za-z_][A-Za-z0-9_]*)/g))assert(defaults.has(key)&&exported.has(key),file+': missing '+key);
}
// Lua-aware literal scan, excluding comments. Only the existing narrator discriminator is an identity.
function literals(source){
 const result=[];let i=0;
 while(i<source.length){
  if(source.startsWith('--',i)){
   i+=2;const long=source.slice(i).match(/^\[(=*)\[/);
   if(long){const end=source.indexOf(']'+long[1]+']',i+long[0].length);assert(end>=0);i=end+long[1].length+2;}
   else{const end=source.indexOf('\n',i);i=end<0?source.length:end+1;}
   continue;
  }
  if(source[i]==="'"||source[i]==='"'){
   const quote=source[i++],start=i;while(i<source.length){if(source[i]==='\\'){i+=2;continue;}if(source[i]===quote)break;i++;}
   result.push(source.slice(start,i));i++;continue;
  }
  const long=source.slice(i).match(/^\[(=*)\[/);
  if(long){const start=i+long[0].length,end=source.indexOf(']'+long[1]+']',start);assert(end>=0);result.push(source.slice(start,end));i=end+long[1].length+2;continue;}
  i++;
 }
 return result;
}
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?walk(path.join(dir,entry.name)):[path.join(dir,entry.name)]);}
let checked=0;
for(const file of [...walk('Lua/UI'),...walk('Lua/Game/Presentation')].filter(file=>file.endsWith('.lua'))){
 const remaining=literals(fs.readFileSync(file,'utf8')).filter(text=>/[\u3400-\u9fff]/.test(text));
 assert.deepEqual(remaining,file.replaceAll('\\','/')==='Lua/UI/Panel/DialogueCtr.lua'?['旁白']:[],file+' has unlocalized UI literals');checked++;
}
const bindings=JSON.parse(fs.readFileSync('Art/Localization/ui-text-bindings.json','utf8'));
for(const row of bindings)assert(defaults.has(row.id)&&exported.has(row.id),'Missing prefab text key '+row.id);
console.log(`PASS ${checked} UI/presentation Lua sources, ${files.length} migrated source references and ${bindings.length} prefab language keys`);

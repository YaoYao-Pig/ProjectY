// One-off, reviewed UI migration. Parser lives in the temporary tooling directory, not the Unity project.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {createRequire} from 'node:module';
import {parseLanguage} from '../../Tools/ConfigEditor/language.mjs';
const require=createRequire(import.meta.url);
const lua=require(path.join(os.tmpdir(),'project-y-localization-tools/node_modules/luaparse'));
const root=process.cwd(), apply=process.argv.includes('--apply');
const languagePath='Lua/Language.lua', originalLanguage=fs.readFileSync(languagePath,'utf8');
const existing=parseLanguage(originalLanguage), rows=[...existing], ids=new Set(rows.map(r=>r.id));
const byText=new Map(rows.map(r=>[r.txt,r.id]));
const report={files:[],keys:[],skipped:[]};
const han=/[\u3400-\u9fff]/;
function add(text,hint,desc){
  if(byText.has(text))return byText.get(text);
  let base=hint.replace(/[^A-Za-z0-9_]/g,'');if(!/^[A-Za-z]/.test(base))base='UI'+base;
  let id=base,n=2;while(ids.has(id))id=base+n++;
  ids.add(id);byText.set(text,id);const row={id,txt:text,desc};rows.push(row);report.keys.push(row);return id;
}
const supplied=[
 ['DiceRequirement','要求：%s','检定要求，%s 为数值'],['DiceTens','十位','骰子十位标签'],['DiceUnits','个位','骰子个位标签'],
 ['DiceTenths','十分位','骰子小数第一位'],['DiceHundredths','百分位','骰子小数第二位'],
 ['DiceSuccess','检定成功','检定结果'],['DiceFailure','检定失败','检定结果'],
 ['BattleLogExpandedTitle','战斗记录 · {0} 条','C# 格式，{0} 为记录条数'],['BattleLogCollapsedTitle','战斗记录 · 点击展开','战斗日志标题'],
 ['InventorySearching','搜索中…','搜刮物品状态'],['InventoryUnsearched','未搜索','搜刮物品状态'],
 ['InventoryDragLabel','{0}  /  R 旋转','C# 格式，{0} 为拖动物品名'],['SkillTooltipTitle','技能说明','技能浮窗'],
 ['SkillSynergyActive','生效中','技能协同状态'],['SkillSynergyDiscovered','已发现','技能协同状态'],
 ['SkillTooltipScrollHint','滚轮翻阅 · 点击下划线术语查看释义','技能浮窗底部提示'],['SkillTooltipTermHint','点击下划线术语查看释义','技能浮窗底部提示']
];
for(const [id,txt,desc] of supplied){if(ids.has(id))continue;ids.add(id);rows.push({id,txt,desc});report.keys.push({id,txt,desc});byText.set(txt,id);}
function filesIn(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?filesIn(path.join(dir,e.name)):[path.join(dir,e.name)]);}
const files=[...filesIn('Lua/UI').filter(f=>f.endsWith('.lua')&&!f.includes(`${path.sep}Types${path.sep}`)),
 ...filesIn('Lua/Game/Presentation').filter(f=>f.endsWith('.lua')),
 'Lua/Game/Adventure/MainHudModel.lua','Lua/Game/Adventure/InteractionPrompt.lua','Lua/Game/Battle/BattleHUDModel.lua',
 'Lua/Game/Equipment/InventoryModel.lua','Lua/Game/Equipment/EquipmentPresentation.lua','Lua/Game/Camp/CampModel.lua',
 'Lua/Game/Loot/LootModel.lua','Lua/Game/Shop/ShopModel.lua','Lua/Game/Progression/SkillAtlas.lua'];
function children(node){return Object.entries(node).filter(([k])=>!['loc','range','comments','raw'].includes(k)).flatMap(([,v])=>Array.isArray(v)?v:[v]).filter(v=>v&&typeof v==='object'&&typeof v.type==='string');}
function literal(node){
 if(/^\[=*[\[]/.test(node.raw)){const m=node.raw.match(/^\[(=*)\[([\s\S]*)\]\1\]$/);return m[2].replace(/^\r?\n/,'');}
 return parseLanguage('-- @localization-begin\nValue = '+node.raw+'\n-- @localization-end')[0].txt;
}
for(const filename of [...new Set(files)]){
 const source=fs.readFileSync(filename,'utf8');
 const tree=lua.parse(source,{luaVersion:'5.3',ranges:true,locations:true,encodingMode:'none'});
 const parents=new Map();function register(node){for(const c of children(node)){parents.set(c,node);register(c);}}register(tree);
 let count=0;const stem='UI'+path.basename(filename,'.lua').replace(/Ctr$|Model$/,'');
 function hint(node){for(let p=node;p;p=parents.get(p)){
   if(p.type==='TableKeyString')return stem+p.key.name.charAt(0).toUpperCase()+p.key.name.slice(1);
   if(p.type==='AssignmentStatement'||p.type==='LocalStatement'){
    const v=p.variables[0];return stem+source.slice(...v.range).replace(/self\.view\.|self\.|model\.|result\./g,'').split(/[^A-Za-z0-9]+/).map(s=>s.charAt(0).toUpperCase()+s.slice(1)).join('');
   }
  }return stem+'Text';}
 function skip(node){for(let p=node;p;p=parents.get(p)){
  if(p.type==='CallExpression'&&p.base.type==='Identifier'&&['assert','error'].includes(p.base.name))return 'developer diagnostic';
  if(p.type==='BinaryExpression'&&['==','~='].includes(p.operator)&&p.left.type!=='BinaryExpression'&&p.right.type!=='BinaryExpression')return 'identity comparison';
  if(p.type==='TableKey'&&p.key===node)return 'table identity key';
 }return null;}
 function render(node){
  const reason=skip(node);if(reason)return source.slice(...node.range);
  if(node.type==='BinaryExpression'&&node.operator==='..'){
   const parts=[];function flatten(n){if(n.type==='BinaryExpression'&&n.operator==='..'){flatten(n.left);flatten(n.right);}else parts.push(n);}flatten(node);
   if(parts.some(p=>p.type==='StringLiteral'&&han.test(literal(p)))){
    let pattern='',args=[];
    for(const part of parts){if(part.type==='StringLiteral')pattern+=literal(part).replace(/%/g,'%%');else{pattern+='%s';args.push(render(part));}}
    const id=add(pattern,hint(node),filename.replaceAll('\\','/')+':'+node.loc.start.line+'；'+args.map((a,i)=>'%s'+(i+1)+'='+a).join('，'));
    count++;return 'string.format(LuaLanguage.'+id+', '+args.map(a=>'('+a+')').join(', ')+')';
   }
  }
  if(node.type==='StringLiteral'&&han.test(literal(node))){count++;return 'LuaLanguage.'+add(literal(node),hint(node),filename.replaceAll('\\','/')+':'+node.loc.start.line);}
  let text=source.slice(...node.range);
  for(const c of children(node).sort((a,b)=>b.range[0]-a.range[0]))text=text.slice(0,c.range[0]-node.range[0])+render(c)+text.slice(c.range[1]-node.range[0]);
  return text;
 }
 const changes=[];
 function top(node){
  if(skip(node)){if(node.type==='StringLiteral'&&han.test(literal(node)))report.skipped.push({file:filename,line:node.loc.start.line,text:literal(node),reason:skip(node)});return;}
  const transformed=render(node);if(transformed!==source.slice(...node.range))changes.push({range:node.range,text:transformed});
 }
 // Root statements own disjoint ranges, so replacements never corrupt quoted strings or comments.
 for(const statement of tree.body)top(statement);
 if(!changes.length)continue;
 let next=source;for(const change of changes.sort((a,b)=>b.range[0]-a.range[0]))next=next.slice(0,change.range[0])+change.text+next.slice(change.range[1]);
 if(!/^local LuaLanguage\s*=\s*require\(['"]Language['"]\)/m.test(source))next="local LuaLanguage = require('Language')\n"+next;
 lua.parse(next,{luaVersion:'5.3'});
 report.files.push({file:filename.replaceAll('\\','/'),replacements:count});
 if(apply)fs.writeFileSync(filename,next);
}
const bindings=JSON.parse(fs.readFileSync('Art/Localization/ui-text-audit.json','utf8')).map(row=>({...row,
 id:add(row.text,'UI'+path.basename(row.prefab,'.prefab')+row.node.split('/').map(s=>s.replace(/[^A-Za-z0-9]/g,'')).join(''),row.prefab+' / '+row.node)}));
if(apply){
 const added=rows.slice(existing.length).map(row=>'    '+row.id+' = '+JSON.stringify(row.txt)+', -- '+row.desc.replace(/[\r\n]/g,' ')).join('\n')+'\n';
 fs.writeFileSync(languagePath,originalLanguage.replace('-- @localization-end',added+'-- @localization-end'));
 fs.writeFileSync('Art/Localization/ui-text-bindings.json',JSON.stringify(bindings,null,2)+'\n');
}
fs.writeFileSync('Art/Localization/migration-report.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({applied:apply,files:report.files.length,keys:report.keys.length,prefabLabels:bindings.length,skipped:report.skipped.length}));

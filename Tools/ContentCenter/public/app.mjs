import {defaultValue,enumOptions} from '/definitions.mjs';
import {createAuthoring} from '/authoring.mjs';
import {modules,labels,optionalReferences as dynamicRefs} from '/modules.mjs';
import {ModelPreview} from '/preview.mjs';
const $=id=>document.getElementById(id),copy=value=>structuredClone(value);
const el=(tag,text='',className='')=>{const n=document.createElement(tag);n.textContent=text;n.className=className;return n;};
const button=(text,action,className='')=>{const b=el('button',text,className);b.type='button';b.onclick=()=>Promise.resolve().then(action).catch(fail);return b;};
const names={id:'编号',name:'名称',description:'说明',kind:'类型',width:'背包宽度',height:'背包高度',iconMode:'图标来源',iconRotation:'图标旋转',iconPadding:'图标留白',assetId:'模型资源',modelPath:'源模型',prefabPath:'游戏 Prefab',skillIds:'初始 / 授予技能',traitIds:'初始特质',attributeIds:'属性',attributeNames:'属性代码',attributeValues:'属性数值',damageMultiplier:'伤害倍率',level:'等级',requirementId:'属性要求',gripId:'握点',hands:'占用手数',weaponId:'主手武器',offhandWeaponId:'副手武器',wearableIds:'初始防具',appearanceJson:'固定外观',unitId:'角色模板',actorTemplateId:'角色能力模板',townTemplateId:'城镇外观',missionIds:'关联任务线',dialogueIds:'关联对话',recruitable:'允许招募',factionId:'阵营',areaId:'地图区域',facilityId:'设施 / 位置',startMinute:'开始分钟',endMinute:'结束分钟',actionIds:'奖励与动作',conditionId:'显示 / 可用条件',startConditionId:'开始条件',completeConditionId:'完成条件',itemIds:'物品',itemCounts:'数量',categoryId:'武器分类',previewRotation:'工坊预览旋转',previewZoom:'工坊预览缩放',mainPosition:'主握点位置',mainRotation:'主握点旋转',offPosition:'第二握点位置',offRotation:'第二握点旋转',rotationOffset:'专属旋转修正',moduleId:'持握模组',hand:'主 / 副手',iconPath:'2D 图标',costCoins:'价格 / 金币消耗',itemId:'物品',chance:'概率（%）',minCount:'最少数量',maxCount:'最多数量'};
const actionTargets={grant_item:'EquipmentItemTable',recruit_npc:'NpcTable',accept_mission:'MissionTable',claim_mission:'MissionTable',add_relation:'NpcTable',add_reputation:'FactionTable'};
const conditionTargets={mission_state:'MissionTable',quest_state:'QuestTable',item_count:'EquipmentItemTable',kill_count:'CombatUnitTable',npc_relation:'NpcTable',faction_reputation:'FactionTable',npc_recruited:'NpcTable'};
let source,state,selected=null,activeModule='items',activeTable='EquipmentItemTable',tab='edit',drafts=new Map(),previewView,createAction,busy=false,characterUnit=null,assetView,previewSerial=0;
const table=name=>state.tables.find(t=>t.name===name);
const row=(name,id)=>table(name)?.rows.find(r=>r[table(name).key]===id);
const title=(name,r)=>r?.name||r?.text||r?.label||r?.reason||r?.activity||`${labels[name]||name} #${r?.[table(name)?.key]}`;
const key=(name,id)=>JSON.stringify([name,id]);
const nextId=name=>Math.max(0,...table(name).rows.map(r=>r.id))+1;
function notice(message,error=false){$('notice').textContent=message;$('notice').classList.toggle('error',error);}
function fail(error){notice(error.message||String(error),true);if($('wizard').open)$('wizard-status').textContent=error.message||String(error);}
async function api(url,input){const response=await fetch(url,input===undefined?{cache:'no-store'}:{method:'POST',headers:{'Content-Type':'application/json','X-Content-Token':source.token},body:JSON.stringify(input)});const result=await response.json();if(!response.ok)throw Object.assign(new Error(result.error||'请求失败'),{status:response.status});return result;}
function persist(){localStorage.setItem('content-center:'+source.projectId,JSON.stringify({revision:source.revision,drafts:[...drafts]}));updateCount();}
function updateCount(){const n=drafts.size;$('draft-count').textContent=n?`${n} 项未保存`:'已与源表同步';$('save').disabled=busy;$('review').disabled=busy||!n;}
function setBusy(value){busy=value;document.querySelector('main').inert=value;$('modules').inert=value;$('reload').disabled=value;$('resources').disabled=value;updateCount();}
function applyOperation(operation){const t=table(operation.table),id=operation.op==='upsert'?operation.row[t.key]:operation.id,i=t.rows.findIndex(r=>r[t.key]===id);if(operation.op==='delete'){if(i>=0)t.rows.splice(i,1);}else if(i>=0)t.rows[i]=copy(operation.row);else t.rows.push(copy(operation.row));}
function stage(operation){
  const t=table(operation.table),id=operation.op==='upsert'?operation.row[t.key]:operation.id,k=key(t.name,id);
  const before=source.tables.find(t=>t.name===operation.table).rows.find(r=>r[t.key]===id);
  if(operation.op==='delete'&&!before||operation.op==='upsert'&&JSON.stringify(before)===JSON.stringify(operation.row))drafts.delete(k);
  else drafts.set(k,{operation:copy(operation),before:copy(before)});
  applyOperation(operation);persist();
}
function stageRow(name,r){stage({op:'upsert',table:name,row:r});}
function patch(){return {revision:source.revision,operations:[...drafts.values()].map(d=>d.operation)};}
function select(name,id){activeTable=name;selected={table:name,id};history.replaceState(null,'',`/?table=${encodeURIComponent(name)}&id=${encodeURIComponent(id)}&tab=${tab}`);renderLibrary();renderDetail();}
function moduleSelect(id){activeModule=id;selected=null;const m=modules.find(m=>m.id===id);activeTable=m?.tables.find(n=>table(n))||state.tables[0].name;render();}
function render(){renderModules();renderLibrary();renderDetail();updateCount();}
function renderModules(){const root=$('modules');root.replaceChildren();for(const m of [...modules,{id:'all',name:'全部表与扩展',icon:'▦'}]){const b=button('',()=>moduleSelect(m.id),activeModule===m.id?'active':'');b.append(el('span',m.icon),document.createTextNode(m.name));root.append(b);}}
function renderLibrary(){
  const m=modules.find(m=>m.id===activeModule);$('title').textContent=m?.name||'全部表与扩展';$('module-name').textContent=$('title').textContent;$('description').textContent=m?.description||'新表会自动出现在这里，字段、类型与引用来自工程 schema。';
  const names=m?m.tables.filter(n=>table(n)):state.tables.map(t=>t.name);if(!names.includes(activeTable))names.push(activeTable);
  $('table').replaceChildren(...names.map(name=>{const o=el('option',labels[name]||table(name).description||name);o.value=name;return o;}));$('table').value=activeTable;
  const query=$('search').value.toLowerCase(),rows=table(activeTable).rows.filter(r=>JSON.stringify(r).toLowerCase().includes(query));$('total').textContent=`${rows.length} 条内容`;
  $('rows').replaceChildren();for(const r of rows){const id=r[table(activeTable).key],b=button('',()=>select(activeTable,id),'row-card'+(selected?.table===activeTable&&selected.id===id?' active':''));const thumb=el('span','◇','thumb');
    if(r.iconPath){const img=document.createElement('img');img.src='/api/icon?path='+encodeURIComponent(r.iconPath);img.alt='';img.loading='lazy';img.onerror=()=>img.remove();thumb.replaceChildren(img);}
    const content=el('span');content.append(el('b',String(title(activeTable,r)).slice(0,70)),el('small',`${r.kind||labels[activeTable]||activeTable} · #${id}`));b.append(thumb,content);if(drafts.has(key(activeTable,id)))b.append(el('span','●','dirty-dot'));$('rows').append(b);
  }
}
function fieldsRef(name,f,r){return f.ref||dynamicRefs[name]?.[f.name]||(f.name==='targetId'?(name==='NarrativeActionTable'?actionTargets[r.kind]:name==='ConditionTable'?conditionTargets[r.kind]:undefined):undefined);}
let listSerial=0;
function refControl(name,value,onchange,optional=false){
  const box=el('div','','ref-control'),input=document.createElement('input'),list=document.createElement('datalist');list.id='refs-'+(++listSerial);input.setAttribute('list',list.id);input.autocomplete='off';input.placeholder='输入名称或 ID 搜索…';
  const t=table(name),choices=t.rows.map(r=>({id:r[t.key],label:`${title(name,r)} 〔${r[t.key]}〕`}));if(optional)choices.unshift({id:0,label:'无 〔0〕'});
  input.value=choices.find(r=>r.id===value)?.label??String(value);list.append(...choices.map(c=>{const o=document.createElement('option');o.value=c.label;return o;}));
  input.onchange=()=>{const match=choices.find(c=>c.label===input.value||String(c.id)===input.value);if(!match){input.setCustomValidity('请从现有内容中选择');input.reportValidity();return;}input.setCustomValidity('');onchange(match.id);};
  const open=button('↗',()=>{const match=choices.find(c=>c.label===input.value||String(c.id)===input.value);if(match&&(!optional||match.id!==0))select(name,match.id);});open.title='编辑关联内容';box.append(input,list,open);return box;
}
function fieldControl(name,r,f){
  const holder=el('div','',`field${f.type.endsWith('[]')||['text','formula'].includes(f.type)||f.name==='appearanceJson'?' wide':''}`),head=el('div',names[f.name]||f.description?.split(/[；，。]/)[0]||f.name,'field-head');holder.append(head);
  const set=value=>{r[f.name]=value;stageRow(name,r);if(['name','kind'].includes(f.name)){renderLibrary();if(f.name==='kind')renderDetail();}};
  const ref=fieldsRef(name,f,r),optional=!!dynamicRefs[name]?.[f.name];
  const scalar=(type,value,change)=>{
    if(ref)return refControl(ref,value,change,optional);
    if(type==='enum'){const s=document.createElement('select');s.setAttribute('aria-label',names[f.name]||f.description||f.name);for(const option of enumOptions({...f,type:'enum'},state.catalog)){const o=el('option',option.label);o.value=JSON.stringify(option.value);s.append(o);}s.value=JSON.stringify(value);s.onchange=()=>change(JSON.parse(s.value));return s;}
    const n=document.createElement(type==='text'?'textarea':'input');if(type==='bool'){n.type='checkbox';n.checked=value;n.onchange=()=>change(n.checked);}
    else{if(['int','float'].includes(type)){n.type='number';n.required=true;n.step=type==='int'?'1':'any';if(f.min!==undefined)n.min=f.min;if(f.max!==undefined)n.max=f.max;}n.value=value;n.oninput=()=>n.setCustomValidity('');n.onchange=()=>{if(!n.reportValidity())return;if(n.type==='number'){if(n.value===''||!Number.isFinite(n.valueAsNumber)){n.setCustomValidity('请填写完整数值');n.reportValidity();return;}n.setCustomValidity('');change(n.valueAsNumber);}else change(n.value);};}
    n.setAttribute('aria-label',names[f.name]||f.description||f.name);return n;
  };
  if(f.name===table(name).key)holder.append(el('div',String(r[f.name]),'read-only'));
  else if(f.name==='appearanceJson'){
    holder.append(el('p',r[f.name]?'已设置固定外观，可在角色工坊中继续调整。':'沿用外观池随机；可在角色工坊定制。','hint'),button('打开角色工坊',()=>openCharacter(r.unitId)),button('恢复随机外观',()=>{set('');renderDetail();}));
  }else if(f.type.endsWith('[]')){
    const vector=f.type==='float[]'&&/Position$|Rotation$|rotationOffset$|^position$|^rotation$/.test(f.name),list=el('div');
    const draw=()=>{list.replaceChildren();r[f.name].forEach((value,index)=>{const line=el('div','','array-row');if(vector)line.append(el('span',['X','Y','Z'][index]));line.append(scalar(f.type.slice(0,-2),value,v=>{const values=[...r[f.name]];values[index]=v;set(values);}));if(!vector)line.append(button('−',()=>{set(r[f.name].filter((_,i)=>i!==index));draw();}));list.append(line);});};draw();holder.append(list);
    if(!vector)holder.append(button('＋ 添加',()=>{const scalarField={...f,type:f.type.slice(0,-2)};delete scalarField.default;const value=ref?table(ref).rows[0]?.[table(ref).key]:defaultValue(scalarField,state.catalog);if(value===undefined)throw new Error('关联表中没有可选内容');set([...r[f.name],value]);draw();},'array-add'));
  }else holder.append(scalar(f.name==='name'&&f.type==='text'?'string':f.type,r[f.name],set));
  holder.append(el('small',`${f.description||''} · ${f.name}`));return holder;
}
function section(name,r,open=true){const s=el('details','','section');s.open=open;const summary=el('summary',labels[name]||table(name).description||name);summary.append(el('small',`#${r[table(name).key]}`));s.append(summary);const fields=el('div','','fields');for(const f of table(name).fields)fields.append(fieldControl(name,r,f));s.append(fields);return s;}
function linkedRows(name,r){
  const result=[];const add=(t,id)=>{const found=row(t,id);if(found&&!result.some(x=>x.table===t&&x.row===found))result.push({table:t,row:found});};
  if(name==='EquipmentItemTable'){
    const sub={weapon:'EquipmentWeaponTable',wearable:'EquipmentWearableTable',rune:'EquipmentRuneTable',module:'EquipmentRuneTable',magazine:'EquipmentMagazineTable'}[r.kind];if(sub)add(sub,r.id);add('EquipmentAssetTable',r.assetId);
    if(r.kind==='weapon'){const w=row('EquipmentWeaponTable',r.id);if(w){add('EquipmentRequirementTable',w.requirementId);add('EquipmentGripTable',w.gripId);for(const id of w.socketIds)add('EquipmentSocketTable',id);}}
  }
  if(name==='NpcTable'){add('CombatUnitTable',r.actorTemplateId);add('MapAreaTownNpcTable',r.townTemplateId);for(const t of ['GrowthProfileTable','PawnTemplateTable','CharacterLoadoutTable'])for(const v of table(t).rows.filter(v=>v.unitId===r.actorTemplateId))add(t,v.id);for(const t of ['NpcPlacementTable','NpcScheduleTable'])for(const v of table(t).rows.filter(v=>v.npcId===r.id))add(t,v.id);}
  if(name==='CombatUnitTable')for(const t of ['GrowthProfileTable','PawnTemplateTable','CharacterLoadoutTable'])for(const v of table(t).rows.filter(v=>v.unitId===r.id))add(t,v.id);
  if(name==='MissionTable')for(const v of table('QuestTable').rows.filter(v=>v.missionId===r.id))add('QuestTable',v.id);
  if(name==='DialogueTable')for(const v of table('DialogueNodeTable').rows.filter(v=>v.dialogueId===r.id))add('DialogueNodeTable',v.id);
  return result;
}
function renderDetail(){
  previewView?.dispose();previewView=null;previewSerial++;
  const r=selected&&row(selected.table,selected.id);$('empty').hidden=!!r;$('selected').hidden=!r;if(!r)return;
  const name=selected.table;$('record-name').textContent=title(name,r);$('record-type').textContent=labels[name]||name;$('record-id').textContent=`${name} / ${selected.id}`;document.querySelectorAll('[data-tab]').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));const root=$('editor');root.replaceChildren();
  if(tab==='edit'){
    root.append(section(name,r));for(const linked of linkedRows(name,r))root.append(section(linked.table,linked.row,false));
    if(name==='NpcTable'){const actions=el('div','','section-actions');actions.append(button('定制角色外观',()=>openCharacter(r.actorTemplateId)),button('＋ 新建关联对话',()=>newDialogue(r)),button('＋ 新建关联任务',()=>newMission(r)));root.append(actions);}
  }else if(tab==='links')renderLinks(root,name,r);else renderPreview(root,name,r).catch(fail);
}
function references(name,r){
  const out=[];for(const f of table(name).fields){const target=fieldsRef(name,f,r);if(target)for(const id of f.type.endsWith('[]')?r[f.name]:[r[f.name]])if(row(target,id))out.push({table:target,id,field:f.name});}return out;
}
function renderLinks(root,name,r){
  const related=references(name,r),incoming=[];for(const t of state.tables)for(const candidate of t.rows)if(references(t.name,candidate).some(ref=>ref.table===name&&ref.id===r[table(name).key]))incoming.push({table:t.name,id:candidate[t.key]});
  for(const [heading,values] of [['此内容关联',related],['在哪里被使用 / 投放',incoming]]){const block=el('div','','section');block.append(el('h3',heading),el('p',values.length?`${values.length} 项关联`:'尚未关联到其他内容。','hint'));const list=el('div','','link-list');for(const ref of values)list.append(button(`${labels[ref.table]||ref.table} · ${title(ref.table,row(ref.table,ref.id))}${ref.field?' / '+(names[ref.field]||ref.field):''}`,()=>select(ref.table,ref.id)));block.append(list);root.append(block);}
  const actions=el('div','','section-actions');actions.append(button('分析间接影响',async()=>showInsight('间接影响',await api('/api/impact?key='+encodeURIComponent(name+':'+r[table(name).key])))));if(name==='EquipmentItemTable')actions.append(button('＋ 配置投放来源',()=>delivery(r),'primary'));root.append(actions);
}
async function jobResult(job,status){
  status('已提交 Unity，正在处理…');const deadline=Date.now()+125000;
  while(Date.now()<deadline){await new Promise(r=>setTimeout(r,1200));const result=await api('/api/job?id='+job.id);if(result.status==='completed'){status(result.message);return result;}if(['failed','timeout'].includes(result.status))throw new Error(result.message);}
  throw new Error('Unity 操作超时；可检查 Console 后明确重试。');
}
async function loadModel(path,view,status,isCurrent=()=>true){
  let data=await api('/api/preview?path='+encodeURIComponent(path));
  if(!data.ready){const job=await api('/api/preview',{path});await jobResult(job,status);data=await api('/api/preview?path='+encodeURIComponent(path));if(!data.ready)throw new Error('模型依赖已变化，请重新预览');}
  if(isCurrent()){view.show(data);status('Unity 实际网格 · 拖动旋转 / 滚轮缩放');}
}
async function renderPreview(root,name,r){
  const item=name==='EquipmentItemTable'?r:name==='EquipmentWeaponTable'?row('EquipmentItemTable',r.id):null;
  const asset=item?row('EquipmentAssetTable',item.assetId):name==='EquipmentAssetTable'?r:null;
  if(asset){if(item?.kind==='weapon'){const actions=el('div','','preview-actions');actions.append(button('角色持握与握点调整 ↗',()=>openCharacter(null,item.id),'primary'));root.append(actions);}const viewport=el('div','','preview-viewport'),status=el('div','读取模型…','preview-status');root.append(viewport,status);previewView=new ModelPreview(viewport);const serial=previewSerial;loadModel(asset.modelPath,previewView,text=>{if(serial===previewSerial)status.textContent=text;},()=>serial===previewSerial).catch(e=>status.textContent=e.message);
    root.append(el('p',asset.modelPath,'hint'));if(item?.iconPath){const image=document.createElement('img');image.src='/api/icon?path='+encodeURIComponent(item.iconPath);image.className='preview-image';image.alt='当前游戏 2D 图标';image.onerror=()=>{image.replaceWith(el('p','图标尚未生成，保存并导出后由 Unity 从模型生成。','hint'));};root.append(image);}
  }else if(name==='NpcTable'||name==='CombatUnitTable'||name==='CharacterLoadoutTable')root.append(el('p','在真实角色工坊中定制外观，应用后加入此角色的草稿。','hint'),button('打开角色工坊',()=>openCharacter(name==='NpcTable'?r.actorTemplateId:name==='CharacterLoadoutTable'?r.unitId:r.id),'primary'));
  else root.append(el('p','此内容不使用独立 3D 模型，可从关联物品或角色进入预览。','hint'));
}
function openCharacter(unitId,itemId){characterUnit=unitId;$('character-frame').src='/character/?embed=1'+(itemId?'&item='+itemId:'');$('character').showModal();}
window.addEventListener('message',event=>{
  if(event.origin!==location.origin||event.source!==$('character-frame').contentWindow)return;
  try{
    if(event.data?.type==='content-character-ready'){
      const profile=table('CharacterLoadoutTable').rows.find(r=>r.unitId===characterUnit);if(profile?.appearanceJson)event.source.postMessage({type:'content-appearance-load',descriptor:JSON.parse(profile.appearanceJson)},location.origin);
      event.source.postMessage({type:'content-grips-load',rows:table('EquipmentGripTable').rows,adjustments:table('EquipmentHoldAdjustmentTable').rows},location.origin);
    }else if(event.data?.type==='content-appearance'&&characterUnit){let profile=table('CharacterLoadoutTable').rows.find(r=>r.unitId===characterUnit);if(!profile)profile={id:nextId('CharacterLoadoutTable'),unitId:characterUnit,weaponId:0,offhandWeaponId:0,wearableIds:[],appearanceJson:''};stageRow('CharacterLoadoutTable',{...profile,appearanceJson:JSON.stringify(event.data.descriptor)});notice('角色外观已加入草稿；保存并导出后用于 NPC 与招募角色。');}
    else if(event.data?.type==='content-grips')for(const change of event.data.changes){if(change.kind==='grip')stageRow('EquipmentGripTable',change.row);else{const t='EquipmentHoldAdjustmentTable',r=change.row,old=table(t).rows.find(v=>v.weaponId===r.weaponId&&v.moduleId===r.moduleId&&v.hand===r.hand);if(r.rotationOffset===null){if(old)stage({op:'delete',table:t,id:old.id});}else stageRow(t,{...r,id:old?.id??nextId(t)});}}
  }catch(e){fail(e);}
});
$('character').addEventListener('close',()=>{$('character-frame').src='about:blank';renderDetail();});
function wizard(titleText){$('wizard-title').textContent=titleText;$('wizard-body').replaceChildren();$('wizard-status').textContent='';$('create').disabled=false;$('wizard').showModal();return $('wizard-body');}
const textInput=(parent,label,value='')=>{const box=el('div','','field'),input=document.createElement('input');input.value=value;input.setAttribute('aria-label',label);box.append(el('label',label),input);parent.append(box);return input;};
function choose(parent,label,rows){const box=el('div','','field'),select=document.createElement('select');select.setAttribute('aria-label',label);for(const r of rows){const option=el('option',r.label);option.value=r.id;select.append(option);}box.append(el('label',label),select);parent.append(box);return select;}
function addRecipe(result){for(const operation of result.operations)stage(operation);selected=result.selection;activeTable=selected.table;tab='edit';$('wizard').close();render();notice('关联内容已加入草稿，请检查属性与投放后保存并导出。');}
async function newItem(){
  const body=wizard('从 3D 模型新建物品');body.append(el('p','01 选择工程模型 → 02 选择规则原型 → 03 编辑属性与投放','step'));const layout=el('div','','asset-layout'),left=el('div'),right=el('div'),search=textInput(left,'搜索工程模型'),list=el('div','','asset-list'),viewport=el('div','','preview-viewport'),status=el('div','先选择一个已有模型。','preview-status');left.append(list);right.append(viewport,status);layout.append(left,right);body.append(layout);assetView=new ModelPreview(viewport);
  const fields=el('div','','fields');fields.style.marginTop='22px';const name=textInput(fields,'物品名称'),template=choose(fields,'复用哪件物品的规则（独立复制握点与属性要求）',table('EquipmentItemTable').rows.map(r=>({id:r.id,label:`${r.name} · ${r.kind}`})));body.append(fields);
  let modelPath='',sequence=0;const data=await api('/api/assets');const draw=()=>{list.replaceChildren();for(const a of data.assets.filter(a=>a.path.toLowerCase().includes(search.value.toLowerCase()))){const b=button('',()=>{modelPath=a.path;if(!name.value)name.value=a.name.replace(/\.[^.]+$/,'');draw();const current=++sequence;status.textContent='正在获取真实模型…';loadModel(a.path,assetView,t=>{if(current===sequence)status.textContent=t;},()=>current===sequence&&$('wizard').open).catch(e=>status.textContent=e.message);},'asset-row'+(modelPath===a.path?' active':''));b.append(el('b',a.name),el('small',a.path));list.append(b);}};search.oninput=draw;draw();
  createAction=()=>{if(!modelPath)throw new Error('请先选择工程里的模型');addRecipe(createAuthoring(state.tables).item({name:name.value,modelPath,templateId:Number(template.value)}));};
}
function newNpc(){const body=wizard('定制特殊 NPC'),fields=el('div','','fields');body.append(fields);const name=textInput(fields,'角色名称'),template=choose(fields,'能力与外观原型',table('NpcTable').rows.map(r=>({id:r.id,label:r.name}))),area=choose(fields,'投放城镇',table('MapAreaTable').rows.filter(r=>r.areaType===2).map(r=>({id:r.id,label:r.name}))),facility=choose(fields,'初始设施',[]),recruit=choose(fields,'是否可以通过任务 / 对话招募',[{id:'false',label:'仅交互 NPC'},{id:'true',label:'可招募角色'}]);
  const facilities=()=>{const a=row('MapAreaTable',Number(area.value)),town=row('MapAreaTownTable',a.profileId);facility.replaceChildren(...town.facilityIds.map(id=>{const o=el('option',title('MapAreaTownFacilityTable',row('MapAreaTownFacilityTable',id)));o.value=id;return o;}));};area.onchange=facilities;facilities();body.append(el('p','生成独立能力、成长与外观模板，以及完整一天的默认停留日程。创建后可细调日程、装备、特质、任务与对话。招募仍需配置对应动作和条件。','hint'));
  createAction=()=>addRecipe(createAuthoring(state.tables).npc({name:name.value,templateId:Number(template.value),areaId:Number(area.value),facilityId:Number(facility.value),recruitable:recruit.value==='true'}));
}
function newGeneric(name=activeTable,from){const t=table(name),original=from||t.rows[0];let r=original?copy(original):Object.fromEntries(t.fields.map(f=>[f.name,defaultValue(f,state.catalog)]));r[t.key]=t.fields.find(f=>f.name===t.key).type==='int'?nextId(name):`${original?.[t.key]||'new'}_copy`;while(row(name,r[t.key]))r[t.key]+='_copy';if(r.name)r.name+=' · 副本';stageRow(name,r);tab='edit';select(name,r[t.key]);notice('已新建草稿；请修改内容并检查关联，保存前会执行完整校验。');}
function newMission(npc){const t='MissionTable',r=copy(table(t).rows[0]);r.id=nextId(t);r.name=npc.name+'的任务';r.description='';r.actionIds=[];r.autoAccept=false;stageRow(t,r);stageRow('NpcTable',{...npc,missionIds:[...npc.missionIds,r.id]});select(t,r.id);notice('已建立任务关联；请配置开始 / 完成条件和奖励。');}
function newDialogue(npc){
  const dt='DialogueTable',nt='DialogueNodeTable',d=copy(table(dt).rows[0]),n=copy(table(nt).rows[0]);d.id=nextId(dt);n.id=nextId(nt);d.npcId=npc.id;d.entryNodeId=n.id;if('name'in d)d.name=npc.name+'的对话';n.dialogueId=d.id;n.text='请填写对白';n.choiceIds=[];stageRow(dt,d);stageRow(nt,n);stageRow('NpcTable',{...npc,dialogueIds:[...npc.dialogueIds,d.id]});select(dt,d.id);notice('对话和入口节点已关联；请编辑对白与选项。');
}
function delivery(item){const body=wizard('配置投放 · '+item.name),fields=el('div','','fields');body.append(fields);const kind=choose(fields,'投放方式',[{id:'loot',label:'加入掉落池'},{id:'shop',label:'加入现有商店 / 探索选项'},{id:'mission',label:'任务完成奖励'},{id:'starter',label:'初始背包'}]),target=choose(fields,'选择来源',[]),count=textInput(fields,'数量','1');count.type='number';count.min='1';count.step='1';const odds=textInput(fields,'掉落概率（%）','100');odds.type='number';odds.min='0';odds.max='100';
  const types={loot:'LootPoolTable',shop:'AdventureChoiceTable',mission:'MissionTable',starter:'EquipmentDemoTable'};const refresh=()=>{target.replaceChildren(...table(types[kind.value]).rows.map(r=>{const o=el('option',title(types[kind.value],r));o.value=r.id;return o;}));odds.parentElement.hidden=kind.value!=='loot';};kind.onchange=refresh;refresh();
  body.append(el('p','只修改所选来源。商店沿用所选选项的价格与触发条件；任务奖励沿用任务的完成条件。可在关联页继续编辑这些条件。','hint'));
  createAction=()=>{const quantity=Number(count.value);if(!Number.isSafeInteger(quantity)||quantity<1)throw new Error('数量必须为正整数');const id=Number(target.value),name=types[kind.value],r=copy(row(name,id));
    if(kind.value==='loot'){const chance=Number(odds.value);if(!Number.isFinite(chance)||chance<0||chance>100)throw new Error('概率应在 0–100');stageRow('LootEntryTable',{id:nextId('LootEntryTable'),poolId:id,itemId:item.id,chance,minCount:quantity,maxCount:quantity});}
    else if(kind.value==='mission'){const action={...copy(table('NarrativeActionTable').rows[0]),id:nextId('NarrativeActionTable'),kind:'grant_item',targetId:item.id,value:quantity,key:''};stageRow('NarrativeActionTable',action);r.actionIds.push(action.id);stageRow(name,r);}
    else{const a=kind.value==='shop'?'itemIds':'starterItemIds',b=kind.value==='shop'?'itemCounts':'starterCounts';r[a].push(item.id);r[b].push(quantity);stageRow(name,r);}
    $('wizard').close();renderDetail();notice('投放已加入草稿。');};
}
function showInsight(heading,value){$('insight-title').textContent=heading;$('insight-body').replaceChildren(el('pre',typeof value==='string'?value:JSON.stringify(value,null,2)));if(!$('insight').open)$('insight').showModal();}
async function check(){if(!drafts.size)return;const result=await api('/api/review',patch());const body=$('insight-body');body.replaceChildren();$('insight-title').textContent='检查通过 · '+result.changes.length+' 张表';for(const change of result.changes){const d=el('details','','section');d.append(el('summary',labels[change.table]||change.table));const changed=[...drafts.values()].filter(v=>v.operation.table===change.table);for(const entry of changed){d.append(el('h3',`${entry.operation.op==='delete'?'删除':'更新'} #${entry.operation.row?.id??entry.operation.id}`),el('pre',JSON.stringify({before:entry.before,after:entry.operation.row},null,2)));}body.append(d);}for(const warning of result.diagnostics?.warnings||[])body.append(el('p',warning,'hint'));$('insight').showModal();}
async function save(){
  if(busy)return;setBusy(true);
  try{for(const input of $('editor').querySelectorAll('input,select,textarea'))if(!input.reportValidity())throw new Error('请修正未完成的表单字段');const result=await api(drafts.size?'/api/save':'/api/export',drafts.size?patch():{revision:source.revision});if(result.sourceSaved){drafts.clear();localStorage.removeItem('content-center:'+source.projectId);}if(result.sourceSaved||!drafts.size){source=await api('/api/workspace');state=copy(source);render();}
    if(result.error)throw new Error('源表已保存，但导出失败：'+result.error);
    notice(result.assetError?'源表和游戏配置已导出；Unity 资源尚未同步：'+result.assetError:'源表与游戏配置已导出，正在同步 Unity 资源…',!!result.assetError);
    if(result.assetJob)await jobResult(result.assetJob,text=>notice(text));
    if(!result.assetError){notice('已保存并导出，Unity 资源同步完成。重新加载游戏配置后生效。');renderDetail();}
  }finally{setBusy(false);}
}
async function reload(){
  const fresh=await api('/api/workspace'),conflicts=[];for(const [k,d] of drafts){const op=d.operation,t=fresh.tables.find(t=>t.name===op.table),id=op.op==='upsert'?op.row[t?.key]:op.id,current=t?.rows.find(r=>r[t.key]===id);
    if(op.op==='upsert'&&JSON.stringify(current)===JSON.stringify(op.row)||op.op==='delete'&&!current){drafts.delete(k);continue;}
    if(!t||JSON.stringify(current)!==JSON.stringify(d.before))conflicts.push({entity:JSON.parse(k),original:d.before,current,draft:op});}
  if(conflicts.length){showInsight('外部修改冲突 · 草稿保留',conflicts);notice('存在重叠修改，未覆盖源表。请下载草稿，对照检查结果修改后重新导入。',true);return;}
  source=fresh;state=copy(fresh);for(const d of drafts.values())applyOperation(d.operation);persist();render();notice(drafts.size?'已合并外部非重叠变更，草稿保留。':'已读取最新源表。');
}
async function start(){source=await api('/api/workspace');state=copy(source);const stored=localStorage.getItem('content-center:'+source.projectId);if(stored){const saved=JSON.parse(stored);drafts=new Map(saved.drafts);source.revision=saved.revision;for(const d of drafts.values())if(table(d.operation.table))applyOperation(d.operation);notice('已恢复本机草稿；保存前请重读 / 合并外部修改。');}else notice('选择内容开始编辑；保存并导出会更新关联表、游戏配置和 Unity 资源。');const query=new URLSearchParams(location.search),target=table(query.get('table'));if(target){activeTable=target.name;activeModule=modules.find(m=>m.tables.includes(target.name))?.id||'all';const id=target.fields.find(f=>f.name===target.key).type==='int'?Number(query.get('id')):query.get('id');if(row(target.name,id))selected={table:target.name,id};if(['edit','links','preview'].includes(query.get('tab')))tab=query.get('tab');}$('unity-state').textContent=source.editor.message;render();}
$('table').onchange=()=>{activeTable=$('table').value;selected=null;renderLibrary();renderDetail();};$('search').oninput=renderLibrary;
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.tab;if(selected)history.replaceState(null,'',`/?table=${encodeURIComponent(selected.table)}&id=${encodeURIComponent(selected.id)}&tab=${tab}`);renderDetail();});
$('new').onclick=()=>Promise.resolve().then(()=>activeTable==='EquipmentItemTable'||activeTable==='EquipmentWeaponTable'?newItem():activeTable==='NpcTable'?newNpc():newGeneric()).catch(fail);
$('duplicate').onclick=()=>{const r=row(selected.table,selected.id);if(['EquipmentItemTable','EquipmentWeaponTable','EquipmentWearableTable','EquipmentRuneTable','EquipmentMagazineTable'].includes(selected.table))newItem().catch(fail);else if(selected.table==='NpcTable')newNpc();else newGeneric(selected.table,r);};
$('delete').onclick=()=>{if(!selected)return;if(!confirm('将此条标记为删除？保存前会检查所有引用。'))return;stage({op:'delete',table:selected.table,id:selected.id});selected=null;render();};
$('create').onclick=()=>Promise.resolve().then(()=>createAction()).catch(fail);$('wizard').addEventListener('close',()=>{assetView?.dispose();assetView=null;});
$('review').onclick=()=>check().catch(fail);$('save').onclick=()=>save().catch(fail);$('reload').onclick=()=>reload().catch(fail);
$('download').onclick=()=>{const url=URL.createObjectURL(new Blob([JSON.stringify(patch(),null,2)],{type:'application/json'})),a=document.createElement('a');a.href=url;a.download='content-draft.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
$('import').onchange=async event=>{try{const file=event.target.files[0];if(!file)return;const input=JSON.parse(await file.text());await api('/api/review',input);if(drafts.size&&!confirm('用导入的草稿替换当前草稿？'))return;source=await api('/api/workspace');if(input.revision!==source.revision)throw new Error('导入期间源表变化，请重新检查');state=copy(source);drafts.clear();for(const op of input.operations)stage(op);render();notice('已导入并检查草稿。');}catch(e){fail(e);}finally{event.target.value='';}};
$('resources').onclick=async()=>{try{if(drafts.size)throw new Error('请先保存并导出当前草稿，再同步资源');await jobResult(await api('/api/sync',{}),text=>notice(text));renderDetail();}catch(e){fail(e);}};
window.addEventListener('beforeunload',event=>{if(drafts.size||busy){event.preventDefault();event.returnValue='';}});
start().catch(fail);

import {narrativeGraph,conditionTargets,actionTargets} from '/rules.mjs';
import {createPreview} from './preview.js';
const $=id=>document.getElementById(id);
const titles={MissionTable:'任务',QuestTable:'阶段',ConditionTable:'条件',NarrativeActionTable:'动作',NpcTable:'NPC',FactionTable:'阵营',NpcPlacementTable:'出生位置',NpcScheduleTable:'日程',DialogueTable:'对话',DialogueNodeTable:'台词节点',DialogueChoiceTable:'选项',DialogueInterjectionTable:'队员插话',DialogueCameraTable:'镜头',NarrativeSettingsTable:'运行参数',TownMissionTable:'城镇委托',TownMissionSettingsTable:'委托参数',LegendaryEncounterTable:'传奇遭遇',SpecialEventTable:'特殊事件'};
const fieldNames={id:'配置 ID',name:'名称',description:'说明',category:'任务分类',startConditionId:'开始条件',completeConditionId:'完成条件',autoAccept:'自动接取',autoComplete:'自动结算',actionIds:'结果动作',missionId:'所属任务',conditionId:'可用条件',npcId:'对话对象',entryNodeId:'入口节点',cameraId:'镜头配方',dialogueId:'所属对话',speaker:'说话者',text:'正文',choiceIds:'选项与显示顺序',shot:'镜头构图',hideWhenLocked:'条件不足时隐藏',nextNodeId:'跳转目标',worldAction:'世界动作',nodeId:'所在节点',order:'排列顺序',mode:'发言方式',cue:'发言缘由',kind:'类型',conditionIds:'子条件',targetId:'目标',key:'事实 / 事件键',value:'数值',state:'目标状态',reason:'未满足时的提示'};
const enumLabels={basic:'基础',main:'主线',side:'支线',recruit:'招募',npc:'NPC',player:'玩家',narrator:'旁白',pair:'双人',auto:'自动',optional:'主动邀请',none:'无',attack:'开战'};
const state={workspace:null,table:'MissionTable',selected:null,operations:new Map(),mode:'overview',tab:'form',workview:'edit',view:null,baseView:null,history:[],draft:null};
const preview=createPreview($('preview'),$('preview-kind'),key=>select(key));
let renderTimer;
function element(tag,cls,text){const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;}
function status(text,error=false){$('status').textContent=text;$('status').classList.toggle('error',error);}
async function request(url,input){const response=await fetch(url,input?{method:'POST',headers:{'Content-Type':'application/json','X-Narrative-Token':state.workspace.token},body:JSON.stringify(input)}:{});const value=await response.json();if(!response.ok)throw new Error(value.error);return value;}
function run(fn){return async()=>{try{await fn();}catch(error){status(error.message,true);}};}
function exclusive(fn){return run(async()=>{const main=document.querySelector('main'),nav=document.querySelector('nav');main.inert=true;nav.inert=true;try{await fn();}finally{main.inert=false;nav.inert=false;}});}
function requireValidFields(){const invalid=$('editor').querySelector(':invalid');if(invalid){invalid.reportValidity();throw new Error('当前字段有无效输入，请修正后再检查或保存。');}}
function table(name){return state.workspace.tables.find(t=>t.name===name);}
function getDraft(){
  if(!state.draft){
    const tables=state.workspace.tables.map(t=>{const rows=new Map(t.rows.map(r=>[r.id,r]));for(const op of state.operations.values())if(op.table===t.name){if(op.op==='delete')rows.delete(op.id);else rows.set(op.row.id,op.row);}return {...t,rows:[...rows.values()].sort((a,b)=>a.id-b.id)};});
    state.draft={tables,graph:narrativeGraph(tables)};
  }
  return state.draft;
}
function currentRows(name){return getDraft().tables.find(t=>t.name===name).rows;}
function rowByKey(key){if(!key)return null;const [name,id]=key.split(':');return table(name)?currentRows(name).find(r=>r.id===Number(id)):null;}
const label=row=>row.name||row.text||row.reason||row.activity||`${row.kind||'记录'} ${row.id}`;
function diagnostics(value){const warnings=value?.warnings||[];$('diagnostics').hidden=warnings.length===0;$('diagnostics').textContent=warnings.join('\n');}
async function load(){
  const value=await request('/api/workspace');state.workspace=value;
  state.workspace.tables.sort((a,b)=>Object.keys(titles).indexOf(a.name)-Object.keys(titles).indexOf(b.name));
  state.operations.clear();state.draft=null;state.history=[];preview.reset();
  if(!rowByKey(state.selected)){const first=table('MissionTable').rows[0];state.selected=first?`MissionTable:${first.id}`:null;}
  state.table=state.selected?.split(':')[0]||'MissionTable';diagnostics(value.diagnostics);render();status('工作区已载入。草稿实时预览；保存后写入项目配置。');
}
function drafts(){const n=state.operations.size;$('draft-count').textContent=n+' 项修改';$('state').textContent=n?`${n} 项未保存修改`:'已与项目配置同步';$('save').disabled=!n;document.body.classList.toggle('has-drafts',n>0);}
function refreshProjection(){clearTimeout(renderTimer);renderList();if(state.workview==='graph')renderGraph();renderPreview();}
function stage(name,row){
  const key=`${name}:${row.id}`,original=table(name).rows.find(r=>r.id===row.id);
  if(original&&JSON.stringify(original)===JSON.stringify(row))state.operations.delete(key);
  else state.operations.set(key,{op:'upsert',table:name,row:structuredClone(row)});
  state.draft=null;drafts();$('selection-title').textContent=label(row);
  clearTimeout(renderTimer);renderTimer=setTimeout(refreshProjection,100);
}
function setWorkview(mode){state.workview=mode;$('edit-workspace').hidden=mode!=='edit';$('graph-workspace').hidden=mode!=='graph';for(const b of document.querySelectorAll('[data-workview]')){b.classList.toggle('active',b.dataset.workview===mode);b.setAttribute('aria-pressed',String(b.dataset.workview===mode));}if(mode==='graph'&&state.workspace)renderGraph();}
function select(key,remember=true){if(remember&&state.selected&&state.selected!==key)state.history.push(state.selected);state.selected=key;state.table=key.split(':')[0];state.tab='form';state.view=null;setWorkview('edit');render();}
function renderCategories(){
  $('categories').replaceChildren();
  for(const t of state.workspace.tables){const b=element('button',t.name===state.table?'active':'',titles[t.name]||t.name);b.setAttribute('aria-pressed',String(t.name===state.table));b.onclick=()=>{state.table=t.name;renderCategories();renderList();};$('categories').append(b);}
}
function renderList(){
  $('rows').replaceChildren();const query=$('search').value.toLowerCase(),rows=currentRows(state.table).filter(r=>!query||JSON.stringify(r).toLowerCase().includes(query));
  $('list-title').textContent=`${titles[state.table]||state.table} · ${rows.length}`;
  for(const row of rows){const key=`${state.table}:${row.id}`,b=element('button','row'+(state.selected===key?' active':'')+(state.operations.has(key)?' dirty':''));b.append(element('small','',`${state.table.replace('Table','')} / ${row.id}`),element('span','row-label',label(row)));b.title=label(row);b.onclick=()=>select(key);$('rows').append(b);}
  if(!rows.length)$('rows').append(element('p','empty',query?'没有匹配内容，试试名称或 ID。':'暂无内容，点击新建开始编写。'));
  $('counts').textContent=state.workspace.tables.length+' 张配置表';
}
function svg(tag,attrs={},text){const e=document.createElementNS('http://www.w3.org/2000/svg',tag);for(const [k,v] of Object.entries(attrs))e.setAttribute(k,v);if(text!==undefined)e.textContent=text;return e;}
function renderGraph(){
  const graph=getDraft().graph,allNodes=new Map(graph.nodes.map(n=>[n.key,n])),edges=graph.edges;
  let visible=new Set();const primary=['MissionTable','QuestTable','NpcTable','DialogueTable'];
  if(state.mode==='overview'){for(const node of allNodes.values())if(primary.includes(node.table))visible.add(node.key);}
  else{visible.add(state.selected);for(let depth=0;depth<2;depth++){const prior=new Set(visible);for(const edge of edges)if(prior.has(edge.from)||prior.has(edge.to)){visible.add(edge.from);visible.add(edge.to);}}}
  const nodes=[...allNodes.values()].filter(n=>visible.has(n.key));visible=new Set(nodes.map(n=>n.key));
  const displayed=[];for(const source of nodes){const seen=new Set(),walk=(key,depth)=>{if(seen.has(key)||depth>10)return;seen.add(key);for(const edge of edges.filter(e=>e.from===key)){if(visible.has(edge.to)){if(edge.to!==source.key)displayed.push({from:source.key,to:edge.to,label:depth?'条件 / 动作':edge.label});}else if(state.mode==='overview')walk(edge.to,depth+1);}};walk(source.key,0);}
  const columns=(state.mode==='overview'?primary:[...new Set(nodes.map(n=>n.table))]).filter(t=>nodes.some(n=>n.table===t));
  const positions=new Map();let height=300;columns.forEach((name,column)=>{const group=nodes.filter(n=>n.table===name);height=Math.max(height,group.length*115+110);group.forEach((n,i)=>positions.set(n.key,{x:50+column*290,y:65+i*115}));});
  const width=Math.max(650,columns.length*290+60);state.baseView={x:0,y:0,w:width,h:height};if(!state.view)state.view={...state.baseView};
  const root=$('graph');root.replaceChildren();const defs=svg('defs');const marker=svg('marker',{id:'arrow',viewBox:'0 0 10 10',refX:9,refY:5,markerWidth:6,markerHeight:6,orient:'auto-start-reverse'});marker.append(svg('path',{d:'M 0 0 L 10 5 L 0 10 z',fill:'#718367'}));defs.append(marker);root.append(defs);
  const unique=new Set();for(const edge of displayed){const key=edge.from+'>'+edge.to;if(unique.has(key))continue;unique.add(key);const a=positions.get(edge.from),b=positions.get(edge.to);if(!a||!b)continue;const x1=a.x+220,y1=a.y+37,x2=b.x,y2=b.y+37;root.append(svg('path',{class:'edge',d:`M ${x1} ${y1} C ${x1+65} ${y1},${x2-65} ${y2},${x2} ${y2}`,'marker-end':'url(#arrow)'}));}
  for(const node of nodes){const p=positions.get(node.key),g=svg('g',{class:`graph-node ${node.table}${state.selected===node.key?' selected':''}`,transform:`translate(${p.x},${p.y})`,tabindex:0,role:'button','aria-label':node.label});g.append(svg('rect',{width:220,height:82,rx:7}),svg('text',{x:15,y:21,class:'node-type'},node.table.replace('Table','').toUpperCase()),svg('text',{x:15,y:45,class:'node-title'},node.label.length>13?node.label.slice(0,13)+'…':node.label),svg('text',{x:15,y:65,class:'node-id'},'# '+node.id),svg('title',{},node.label));g.onclick=()=>select(node.key);g.onkeydown=e=>{if(e.key==='Enter')select(node.key);};root.append(g);}
  $('graph-title').textContent=state.mode==='overview'?'任务、人物与对话':'当前节点 · 两层关联';view();
}
function view(){const v=state.view;$('graph').setAttribute('viewBox',`${v.x} ${v.y} ${v.w} ${v.h}`);}
function fieldEditor(t,row,field){
  const wrap=element('div','field'),title=element('label','field-title',fieldNames[field.name]||field.description||field.name),inputId=`field-${field.name}`;
  title.htmlFor=inputId;title.append(element('span','field-type',field.name));wrap.append(title);let input;
  const refName=field.ref||(field.name==='targetId'?(t.name==='ConditionTable'?conditionTargets[row.kind]:t.name==='NarrativeActionTable'?actionTargets[row.kind]:null):['DialogueChoiceTable','DialogueInterjectionTable'].includes(t.name)&&field.name==='nextNodeId'?'DialogueNodeTable':null);
  let refRows=refName?(table(refName)?currentRows(refName).map(r=>({id:r.id,name:label(r)})):state.workspace.references[refName]):null;
  if(refName==='DialogueNodeTable'&&field.name==='nextNodeId')refRows=[{id:0,name:t.name==='DialogueInterjectionTable'?'留在当前节点':'结束对话'},...refRows];
  if(refRows&&field.type.endsWith('[]')){
    const list=element('div','ordered-references');
    const draw=()=>{
      list.replaceChildren();
      row[field.name].forEach((id,index)=>{
        const line=element('div','ordered-reference'),target=refRows.find(r=>r.id===id),b=element('button','reference-name',`${index+1}. ${target?.name||'缺失引用'} · #${id}`);
        b.disabled=!table(refName);b.onclick=()=>select(`${refName}:${id}`);line.append(b);
        for(const [text,offset] of [['↑',-1],['↓',1]]){const move=element('button','order-button',text);move.setAttribute('aria-label',`${offset<0?'上移':'下移'} ${id}`);move.disabled=index+offset<0||index+offset>=row[field.name].length;move.onclick=()=>{const ids=row[field.name];[ids[index],ids[index+offset]]=[ids[index+offset],ids[index]];stage(t.name,row);draw();};line.append(move);}
        const remove=element('button','order-button','×');remove.setAttribute('aria-label',`移除引用 ${id}`);remove.onclick=()=>{row[field.name].splice(index,1);stage(t.name,row);draw();};line.append(remove);list.append(line);
      });
      input=element('select');input.id=inputId;input.setAttribute('aria-label',field.name);const placeholder=element('option','','＋ 添加引用…');placeholder.value='';input.append(placeholder);
      for(const r of refRows.filter(r=>!row[field.name].includes(r.id))){const o=element('option','',`${r.id} · ${r.name}`);o.value=r.id;input.append(o);}
      input.onchange=()=>{if(input.value==='')return;row[field.name].push(Number(input.value));stage(t.name,row);draw();};list.append(input);
    };draw();wrap.append(list,element('small','',field.description));return wrap;
  }
  if(refRows||field.type==='enum'){
    input=element('select');const options=refRows||field.values.map(v=>({id:typeof v==='object'?v.value:v,name:typeof v==='object'?v.description:enumLabels[v]||v}));
    if(!options.some(o=>String(o.id)===String(row[field.name]))){const unset=element('option','',`未设置 / ${row[field.name]}`);unset.value=String(row[field.name]);unset.selected=true;input.append(unset);}
    for(const o of options){const option=element('option','',`${o.id} · ${o.name}`);option.value=String(o.id);option.selected=String(row[field.name])===String(o.id);input.append(option);}
  }else if(field.type==='text'&&!['name','cue'].includes(field.name)||field.type.endsWith('[]')){input=element('textarea');input.value=field.type.endsWith('[]')?JSON.stringify(row[field.name]):row[field.name];input.rows=field.name==='text'||field.name==='description'?5:2;}
  else{input=element('input');input.type=field.type==='bool'?'checkbox':['int','float'].includes(field.type)?'number':'text';if(input.type==='checkbox')input.checked=row[field.name];else input.value=row[field.name];if(input.type==='number'){input.step=field.type==='float'?'any':'1';if(field.min!==undefined)input.min=field.min;if(field.max!==undefined)input.max=field.max;}}
  input.id=inputId;input.disabled=field.name==='id';input.setAttribute('aria-label',field.name);
  const update=()=>{try{
    let value;input.setCustomValidity('');
    if(field.type==='bool')value=input.checked;
    else if(['int','float'].includes(field.type)){if(input.value===''||!input.validity.valid)throw new Error('请输入字段范围内的有效数值');value=Number(input.value);}
    else if(field.type.endsWith('[]')){value=JSON.parse(input.value);if(!Array.isArray(value)||!value.every(Number.isSafeInteger))throw new Error('请输入整数数组');}
    else value=input.value;
    row[field.name]=value;stage(t.name,row);status('草稿已更新，右侧显示当前内容。');
  }catch(error){input.setCustomValidity(error.message);status(error.message,true);}};
  input.onchange=()=>{update();if(field.name==='kind')renderEditor();};if(input.tagName==='TEXTAREA'||input.tagName==='INPUT')input.oninput=update;
  wrap.append(input,element('small','',field.description));
  if(refName&&table(refName)&&!field.type.endsWith('[]')){const open=element('button','text-button','编辑引用 ↗');open.onclick=()=>select(`${refName}:${row[field.name]}`);wrap.append(open);}
  return wrap;
}
function renderEditor(){
  const key=state.selected,existing=rowByKey(key),name=key?.split(':')[0];
  $('selection-title').textContent=existing?label(existing):key?'条目已在草稿中删除':'选择或新建内容';$('selection-type').textContent=key?`${titles[name]||name} / ${name} #${existing?.id||key.split(':')[1]}`:'';
  $('editor').replaceChildren();$('delete').disabled=!existing;$('selection-back').disabled=!state.history.length;
  for(const tab of ['form','impact'])$(tab+'-tab').classList.toggle('active',state.tab===tab);
  if(!existing){$('editor').append(element('p','empty','从资料库选择条目，或新建一条内容。'));return;}
  if(state.tab==='form'){
    const row=structuredClone(existing);
    const groups=[['正文与身份',f=>['id','name','description','text','speaker','cue','category','kind'].includes(f.name)],['条件、关联与结果',f=>f.ref||['nextNodeId','targetId','conditionIds','actionIds','key','value','state','reason'].includes(f.name)],['行为设置',()=>true]];
    const remaining=new Set(table(name).fields.filter(f=>f.name!=='id'));
    for(const [title,predicate] of groups){const fields=[...remaining].filter(predicate);if(!fields.length)continue;$('editor').append(element('div','form-section-title',title));for(const f of fields){remaining.delete(f);$('editor').append(fieldEditor(table(name),row,f));}}
  }else{
    const graph=getDraft().graph,links=graph.edges.filter(e=>e.from===key||e.to===key);
    $('editor').append(element('p','note','引用与影响包含尚未保存的草稿。点击关联内容继续编辑。'));
    for(const e of links){const to=e.from===key?e.to:e.from,target=rowByKey(to),b=element('button','link-row',`${e.from===key?'引用 →':'被引用 ←'} ${target?label(target):to} · ${e.label}`);b.disabled=!table(to.split(':')[0]);b.onclick=()=>select(to);$('editor').append(b);}
    const b=element('button','','分析间接影响');b.onclick=()=>{const affected=new Set([key]),pending=[key];for(let i=0;i<pending.length;i++)for(const e of graph.edges)if(e.to===pending[i]&&!affected.has(e.from)){affected.add(e.from);pending.push(e.from);}status(`草稿中有 ${affected.size-1} 条间接关联内容。此分析表示引用影响，不代表剧情可达性。`);const list=element('div','impact-results');for(const k of pending.slice(1)){const row=rowByKey(k);if(!row)continue;const link=element('button','link-row',`${titles[k.split(':')[0]]} · ${label(row)}`);link.onclick=()=>select(k);list.append(link);}$('editor').querySelector('.impact-results')?.remove();$('editor').append(list);};$('editor').append(b);
  }
}
function renderPreview(){if(!state.selected){$('preview').replaceChildren(element('p','empty','选择任务、阶段、对白或选项，在这里预览。'));return;}const draft=getDraft();preview.render(draft.tables,state.workspace.references,draft.graph,state.selected);}
function render(){clearTimeout(renderTimer);renderCategories();renderList();if(state.workview==='graph')renderGraph();renderEditor();renderPreview();drafts();}
async function save(){requireValidFields();if(!state.operations.size)return;const input={revision:state.workspace.revision,operations:[...state.operations.values()]};const review=await request('/api/review',input);diagnostics(review.diagnostics);await request('/api/patch',input);await load();status('已保存全部草稿；游戏配置尚需导出。');}
$('reload').onclick=exclusive(async()=>{if(!state.operations.size||confirm('重新载入会丢弃未保存草稿，是否继续？'))await load();});$('search').oninput=renderList;$('save').onclick=exclusive(save);
$('validate').onclick=exclusive(async()=>{requireValidFields();if(!state.operations.size){const result=await request('/api/workspace');diagnostics(result.diagnostics);status('当前配置检查通过。');return;}const result=await request('/api/review',{revision:state.workspace.revision,operations:[...state.operations.values()]});diagnostics(result.diagnostics);status('草稿检查通过，可以保存。');});
$('export').onclick=exclusive(async()=>{await save();const result=await request('/api/export',{revision:state.workspace.revision});state.workspace.revision=result.revision;status(`已保存并导出 ${result.tables} 张配置表。Unity 在下次启动会读取新配置。`);});
$('new').onclick=()=>{const t=table(state.table),row={};for(const f of t.fields){if(f.name==='id')row.id=Math.max(0,...currentRows(t.name).map(r=>r.id))+1;else if(f.default!==undefined)row[f.name]=structuredClone(f.default);else if(f.type.endsWith('[]'))row[f.name]=[];else if(f.type==='bool')row[f.name]=false;else if(f.ref)row[f.name]=(table(f.ref)?currentRows(f.ref):state.workspace.references[f.ref])[0]?.id||0;else if(f.type==='enum')row[f.name]=typeof f.values[0]==='object'?f.values[0].value:f.values[0];else row[f.name]=['int','float'].includes(f.type)?(f.min||0):'';}stage(t.name,row);select(`${t.name}:${row.id}`);};
$('delete').onclick=()=>{if(!state.selected||!confirm('将此条加入删除草稿？被引用的条目需要一起修改才能保存。'))return;const [name,id]=state.selected.split(':');if(table(name).rows.some(r=>r.id===Number(id)))state.operations.set(state.selected,{op:'delete',table:name,id:Number(id)});else state.operations.delete(state.selected);state.draft=null;render();};
$('download').onclick=()=>{const blob=new Blob([JSON.stringify({revision:state.workspace.revision,operations:[...state.operations.values()]},null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=element('a');a.href=url;a.download='narrative-patch.json';a.click();URL.revokeObjectURL(url);};
$('selection-back').onclick=()=>{const key=state.history.pop();if(key)select(key,false);};
for(const tab of ['form','impact'])$(tab+'-tab').onclick=()=>{state.tab=tab;renderEditor();};
for(const b of document.querySelectorAll('[data-workview]'))b.onclick=()=>setWorkview(b.dataset.workview);
for(const b of document.querySelectorAll('[data-mode]'))b.onclick=()=>{state.mode=b.dataset.mode;state.view=null;document.querySelectorAll('[data-mode]').forEach(x=>x.classList.toggle('active',x===b));renderGraph();};$('fit').onclick=()=>{state.view={...state.baseView};view();};
let pan=null;$('graph').onpointerdown=e=>{if(e.target.closest('.graph-node'))return;pan={x:e.clientX,y:e.clientY,view:{...state.view}};$('graph').setPointerCapture(e.pointerId);};$('graph').onpointermove=e=>{if(!pan)return;const rect=$('graph').getBoundingClientRect();state.view={...pan.view,x:pan.view.x-(e.clientX-pan.x)*pan.view.w/rect.width,y:pan.view.y-(e.clientY-pan.y)*pan.view.h/rect.height};view();};$('graph').onpointerup=$('graph').onpointercancel=()=>pan=null;$('graph').addEventListener('wheel',e=>{e.preventDefault();const factor=e.deltaY>0?1.12:.89,v=state.view,w=Math.max(200,Math.min(9000,v.w*factor)),h=v.h*w/v.w;state.view={x:v.x+(v.w-w)/2,y:v.y+(v.h-h)/2,w,h};view();},{passive:false});
window.addEventListener('beforeunload',e=>{if(state.operations.size){e.preventDefault();e.returnValue='';}});run(load)();

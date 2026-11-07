// Read-only projection of the draft. No conditions are evaluated and no actions run here.
const progress = {inactive:'未接取 / 未激活', active:'进行中', ready:'待结算', completed:'已完成'};
const signed = value => value >= 0 ? `+${value}` : String(value);
const time = minute => `${String(Math.floor(minute / 60)).padStart(2,'0')}:${String(minute % 60).padStart(2,'0')}`;

export function createPreviewModel(tables, references = {}) {
  const indexes = new Map(tables.map(t => [t.name, new Map(t.rows.map(r => [r.id, r]))]));
  const rows = name => [...(indexes.get(name)?.values() || [])];
  const get = (name, id) => indexes.get(name)?.get(id);
  const ref = (name, id) => get(name,id) || references[name]?.find(r => r.id === id);
  const label = (name,id) => { const row=ref(name,id); return row ? (row.name || row.text || row.reason || `${name} #${id}`) : `缺失引用：${name} #${id}`; };
  const owners = id => rows('DialogueNodeTable').filter(n => n.choiceIds.includes(id));
  const interjections = id => rows('DialogueInterjectionTable').filter(r => r.nodeId === id).sort((a,b) => a.order-b.order || a.id-b.id);
  const incoming = id => [
    ...rows('DialogueChoiceTable').filter(c => c.nextNodeId === id).flatMap(c => owners(c.id).map(node => ({table:'DialogueChoiceTable',row:c,node}))),
    ...rows('DialogueInterjectionTable').filter(c => c.nextNodeId === id).map(c => ({table:'DialogueInterjectionTable',row:c,node:get('DialogueNodeTable',c.nodeId)}))
  ];
  function conditionText(c) {
    switch (c.kind) {
      case 'all': return '全部满足 · AND';
      case 'any': return '任一满足 · OR';
      case 'not': return '取反 · NOT';
      case 'always': return '无前置要求';
      case 'never': return '始终不满足';
      case 'mission_state': return `任务「${label('MissionTable',c.targetId)}」＝ ${progress[c.state] || c.state}`;
      case 'quest_state': return `阶段「${label('QuestTable',c.targetId)}」＝ ${progress[c.state] || c.state}`;
      case 'flag': return `事实 ${c.key} ＝ ${c.value}`;
      case 'coins': return `金币 ≥ ${c.value}`;
      case 'item_count': return `${label('EquipmentItemTable',c.targetId)} ≥ ${c.value}（只检查，不扣除）`;
      case 'kill_count': return `激活后击败 ${label('CombatUnitTable',c.targetId)} ≥ ${c.value}`;
      case 'npc_relation': return `${label('NpcTable',c.targetId)} · 好感 ≥ ${c.value}`;
      case 'faction_reputation': return `${label('FactionTable',c.targetId)} · 声望 ≥ ${c.value}`;
      case 'npc_recruited': return `已招募 ${label('NpcTable',c.targetId)}`;
      case 'time_window': return `${time(c.targetId)} ≤ 游戏时间 < ${time(c.value)}`;
      case 'party_attribute': return `任一存活队员 · ${label('GrowthAttributeTable',c.targetId)} ≥ ${c.value}`;
      case 'actor_attribute': return `同一队员 · ${label('GrowthAttributeTable',c.targetId)} ≥ ${c.value}`;
      case 'actor_trait': return `同一队员具有特质 · ${label('CombatTraitTable',c.targetId)}`;
      case 'actor_history': return `同一队员经历 ${c.key} / ${c.state}${c.targetId ? ` / ${label('AdventureEventTable',c.targetId)}` : ''} ≥ ${c.value} 次`;
      default: return `自定义条件 ${c.kind}（需运行时判定）· targetId=${c.targetId}, key=${c.key}, value=${c.value}, state=${c.state}`;
    }
  }
  function condition(id) {
    let budget=160;
    function visit(next,path) {
      const c=get('ConditionTable',next);
      const error=!c ? '条件不存在或已删除' : path.has(next) ? '条件存在循环引用' : path.size >= 64 || --budget < 0 ? '条件过深或过大，请在关系图中检查' : null;
      if(error) return {id:next,text:`#${next} · ${error}`,error,children:[]};
      const branch=new Set(path).add(next),children=[];
      for(const child of c.conditionIds) { children.push(visit(child,branch)); if(budget<0)break; }
      return {id:next,text:conditionText(c),reason:c.reason,kind:c.kind,children};
    }
    return visit(id,new Set());
  }
  function action(id) {
    const a=get('NarrativeActionTable',id);
    if(!a)return {id,text:`动作 #${id} 不存在或已删除`,error:true};
    const names={
      set_flag:()=>`设置事实 ${a.key} ＝ ${a.value}`,
      add_coins:()=>`金币 ${signed(a.value)}`,
      grant_item:()=>`获得 ${label('EquipmentItemTable',a.targetId)} × ${a.value}`,
      grant_experience:()=>`每位现有队员经验 +${a.value}`,
      accept_mission:()=>`接取任务「${label('MissionTable',a.targetId)}」`,
      claim_mission:()=>`结算任务「${label('MissionTable',a.targetId)}」并执行其完成动作`,
      recruit_npc:()=>`招募 ${label('NpcTable',a.targetId)}`,
      add_relation:()=>`${label('NpcTable',a.targetId)} · 好感 ${signed(a.value)}`,
      add_reputation:()=>`${label('FactionTable',a.targetId)} · 声望 ${signed(a.value)}`
    };
    return {id,text:names[a.kind]?.() || `未知动作 ${a.kind}`,kind:a.kind,row:a};
  }
  function focus(key) {
    const [name,value]=key.split(':'),id=Number(value),row=get(name,id);
    if(!row)return {kind:'missing',name,id};
    if(name==='MissionTable'||name==='QuestTable') return {kind:'mission',mission:get('MissionTable',name==='MissionTable'?id:row.missionId),quest:name==='QuestTable'?row:null};
    let nodes=[];
    if(name==='DialogueTable')nodes=[get('DialogueNodeTable',row.entryNodeId)];
    if(name==='DialogueNodeTable')nodes=[row];
    if(name==='DialogueChoiceTable')nodes=owners(id);
    if(name==='DialogueInterjectionTable')nodes=[get('DialogueNodeTable',row.nodeId)];
    if(nodes.length)return {kind:'dialogue',node:nodes[0],owners:nodes.filter(Boolean),selected:key};
    return {kind:'entity',name,row};
  }
  function relatedDialogues(mission,quests,graph) {
    const seeds=new Set([`MissionTable:${mission.id}`,...quests.map(q=>`QuestTable:${q.id}`)]);
    const forward=[...seeds];
    for(let i=0;i<forward.length;i++)for(const edge of graph.edges)if(edge.from===forward[i] && /^(ConditionTable|NarrativeActionTable):/.test(edge.to) && !seeds.has(edge.to)) {
      const [name,id]=edge.to.split(':'),row=get(name,Number(id));
      // Universal gates do not establish a story connection between their users.
      if(name==='ConditionTable'&&(!row||['always','never'].includes(row.kind)))continue;
      seeds.add(edge.to);forward.push(edge.to);
    }
    const pending=[...seeds],found=new Set();
    for(let i=0;i<pending.length;i++)for(const edge of graph.edges)if(edge.to===pending[i] && !seeds.has(edge.from)) {
      const name=edge.from.split(':')[0];
      if(!['ConditionTable','NarrativeActionTable','DialogueChoiceTable','DialogueNodeTable','DialogueInterjectionTable','DialogueTable'].includes(name))continue;
      seeds.add(edge.from);pending.push(edge.from);
      const id=Number(edge.from.split(':')[1]);
      if(name==='DialogueTable')found.add(id);
      if(name==='DialogueNodeTable')found.add(get(name,id).dialogueId);
      if(name==='DialogueInterjectionTable'){const n=get('DialogueNodeTable',get(name,id).nodeId);if(n)found.add(n.dialogueId);}
    }
    return [...found].map(id=>get('DialogueTable',id)).filter(Boolean);
  }
  // Reconcile every draft update: changed/deleted edges must not leave a stale transcript.
  function reconcile(origin,steps) {
    let node=get('DialogueNodeTable',origin),ended=false;
    const valid=[],used=new Set();
    for(const step of steps) {
      if(!node||ended)break;
      const choice=get(step.table,step.id),isChoice=step.table==='DialogueChoiceTable';
      if(!choice || (isChoice ? !node.choiceIds.includes(choice.id) : choice.nodeId!==node.id||choice.mode!=='optional'||used.has(choice.id)))break;
      const next=choice.nextNodeId ? get('DialogueNodeTable',choice.nextNodeId) : null;
      if(choice.nextNodeId && (!next || next.dialogueId!==node.dialogueId))break;
      valid.push({...step,from:node.id});
      if(!isChoice)used.add(choice.id);
      if(next)node=next;else if(isChoice)ended=true;
    }
    return {steps:valid,node,ended,used};
  }
  return {rows,get,ref,label,owners,incoming,interjections,condition,action,focus,reconcile,relatedDialogues};
}

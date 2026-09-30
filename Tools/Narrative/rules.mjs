// 纯数据校验与关系投影；ConfigEditor、导表器、叙事 Web 和 Agent CLI 共用。
export const narrativeTables = ['MissionTable','QuestTable','ConditionTable','NarrativeActionTable','NpcTable','FactionTable','NpcPlacementTable','NpcScheduleTable','DialogueTable','DialogueNodeTable','DialogueChoiceTable','DialogueCameraTable','NarrativeSettingsTable'];
export const conditionTargets = {mission_state:'MissionTable',quest_state:'QuestTable',item_count:'EquipmentItemTable',kill_count:'CombatUnitTable',npc_relation:'NpcTable',faction_reputation:'FactionTable',npc_recruited:'NpcTable'};
export const actionTargets = {grant_item:'EquipmentItemTable',accept_mission:'MissionTable',claim_mission:'MissionTable',recruit_npc:'NpcTable',add_relation:'NpcTable',add_reputation:'FactionTable'};
const requireRule = (test, message) => { if (!test) throw new Error(message); };
export function validateNarrative(tables) {
  if (!tables.some(t => t.name === 'MissionTable')) return;
  const byName = new Map(tables.map(t => [t.name,t]));
  for (const name of narrativeTables) requireRule(byName.has(name), `Narrative: missing ${name}`);
  const rows = name => byName.get(name).rows;
  const get = (name,id) => { const row=byName.get(name)?.rows.find(r=>r.id===id); requireRule(row,`Narrative: missing ${name}[${id}]`); return row; };
  const warnings=[]; const depths=new Map(),visiting=new Set();
  function condition(id) {
    requireRule(!visiting.has(id),`Condition cycle at ${id}`);
    if (depths.has(id)) return depths.get(id);
    const row=get('ConditionTable',id); visiting.add(id);
    requireRule(row.reason.trim(),`Condition ${id}: reason is required`);
    let depth=1;
    if (['all','any','not'].includes(row.kind)) {
      requireRule(row.conditionIds.length>0 && (row.kind!=='not'||row.conditionIds.length===1),`Condition ${id}: invalid composite arity`);
      requireRule(new Set(row.conditionIds).size===row.conditionIds.length,`Condition ${id}: duplicate children`);
      for (const child of row.conditionIds) depth=Math.max(depth,condition(child)+1);
    } else {
      requireRule(row.conditionIds.length===0,`Condition ${id}: leaf has children`);
      if (conditionTargets[row.kind]) get(conditionTargets[row.kind],row.targetId);
      if (['item_count','kill_count','coins'].includes(row.kind)) requireRule(row.value>0,`Condition ${id}: threshold must be positive`);
      if (row.kind==='flag') requireRule(/^[A-Za-z_][A-Za-z0-9_]*$/.test(row.key),`Condition ${id}: invalid flag key`);
      if (['mission_state','quest_state'].includes(row.kind)) requireRule(['inactive','active','ready','completed'].includes(row.state),`Condition ${id}: unknown progress state`);
      if (row.kind==='time_window') requireRule(row.targetId>=0&&row.targetId<row.value&&row.value<=1440,`Condition ${id}: invalid time window`);
      if (row.kind==='npc_relation') {const npc=get('NpcTable',row.targetId);requireRule(row.value>=npc.relationMin&&row.value<=npc.relationMax,`Condition ${id}: relation outside range`);}
      if (row.kind==='faction_reputation') {const faction=get('FactionTable',row.targetId);requireRule(row.value>=faction.minValue&&row.value<=faction.maxValue,`Condition ${id}: reputation outside range`);}
      if (row.kind==='npc_recruited') requireRule(get('NpcTable',row.targetId).recruitable,`Condition ${id}: NPC is not recruitable`);
      if (!conditionTargets[row.kind]&&!['always','never','flag','time_window','coins'].includes(row.kind)) warnings.push(`Condition ${id}: custom kind '${row.kind}' requires its registered Lua validator`);
    }
    requireRule(depth<=64,`Condition ${id}: depth exceeds 64`);visiting.delete(id);depths.set(id,depth);return depth;
  }
  for(const row of rows('ConditionTable')) condition(row.id);
  const leaves = id => {const result=[],pending=[id],seen=new Set();while(pending.length){const next=pending.pop();if(seen.has(next))continue;seen.add(next);const r=get('ConditionTable',next);if(r.conditionIds.length)pending.push(...r.conditionIds);else result.push(r);}return result;};
  const noKill = (id,label) => requireRule(!leaves(id).some(r=>r.kind==='kill_count'),`${label}: kill_count requires an accepted mission/quest context`);
  for(const action of rows('NarrativeActionTable')) {
    if(actionTargets[action.kind])get(actionTargets[action.kind],action.targetId);
    if(action.kind==='grant_item')requireRule(action.value>0,`Action ${action.id}: grant must be positive`);
    if(action.kind==='set_flag')requireRule(/^[A-Za-z_][A-Za-z0-9_]*$/.test(action.key),`Action ${action.id}: invalid flag`);
    if(action.kind==='recruit_npc')requireRule(get('NpcTable',action.targetId).recruitable,`Action ${action.id}: NPC cannot recruit`);
  }
  for(const name of ['MissionTable','QuestTable'])for(const row of rows(name)) {
    if(name==='MissionTable')noKill(row.startConditionId,`${name}[${row.id}].startConditionId`);
    requireRule(new Set(row.actionIds).size===row.actionIds.length,`${name}[${row.id}]: duplicate reward action`);
    for(const id of row.actionIds)requireRule(!['accept_mission','claim_mission'].includes(get('NarrativeActionTable',id).kind),`${name}[${row.id}]: completion actions cannot accept/claim missions; use Conditions`);
  }
  const owners=new Map();
  for(const node of rows('DialogueNodeTable')) {
    requireRule(node.text.trim(),`Dialogue node ${node.id}: empty text`);
    requireRule(new Set(node.choiceIds).size===node.choiceIds.length,`Dialogue node ${node.id}: duplicate choices`);
    for(const id of node.choiceIds) {
      requireRule(!owners.has(id)||owners.get(id)===node.dialogueId,`Choice ${id}: shared across different dialogues`);owners.set(id,node.dialogueId);
      const choice=get('DialogueChoiceTable',id);noKill(choice.conditionId,`Choice ${id}`);
      if(choice.nextNodeId!==0)requireRule(get('DialogueNodeTable',choice.nextNodeId).dialogueId===node.dialogueId,`Choice ${id}: cross-dialogue edge`);
    }
  }
  for(const dialogue of rows('DialogueTable')) {
    noKill(dialogue.conditionId,`Dialogue ${dialogue.id}`);
    requireRule(get('DialogueNodeTable',dialogue.entryNodeId).dialogueId===dialogue.id,`Dialogue ${dialogue.id}: invalid entry`);
    const seen=new Set();const walk=id=>{if(seen.has(id))return;seen.add(id);for(const cid of get('DialogueNodeTable',id).choiceIds){const next=get('DialogueChoiceTable',cid).nextNodeId;if(next)walk(next);}};walk(dialogue.entryNodeId);
    for(const node of rows('DialogueNodeTable').filter(r=>r.dialogueId===dialogue.id))requireRule(seen.has(node.id),`Dialogue ${dialogue.id}: unreachable node ${node.id}`);
  }
  for(const npc of rows('NpcTable')) {
    requireRule(npc.relationMin<=npc.initialRelation&&npc.initialRelation<=npc.relationMax,`NPC ${npc.id}: invalid relation range`);
    for(const id of npc.dialogueIds)requireRule(get('DialogueTable',id).npcId===npc.id,`NPC ${npc.id}: foreign dialogue ${id}`);
    const placements=rows('NpcPlacementTable').filter(p=>p.npcId===npc.id);requireRule(placements.length===1,`NPC ${npc.id}: requires exactly one placement`);
    const placement=placements[0],area=get('MapAreaTable',placement.areaId);requireRule(area.areaType===2,`NPC ${npc.id}: requires a town`);
    const facilities=get('MapAreaTownTable',area.profileId).facilityIds;
    requireRule(facilities.includes(placement.facilityId),`NPC ${npc.id}: spawn facility absent`);
    const schedules=rows('NpcScheduleTable').filter(r=>r.npcId===npc.id).sort((a,b)=>a.startMinute-b.startMinute);
    let minute=0;for(const s of schedules){requireRule(s.startMinute===minute&&s.endMinute>s.startMinute,`NPC ${npc.id}: schedule gap/overlap`);requireRule(facilities.includes(s.facilityId),`NPC ${npc.id}: schedule facility absent`);minute=s.endMinute;}
    requireRule(minute===1440,`NPC ${npc.id}: schedule must cover 24 hours`);
  }
  for(const f of rows('FactionTable'))requireRule(f.minValue<=f.initialValue&&f.initialValue<=f.maxValue,`Faction ${f.id}: invalid reputation range`);
  // 任务状态依赖允许环；它可能是未接取/排他分支。只能给出诊断，不把网状叙事误当作线性 DAG。
  const dependencies=new Map(rows('MissionTable').map(m=>[m.id,leaves(m.startConditionId).filter(c=>c.kind==='mission_state'&&c.state==='completed').map(c=>c.targetId)]));
  const seen=new Set(),stack=new Set();function visit(id){if(stack.has(id)){warnings.push(`Mission ${id}: completed-state prerequisite cycle; check for a reachable entry`);return;}if(seen.has(id))return;seen.add(id);stack.add(id);for(const next of dependencies.get(id)||[])visit(next);stack.delete(id);}for(const id of dependencies.keys())visit(id);
  return {warnings};
}
export function narrativeGraph(tables) {
  const nodes=[],edges=[];
  const add=(from,to,label)=>edges.push({from,to,label});
  for(const table of tables.filter(t=>narrativeTables.includes(t.name)))for(const row of table.rows) {
    const key=`${table.name}:${row.id}`;nodes.push({key,table:table.name,id:row.id,label:row.name||row.text||row.reason||row.activity||`${row.kind||table.name} ${row.id}`});
    for(const field of table.fields.filter(f=>f.ref))for(const id of field.type.endsWith('[]')?row[field.name]:[row[field.name]])add(key,`${field.ref}:${id}`,field.name);
    if(table.name==='ConditionTable'&&conditionTargets[row.kind])add(key,`${conditionTargets[row.kind]}:${row.targetId}`,row.kind);
    if(table.name==='NarrativeActionTable'&&actionTargets[row.kind])add(key,`${actionTargets[row.kind]}:${row.targetId}`,row.kind);
    if(table.name==='DialogueChoiceTable'&&row.nextNodeId)add(key,`DialogueNodeTable:${row.nextNodeId}`,'nextNodeId');
  }
  const conditions=tables.find(t=>t.name==='ConditionTable')?.rows||[],actions=tables.find(t=>t.name==='NarrativeActionTable')?.rows||[];
  for(const condition of conditions.filter(c=>c.kind==='flag'))for(const action of actions.filter(a=>a.kind==='set_flag'&&a.key===condition.key))
    add(`ConditionTable:${condition.id}`,`NarrativeActionTable:${action.id}`,'reads flag:'+condition.key);
  return {nodes,edges};
}

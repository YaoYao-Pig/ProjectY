// 纯数据校验与关系投影；ConfigEditor、导表器、叙事 Web 和 Agent CLI 共用。
export const narrativeTables = ['MissionTable','QuestTable','ConditionTable','NarrativeActionTable','NpcTable','FactionTable','NpcPlacementTable','NpcScheduleTable','DialogueTable','DialogueNodeTable','DialogueChoiceTable','DialogueInterjectionTable','DialogueCameraTable','NarrativeSettingsTable','TownMissionTable','TownMissionSettingsTable','LegendaryEncounterTable','SpecialEventTable'];
export const conditionTargets = {mission_state:'MissionTable',quest_state:'QuestTable',item_count:'EquipmentItemTable',kill_count:'CombatUnitTable',npc_relation:'NpcTable',faction_reputation:'FactionTable',npc_recruited:'NpcTable',party_attribute:'GrowthAttributeTable',actor_attribute:'GrowthAttributeTable',actor_trait:'CombatTraitTable'};
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
      if (['party_attribute','actor_attribute'].includes(row.kind)) requireRule(row.value>0&&row.key===''&&row.state==='',`Condition ${id}: ${row.kind} requires positive value and targetId only`);
      if (row.kind==='actor_trait') requireRule(row.value===0&&row.key===''&&row.state==='',`Condition ${id}: actor_trait uses targetId only`);
      if (row.kind==='actor_history') {
        requireRule(row.value>0&&row.targetId>=0&&['participant','subject','object'].includes(row.state)&&rows('StoryLogTemplateTable').some(r=>r.kind===row.key),`Condition ${id}: invalid actor_history kind/role/count`);
        if(row.targetId>0){requireRule(row.key==='event',`Condition ${id}: event ID requires event history`);get('AdventureEventTable',row.targetId);}
      }
      if (row.kind==='flag') requireRule(/^[A-Za-z_][A-Za-z0-9_]*$/.test(row.key),`Condition ${id}: invalid flag key`);
      if (['mission_state','quest_state'].includes(row.kind)) requireRule(['inactive','active','ready','completed'].includes(row.state),`Condition ${id}: unknown progress state`);
      if (row.kind==='time_window') requireRule(row.targetId>=0&&row.targetId<row.value&&row.value<=1440,`Condition ${id}: invalid time window`);
      if (row.kind==='npc_relation') {const npc=get('NpcTable',row.targetId);requireRule(row.value>=npc.relationMin&&row.value<=npc.relationMax,`Condition ${id}: relation outside range`);}
      if (row.kind==='faction_reputation') {const faction=get('FactionTable',row.targetId);requireRule(row.value>=faction.minValue&&row.value<=faction.maxValue,`Condition ${id}: reputation outside range`);}
      if (row.kind==='npc_recruited') requireRule(get('NpcTable',row.targetId).recruitable,`Condition ${id}: NPC is not recruitable`);
      if (!conditionTargets[row.kind]&&!['always','never','flag','time_window','coins','actor_history'].includes(row.kind)) warnings.push(`Condition ${id}: custom kind '${row.kind}' requires its registered Lua validator`);
    }
    requireRule(depth<=64,`Condition ${id}: depth exceeds 64`);visiting.delete(id);depths.set(id,depth);return depth;
  }
  for(const row of rows('ConditionTable')) condition(row.id);
  const leaves = id => {const result=[],pending=[id],seen=new Set();while(pending.length){const next=pending.pop();if(seen.has(next))continue;seen.add(next);const r=get('ConditionTable',next);if(r.conditionIds.length)pending.push(...r.conditionIds);else result.push(r);}return result;};
  const noKill = (id,label) => requireRule(!leaves(id).some(r=>r.kind==='kill_count'),`${label}: kill_count requires an accepted mission/quest context`);
  const noActor = (id,label) => requireRule(!leaves(id).some(r=>r.kind.startsWith('actor_')),`${label}: actor condition requires an interjection participant`);
  for(const name of ['MissionTable','QuestTable'])for(const row of rows(name))for(const field of ['startConditionId','completeConditionId'])noActor(row[field],`${name} ${row.id}`);
  for(const name of ['DialogueTable','DialogueChoiceTable'])for(const row of rows(name))noActor(row.conditionId,`${name} ${row.id}`);
  const interjectionsByNode=new Map();
  for(const row of rows('DialogueInterjectionTable')) {
    const node=get('DialogueNodeTable',row.nodeId);noKill(row.conditionId,`Interjection ${row.id}`);
    requireRule(row.cue.trim()&&row.text.trim(),`Interjection ${row.id}: cue and text are required`);
    requireRule(row.mode!=='auto'||row.nextNodeId===0,`Interjection ${row.id}: automatic speech cannot change nodes`);
    if(row.nextNodeId)requireRule(get('DialogueNodeTable',row.nextNodeId).dialogueId===node.dialogueId,`Interjection ${row.id}: cross-dialogue edge`);
    const group=interjectionsByNode.get(node.id)||[];group.push(row);interjectionsByNode.set(node.id,group);
  }
  for(const action of rows('NarrativeActionTable')) {
    if(actionTargets[action.kind])get(actionTargets[action.kind],action.targetId);
    if(action.kind==='grant_item')requireRule(action.value>0,`Action ${action.id}: grant must be positive`);
    if(action.kind==='grant_experience')requireRule(action.value>0&&action.targetId===0&&action.key==='',`Action ${action.id}: experience requires positive value and whole-party target`);
    if(action.kind==='set_flag')requireRule(/^[A-Za-z_][A-Za-z0-9_]*$/.test(action.key),`Action ${action.id}: invalid flag`);
    if(action.kind==='recruit_npc')requireRule(get('NpcTable',action.targetId).recruitable,`Action ${action.id}: NPC cannot recruit`);
  }
  for(const name of ['MissionTable','QuestTable'])for(const row of rows(name)) {
    if(name==='MissionTable')noKill(row.startConditionId,`${name}[${row.id}].startConditionId`);
    requireRule(new Set(row.actionIds).size===row.actionIds.length,`${name}[${row.id}]: duplicate reward action`);
    for(const id of row.actionIds)requireRule(!['accept_mission','claim_mission'].includes(get('NarrativeActionTable',id).kind),`${name}[${row.id}]: completion actions cannot accept/claim missions; use Conditions`);
  }
  const owners=new Map();
  for(const row of rows('TownMissionTable')) {
    requireRule(row.minCount>0&&row.minCount<=row.maxCount,`Town mission ${row.id}: invalid objective range`);
    if(row.kind==='delivery')requireRule(get('EquipmentItemTable',row.itemId).kind==='material',`Town mission ${row.id}: delivery requires material`);
    else requireRule(['clear','escort'].includes(row.kind)&&row.itemId===0,`Town mission ${row.id}: invalid kind/item`);
    requireRule(row.kind!=='clear'||row.radius>0,`Town mission ${row.id}: clear radius must be positive`);
    requireRule(row.kind!=='escort'||row.minCount===1&&row.maxCount===1,`Town mission ${row.id}: escort count must be one`);
    requireRule(row.actionIds.length>0&&new Set(row.actionIds).size===row.actionIds.length,`Town mission ${row.id}: missing or duplicate rewards`);
    for(const id of row.actionIds){const action=get('NarrativeActionTable',id);requireRule(['add_coins','grant_experience'].includes(action.kind)&&action.value>0,`Town mission ${row.id}: reward must be positive coins/experience`);}
  }
  for(const row of rows('TownMissionSettingsTable')) {
    requireRule(row.id===1&&row.minOffers>=1&&row.minOffers<=row.maxOffers&&row.maxOffers<=5,'Town mission settings: invalid daily count range');
    requireRule(get('WorldPartyTable',row.escortPartyDefinitionId).kind==='caravan','Town mission settings: escort requires caravan');
    requireRule(rows('TownMissionTable').filter(r=>r.kind!=='escort').length>=row.maxOffers,'Town missions: insufficient templates when no caravan route exists');
  }
  for(const node of rows('DialogueNodeTable')) {
    requireRule(node.text.trim(),`Dialogue node ${node.id}: empty text`);
    requireRule(new Set(node.choiceIds).size===node.choiceIds.length,`Dialogue node ${node.id}: duplicate choices`);
    for(const id of node.choiceIds) {
      requireRule(!owners.has(id)||owners.get(id)===node.dialogueId,`Choice ${id}: shared across different dialogues`);owners.set(id,node.dialogueId);
      const choice=get('DialogueChoiceTable',id);noKill(choice.conditionId,`Choice ${id}`);
      if(choice.worldAction==='attack')requireRule(choice.nextNodeId===0&&choice.actionIds.length===0&&get('NpcTable',get('DialogueTable',node.dialogueId).npcId).locationKind==='world_party',`Choice ${id}: attack requires a terminal world-party choice without reward actions`);
      if(choice.nextNodeId!==0)requireRule(get('DialogueNodeTable',choice.nextNodeId).dialogueId===node.dialogueId,`Choice ${id}: cross-dialogue edge`);
    }
  }
  for(const dialogue of rows('DialogueTable')) {
    noKill(dialogue.conditionId,`Dialogue ${dialogue.id}`);
    requireRule(get('DialogueNodeTable',dialogue.entryNodeId).dialogueId===dialogue.id,`Dialogue ${dialogue.id}: invalid entry`);
    const seen=new Set();const walk=id=>{if(seen.has(id))return;seen.add(id);for(const cid of get('DialogueNodeTable',id).choiceIds){const next=get('DialogueChoiceTable',cid).nextNodeId;if(next)walk(next);}for(const row of interjectionsByNode.get(id)||[])if(row.nextNodeId)walk(row.nextNodeId);};walk(dialogue.entryNodeId);
    for(const node of rows('DialogueNodeTable').filter(r=>r.dialogueId===dialogue.id))requireRule(seen.has(node.id),`Dialogue ${dialogue.id}: unreachable node ${node.id}`);
  }
  for(const npc of rows('NpcTable')) {
    requireRule(npc.relationMin<=npc.initialRelation&&npc.initialRelation<=npc.relationMax,`NPC ${npc.id}: invalid relation range`);
    for(const id of npc.dialogueIds)requireRule(get('DialogueTable',id).npcId===npc.id,`NPC ${npc.id}: foreign dialogue ${id}`);
    if(npc.locationKind==='world_party'){
      requireRule(!npc.recruitable&&!rows('NpcPlacementTable').some(r=>r.npcId===npc.id)&&!rows('NpcScheduleTable').some(r=>r.npcId===npc.id),`NPC ${npc.id}: world-party identity cannot use town placement, schedules or recruitment`);
      requireRule(rows('LegendaryEncounterTable').filter(r=>r.npcId===npc.id).length===1,`NPC ${npc.id}: requires one legendary world-party binding`);
      continue;
    }
    if(npc.locationKind==='event'){
      requireRule(npc.recruitable&&!rows('NpcPlacementTable').some(r=>r.npcId===npc.id)&&!rows('NpcScheduleTable').some(r=>r.npcId===npc.id),`NPC ${npc.id}: event identity must be recruitable without town placement or schedules`);
      const bindings=rows('SpecialEventTable').filter(r=>r.npcId===npc.id);
      requireRule(bindings.length===1&&bindings[0].allyUnitId===npc.actorTemplateId,`NPC ${npc.id}: requires one special-event binding with a matching ally template`);
      continue;
    }
    requireRule(npc.locationKind==='town',`NPC ${npc.id}: unknown location kind`);
    const placements=rows('NpcPlacementTable').filter(p=>p.npcId===npc.id);requireRule(placements.length===1,`NPC ${npc.id}: requires exactly one placement`);
    const placement=placements[0],area=get('MapAreaTable',placement.areaId);requireRule(area.areaType===2,`NPC ${npc.id}: requires a town`);
    const facilities=get('MapAreaTownTable',area.profileId).facilityIds;
    requireRule(facilities.includes(placement.facilityId),`NPC ${npc.id}: spawn facility absent`);
    const schedules=rows('NpcScheduleTable').filter(r=>r.npcId===npc.id).sort((a,b)=>a.startMinute-b.startMinute);
    let minute=0;for(const s of schedules){requireRule(s.startMinute===minute&&s.endMinute>s.startMinute,`NPC ${npc.id}: schedule gap/overlap`);requireRule(facilities.includes(s.facilityId),`NPC ${npc.id}: schedule facility absent`);minute=s.endMinute;}
    requireRule(minute===1440,`NPC ${npc.id}: schedule must cover 24 hours`);
  }
  const specialUnique=new Map(['key','npcId','areaId','encounterId','missionId','allyUnitId'].map(key=>[key,new Set()]));
  const specialEvents=new Set(),specialChoices=new Set();
  for(const row of rows('SpecialEventTable')){
    for(const [key,seen] of specialUnique){requireRule(!seen.has(row[key]),`Special event ${row.id}: duplicate ${key}`);seen.add(row[key]);}
    requireRule(/^[A-Za-z_][A-Za-z0-9_]*$/.test(row.key)&&row.townRadius>=0,`Special event ${row.id}: invalid key or town radius`);
    requireRule(Number.isInteger(row.initialHealthPercent)&&row.initialHealthPercent>=1&&row.initialHealthPercent<=100,`Special event ${row.id}: invalid initial health`);
    const injuryCount=row.initialInjuryPartIds.length;
    requireRule(row.initialInjuryTypeIds.length===injuryCount&&row.initialInjuryDamage.length===injuryCount&&row.injuryRecoveryMinutes.length===injuryCount&&new Set(row.initialInjuryPartIds).size===injuryCount,`Special event ${row.id}: injury arrays must match with unique body parts`);
    for(let i=0;i<injuryCount;i++){
      get('BodyPartTable',row.initialInjuryPartIds[i]);get('InjuryTypeTable',row.initialInjuryTypeIds[i]);
      requireRule(row.initialInjuryDamage[i]>=1&&row.initialInjuryDamage[i]<100&&row.injuryRecoveryMinutes[i]>0,`Special event ${row.id}: initial injuries must be recoverable`);
    }
    const npc=get('NpcTable',row.npcId),encounter=get('CombatEncounterTable',row.encounterId),areaEncounter=get('MapAreaEncounterTable',row.areaId);
    requireRule(npc.locationKind==='event'&&npc.recruitable&&npc.actorTemplateId===row.allyUnitId,`Special event ${row.id}: invalid recruit identity`);
    requireRule(Number.isInteger(row.allyIndex)&&row.allyIndex>=1&&row.allyIndex<=encounter.enemyIds.length&&encounter.enemyIds[row.allyIndex-1]===row.allyUnitId&&encounter.enemyIds.length>1&&encounter.enemyIds.filter(id=>id===row.allyUnitId).length===1,`Special event ${row.id}: invalid unique ally encounter slot`);
    requireRule(areaEncounter.encounterId===row.encounterId&&areaEncounter.groupCount===1,`Special event ${row.id}: area must contain exactly its configured encounter`);
    requireRule(get('MissionTable',row.missionId).actionIds.some(id=>{const action=get('NarrativeActionTable',id);return action.kind==='recruit_npc'&&action.targetId===npc.id;}),`Special event ${row.id}: mission must recruit its survivor`);
    for(const id of [row.eventId,row.sceneEventId]){get('AdventureEventTable',id);requireRule(!specialEvents.has(id),`Special event ${row.id}: duplicate world/scene event`);specialEvents.add(id);}
    for(const [id,eventId] of [[row.enterChoiceId,row.eventId],[row.battleChoiceId,row.sceneEventId],[row.leaveChoiceId,row.sceneEventId]]){
      get('AdventureChoiceTable',id);
      requireRule(!specialChoices.has(id),`Special event ${row.id}: duplicate choice`);specialChoices.add(id);
      const owners=rows('AdventureEventTable').filter(event=>event.choiceIds.includes(id));
      requireRule(owners.length===1&&owners[0].id===eventId,`Special event ${row.id}: choice ${id} belongs to another event`);
    }
  }
  const legendUnits=new Set(),legendFactions=new Set(),legendTraits=new Set();
  for(const legend of rows('LegendaryEncounterTable')){
    const party=get('WorldPartyTable',legend.id),npc=get('NpcTable',legend.npcId),encounter=get('CombatEncounterTable',party.encounterId),unit=get('CombatUnitTable',npc.actorTemplateId),policy=get('WorldFactionTable',party.factionId);
    requireRule(party.count===1&&party.kind==='hostile'&&encounter.enemyIds.length===1&&encounter.enemyIds[0]===unit.id,`Legend ${legend.id}: requires one unique actor`);
    requireRule(npc.locationKind==='world_party'&&npc.factionId===party.factionId&&!legendUnits.has(unit.id)&&!legendFactions.has(party.factionId),`Legend ${legend.id}: duplicate or mismatched identity/faction`);
    requireRule(policy.role==='wildlife'&&policy.siteCount===0&&policy.regionTypes.length>0,`Legend ${legend.id}: requires a roaming policy without a respawning garrison`);
    requireRule(rows('WorldPartyTable').filter(r=>r.factionId===party.factionId).length===1,`Legend ${legend.id}: diplomacy must belong to this individual`);
    requireRule(legend.defeatedFlag===''||/^[A-Za-z_][A-Za-z0-9_]*$/.test(legend.defeatedFlag),`Legend ${legend.id}: invalid defeated flag`);
    requireRule(npc.dialogueIds.some(id=>get('ConditionTable',get('DialogueTable',id).conditionId).kind==='always'),`Legend ${legend.id}: needs an unconditional fallback dialogue`);
    const traits=unit.traitIds.map(id=>get('CombatTraitTable',id)).filter(r=>r.rarity==='legendary');
    requireRule(traits.length>0,`Legend ${legend.id}: requires a legendary trait`);
    for(const trait of traits){requireRule(!legendTraits.has(trait.id),`Legend ${legend.id}: exclusive trait reused`);legendTraits.add(trait.id);}
    legendUnits.add(unit.id);legendFactions.add(party.factionId);
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
    if(table.name==='DialogueInterjectionTable'&&row.nextNodeId)add(key,`DialogueNodeTable:${row.nextNodeId}`,'nextNodeId');
    if(table.name==='ConditionTable'&&row.kind==='actor_history'&&row.targetId)add(key,`AdventureEventTable:${row.targetId}`,'actor history event');
    if(table.name==='TownMissionTable'&&row.kind==='delivery')add(key,`EquipmentItemTable:${row.itemId}`,'delivery');
  }
  const conditions=tables.find(t=>t.name==='ConditionTable')?.rows||[],actions=tables.find(t=>t.name==='NarrativeActionTable')?.rows||[];
  for(const condition of conditions.filter(c=>c.kind==='flag'))for(const action of actions.filter(a=>a.kind==='set_flag'&&a.key===condition.key))
    add(`ConditionTable:${condition.id}`,`NarrativeActionTable:${action.id}`,'reads flag:'+condition.key);
  for(const legend of tables.find(t=>t.name==='LegendaryEncounterTable')?.rows||[])for(const condition of conditions.filter(c=>c.kind==='flag'&&c.key===legend.defeatedFlag))
    add(`ConditionTable:${condition.id}`,`LegendaryEncounterTable:${legend.id}`,'reads defeated flag:'+condition.key);
  return {nodes,edges};
}

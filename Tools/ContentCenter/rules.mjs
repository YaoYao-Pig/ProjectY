const check=(ok,message)=>{if(!ok)throw new Error('Content: '+message);};
export function validateContent(tables) {
  const map=new Map(tables.map(t=>[t.name,t]));
  const rows=name=>map.get(name)?.rows||[];
  const get=(name,id)=>{const row=rows(name).find(r=>r.id===id);check(row,`${name}[${id}] missing`);return row;};
  const pairs=(name,a,b)=>{for(const r of rows(name))check(r[a].length===r[b].length,`${name}[${r.id}] ${a}/${b} length mismatch`);};
  for(const [name,a,b] of [['CombatUnitTable','attributeNames','attributeValues'],['EquipmentWearableTable','attributeNames','attributeValues'],['EquipmentRequirementTable','attributeIds','values'],['AdventureChoiceTable','itemIds','itemCounts'],['EquipmentLootTable','itemIds','counts'],['EquipmentDemoTable','starterItemIds','starterCounts']])pairs(name,a,b);
  for(const r of rows('EquipmentItemTable')) {
    const sub={weapon:'EquipmentWeaponTable',wearable:'EquipmentWearableTable',rune:'EquipmentRuneTable',module:'EquipmentRuneTable',magazine:'EquipmentMagazineTable'}[r.kind];
    if(sub)get(sub,r.id);
    check(r.width>0&&r.height>0,`Item ${r.id}: footprint must be positive`);
    check(r.iconRotation.length===3&&r.iconPadding>=1&&r.iconPadding<=2,`Item ${r.id}: invalid icon framing`);
  }
  for(const r of rows('EquipmentWeaponTable')) {
    check(get('EquipmentItemTable',r.id).kind==='weapon',`Weapon ${r.id}: item kind mismatch`);
    for(const id of r.socketIds)check(get('EquipmentSocketTable',id).weaponItemId===r.id,`Weapon ${r.id}: foreign socket`);
    if(r.magazineItemId)get('EquipmentMagazineTable',r.magazineItemId);
    if(r.offhandSkillId)get('CombatSkillTable',r.offhandSkillId);
  }
  for(const r of rows('EquipmentGripTable'))for(const key of ['mainPosition','mainRotation','offPosition','offRotation'])check(r[key].length===3,`Grip ${r.id}: ${key} must be Vector3`);
  const adjustments=new Set();for(const r of rows('EquipmentHoldAdjustmentTable')){const key=`${r.weaponId}:${r.moduleId}:${r.hand}`;check(!adjustments.has(key),`duplicate hold adjustment ${key}`);adjustments.add(key);check(r.rotationOffset.length===3,`Hold ${r.id}: rotationOffset must be Vector3`);}
  for(const r of rows('EquipmentSocketTable'))for(const key of ['position','rotation'])check(r[key].length===3,`Socket ${r.id}: ${key} must be Vector3`);
  const units=new Set();
  const match=(main,off,shield)=>rows('EquipmentMotionMatchTable').filter(r=>r.mainKind===(main?main.kind:'none')&&r.mainHands===(main?main.hands:0)&&r.offKind===(off?'weapon':shield?'shield':'none')&&r.gunClass===(main?main.gunClass:''));
  for(const weapon of rows('EquipmentWeaponTable'))check(match(weapon,false,false).length===1,`Weapon ${weapon.id}: requires exactly one motion module match`);
  for(const r of rows('CharacterLoadoutTable')) {
    check(!units.has(r.unitId),`duplicate loadout for unit ${r.unitId}`);units.add(r.unitId);
    const slots=new Set();
    for(const id of r.wearableIds){const w=get('EquipmentWearableTable',id);check(!slots.has(w.slot),`Loadout ${r.id}: duplicate slot ${w.slot}`);slots.add(w.slot);}
    const main=r.weaponId&&get('EquipmentWeaponTable',r.weaponId),off=r.offhandWeaponId&&get('EquipmentWeaponTable',r.offhandWeaponId);
    check(!off||off.hands===1,`Loadout ${r.id}: offhand weapon must be one-handed`);
    check(!off||!slots.has('offhand'),`Loadout ${r.id}: shield and offhand weapon conflict`);
    check(!main||main.hands!==2||!off&&!slots.has('offhand'),`Loadout ${r.id}: two-handed weapon requires free offhand`);
    check(match(main,off,slots.has('offhand')).length===1,`Loadout ${r.id}: requires exactly one motion module match`);
    if(r.appearanceJson){let appearance;try{appearance=JSON.parse(r.appearanceJson);}catch{throw new Error(`Content: Loadout ${r.id}: malformed appearance JSON`);}
      check(appearance&&appearance.version===1&&Number.isInteger(appearance.seed)&&appearance.seed>=0&&appearance.seed<=2147483647,`Loadout ${r.id}: invalid appearance version/seed`);
      for(const key of ['race','sex','body','head','hair'])check(typeof appearance[key]==='string'&&appearance[key].length>0,`Loadout ${r.id}: missing appearance ${key}`);
      for(const key of ['skin','hairColor','clothColor'])check(Number.isInteger(appearance[key])&&appearance[key]>=0,`Loadout ${r.id}: invalid ${key}`);
    }
  }
  for(const npc of rows('NpcTable'))if(npc.recruitable){
    for(const name of ['GrowthProfileTable','PawnTemplateTable'])check(rows(name).filter(r=>r.unitId===npc.actorTemplateId).length===1,`NPC ${npc.id}: requires one ${name} for recruit template`);
  }
}

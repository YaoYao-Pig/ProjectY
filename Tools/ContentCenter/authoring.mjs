// Pure recipes: return rows for review; never write, export, or invent a model.
export function createAuthoring(tables){
  const table=name=>{const t=tables.find(t=>t.name===name);if(!t)throw new Error('缺少表 '+name);return t;};
  const row=(name,id)=>{const r=table(name).rows.find(r=>r[table(name).key]===id);if(!r)throw new Error('缺少记录 '+name+':'+id);return r;};
  const counters=new Map();
  const next=name=>{const id=(counters.get(name)??Math.max(0,...table(name).rows.map(r=>r.id)))+1;counters.set(name,id);return id;};
  const operations=[],put=(name,r)=>{operations.push({op:'upsert',table:name,row:r});return r;};
  const clone=(name,id,changes={})=>put(name,{...structuredClone(row(name,id)),id:next(name),...changes});
  return {
    item({name,modelPath,templateId}){
      if(!name.trim()||!modelPath?.startsWith('Assets/'))throw new Error('名称和工程内模型必填');
      const original=row('EquipmentItemTable',templateId),id=next('EquipmentItemTable'),assetId=next('EquipmentAssetTable');
      // Fitted clothing is resolved by its authored source path in PawnCustomizationCatalog.
      const fitted=original.kind==='wearable'&&['head','chest','legs','feet','back'].includes(row('EquipmentWearableTable',templateId).mount);
      put('EquipmentAssetTable',{id:assetId,name,modelPath,prefabPath:fitted?modelPath:`Assets/DynamicAsset/ContentCenter/Prefabs/Asset_${assetId}.prefab`});
      put('EquipmentItemTable',{...structuredClone(original),id,name,assetId,iconMode:'model',iconPath:`Assets/DynamicAsset/ContentCenter/Icons/Item_${id}.png`});
      const subtype={weapon:'EquipmentWeaponTable',wearable:'EquipmentWearableTable',rune:'EquipmentRuneTable',module:'EquipmentRuneTable',magazine:'EquipmentMagazineTable'}[original.kind];
      if(subtype){const rule={...structuredClone(row(subtype,templateId)),id};
        if(original.kind==='weapon'){
          rule.gripId=clone('EquipmentGripTable',rule.gripId,{name:name+' · 握点'}).id;
          rule.socketIds=rule.socketIds.map(s=>clone('EquipmentSocketTable',s,{weaponItemId:id}).id);
          rule.requirementId=clone('EquipmentRequirementTable',rule.requirementId).id;
        }put(subtype,rule);
      }
      return {operations,selection:{table:'EquipmentItemTable',id}};
    },
    npc({name,templateId,areaId,facilityId,recruitable}){
      if(!name.trim())throw new Error('请填写名称');
      const original=row('NpcTable',templateId),id=next('NpcTable');
      const unit=clone('CombatUnitTable',original.actorTemplateId,{name});
      for(const type of ['GrowthProfileTable','PawnTemplateTable']){
        const source=table(type).rows.find(r=>r.unitId===original.actorTemplateId);if(!source)throw new Error('原型缺少 '+type);
        clone(type,source.id,{unitId:unit.id,...(type==='PawnTemplateTable'?{name}: {})});
      }
      const town=clone('MapAreaTownNpcTable',original.townTemplateId,{name});
      put('NpcTable',{...structuredClone(original),id,name,description:'',actorTemplateId:unit.id,townTemplateId:town.id,recruitable,dialogueIds:[],missionIds:[]});
      put('NpcPlacementTable',{id:next('NpcPlacementTable'),npcId:id,areaId,facilityId});
      put('NpcScheduleTable',{id:next('NpcScheduleTable'),npcId:id,startMinute:0,endMinute:1440,facilityId,activity:'停留'});
      put('CharacterLoadoutTable',{id:next('CharacterLoadoutTable'),unitId:unit.id,weaponId:0,offhandWeaponId:0,wearableIds:[],appearanceJson:''});
      return {operations,selection:{table:'NpcTable',id}};
    },
  };
}

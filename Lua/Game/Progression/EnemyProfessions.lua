-- Enemy careers use the saved birth profession; equipment and supported courses remain config projections.
local Random=require('Game.Map.SeededRandom')
local Rules={};Rules.__index=Rules
local function contains(values,value)for _,item in ipairs(values)do if item==value then return true end end;return false end
function Rules.New(config)
    local self=setmetatable({units=config:GetTable('CombatUnitTable'),professions=config:GetTable('ProfessionTable'),
        skills=config:GetTable('CombatSkillTable'),weapons=config:GetTable('EquipmentWeaponTable'),
        combat=config:GetTable('ProfessionCombatTable'),courses={},pool={},namedActors={},namedUnits={},plans={}},Rules)
    local construction=config:GetTable('ConstructionTable')
    local legendary=config:GetTable('LegendaryEquipmentTable')
    for _,npc in ipairs(config:GetTable('NpcTable'):All())do
        self.namedActors[10000+npc.id]=true
        if npc.locationKind=='world_party' then self.namedUnits[npc.actorTemplateId]=true end
    end
    for _,event in ipairs(config:GetTable('SpecialEventTable'):All())do self.namedUnits[event.allyUnitId]=true end
    for _,profession in ipairs(self.professions:All())do
        self.pool[#self.pool+1]=profession.id;self.courses[profession.id]={}
    end
    table.sort(self.pool);assert(#self.pool>0,'Enemy profession pool is empty')
    for _,course in ipairs(config:GetTable('ProfessionSkillTable'):All())do
        local skill=self.skills:Get(course.skillId);local combat=self.combat:Find(skill.id)
        -- Enemies cannot spend the player's materials or command a companion they do not own.
        if course.minLevel==1 and (contains(skill.contexts,'battle') or contains(skill.contexts,'preparation'))
            and skill.skillGroup~='animal' and not construction:Find(skill.id) and (not combat or combat.materialId==0) then
            local rows=assert(self.courses[course.professionId]);rows[#rows+1]=skill.id
        end
    end
    for _,rows in pairs(self.courses)do table.sort(rows)end
    local weapons={}
    for _,weapon in ipairs(self.weapons:All())do
        if not legendary:Find(weapon.id) and weapon.kind~='gun' then weapons[#weapons+1]=weapon end
    end
    table.sort(weapons,function(a,b)
        if a.level~=b.level then return a.level<b.level end
        if a.hands~=b.hands then return a.hands<b.hands end
        return a.id<b.id
    end)
    assert(#weapons>0,'Enemy professions need an ordinary weapon')
    for _,professionId in ipairs(self.pool)do
        local best,bestScore
        for _,weapon in ipairs(weapons)do
            local score=0
            for _,id in ipairs(self.courses[professionId])do
                if self:Supports(weapon,self.skills:Get(id)) then score=score+1 end
            end
            if not best or score>bestScore then best,bestScore=weapon,score end
        end
        self.plans[professionId]=best.id
    end
    return self
end
function Rules:Eligible(actor)
    return self.units:Get(actor.TemplateId).bodyInjuries and not self.namedActors[actor.Id] and not self.namedUnits[actor.TemplateId]
end
function Rules:Choose(actor,seed)
    if not self:Eligible(actor) then return nil end
    local mixed=(seed ~ actor.Id ~ 0x35b8ac71)&0xffffffff
    mixed=((mixed ~ (mixed>>16))*0x45d9f3b)&0xffffffff
    mixed=((mixed ~ (mixed>>16))*0x45d9f3b)&0xffffffff
    return self.pool[Random((mixed ~ (mixed>>16))&0xffffffff):Integer(1,#self.pool)]
end
function Rules:Active(actor)
    return actor.Team~=nil and actor.Team>=2 and actor.HasInitialAttributes and actor.InitialProfessionId>0 and self:Eligible(actor)
end
function Rules:Supports(weapon,skill)
    if skill.catalystKind~='none' and weapon.catalystKind~=skill.catalystKind then return false end
    local combat=self.combat:Find(skill.id)
    if combat and combat.requiredEquipment~='' then
        local required=combat.requiredEquipment
        -- A single free hand does not imply that this actor actually owns a shield.
        if required=='shield' then return false end
        if required~='weapon' and weapon.kind~=required then return false end
    end
    if skill.skillGroup=='weapon' or skill.skillGroup=='slash' then
        for _,id in ipairs(weapon.skillIds)do
            if self.skills:Get(id).proficiency==skill.proficiency then return true end
        end
        return false
    end
    return true
end
function Rules:SkillIds(actor,template)
    if not self:Active(actor) then return template.skillIds end
    local result,seen={},{}
    for _,id in ipairs(template.skillIds)do
        local skill=self.skills:Get(id)
        if skill.skillGroup=='support' then result[#result+1]=id;seen[id]=true end
    end
    local weapon=self.weapons:Get(assert(self.plans[actor.InitialProfessionId]))
    for _,id in ipairs(self.courses[actor.InitialProfessionId])do
        if not seen[id] and self:Supports(weapon,self.skills:Get(id)) then result[#result+1]=id;seen[id]=true end
    end
    return result
end
function Rules:Loadout(actor,main,off,items,slots)
    if not self:Active(actor) then return main,off,items,slots end
    local planned=assert(self.plans[actor.InitialProfessionId],'Missing enemy profession equipment plan')
    local keep=main~=0
    if keep then
        local original,selected=self.weapons:Get(main),self.weapons:Get(planned)
        for _,id in ipairs(self.courses[actor.InitialProfessionId])do
            local skill=self.skills:Get(id)
            if self:Supports(original,skill)~=self:Supports(selected,skill) then keep=false;break end
        end
    end
    if not keep then main=planned end
    if self.weapons:Get(main).hands==2 then
        off=0
        for i=#slots,1,-1 do if slots[i]=='offhand' then table.remove(items,i);table.remove(slots,i)end end
    end
    return main,off,items,slots
end
return Rules

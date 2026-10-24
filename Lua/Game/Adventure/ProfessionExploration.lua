-- Profession exploration acts on real area objects; persistent facts belong to NarrativeData.
local L=require('Language')
local Hex=require('Game.Map.HexGrid')
local Exploration={};Exploration.__index=Exploration
local supported={extract=true,rumor=true,care=true,curse=true,track=true}
local function fact(kind,...)
    local parts={...};for i,v in ipairs(parts) do parts[i]=tostring(v) end
    return 'flag:profession_'..kind..'_'..table.concat(parts,'_')
end
function Exploration.New(adventure)
    return setmetatable({adventure=adventure,rules=adventure.config:GetTable('ProfessionExplorationTable'),
        curses=adventure.config:GetTable('ProfessionCurseTable'),areas=adventure.config:GetTable('MapAreaTable'),
        forests=adventure.config:GetTable('MapAreaForestTable')},Exploration)
end
function Exploration:Data() return self.adventure.data.Narrative end
function Exploration:Day() return math.floor(self:Data().Minutes/1440)+1 end
function Exploration:Origin(actor)
    local state=self.adventure.data.Areas.Active;local area=self.adventure.areas:ActiveLayout()
    for i=0,state.MemberCount-1 do
        if state:GetMemberIdAt(i)==actor.Id then return area.cells[state:GetMemberCellAt(i)] end
    end
end
function Exploration:Actor(id)
    for i=0,self.adventure.data.PartyCount-1 do local actor=self.adventure.data:GetPartyAt(i);if actor.Id==id then return actor end end
end
function Exploration:Visible(index)
    local state=self.adventure.data.Areas.Active
    for i=0,state.VisibleCount-1 do if state:GetVisibleAt(i)==index then return true end end
    return false
end
function Exploration:Near(actor,cell,range,path)
    local origin=self:Origin(actor);if not origin or not cell or not self:Visible(cell.index) then return false end
    local area=self.adventure.areas:ActiveLayout()
    if path then local route=area:FindPath(origin.index,cell.index);return route~=nil and #route<=range end
    return origin.layer==cell.layer and Hex.Distance(origin.q,origin.r,cell.q,cell.r)<=range and area:CanSee(origin,cell)
end
function Exploration:Facility(actor,kind,range)
    local siteId=self.adventure.data.Areas.ActiveSiteId
    local allowed,reason=self.adventure.factions:ServiceAllowed(siteId);if not allowed then return nil,reason end
    local area=self.adventure.areas:ActiveLayout()
    for _,row in ipairs(area.facilities) do
        if row.kind==kind and self:Near(actor,area.cells[row.entryIndex],range,true) then return row end
    end
    return nil,L.ProfessionExploreFacility
end
function Exploration:Record(actor,row,message)
    self.adventure.growth.chronicle:Record('event',actor,self.adventure.config:GetTable('CombatSkillTable'):Get(row.id).name,
        message,self.adventure.areas:ActiveLayout().name,false)
end
function Exploration:Advance(row) self.adventure.narrative:AdvanceMinutes(row.minutes) end
function Exploration:Plant(actor,row)
    local area=self.adventure.areas:ActiveLayout()
    if area.areaType~=self.adventure.areas.forestType then return end
    local profile=self.forests:Get(self.areas:Get(area.configId).profileId)
    local site=self.adventure.data.Areas.ActiveSiteId
    for i,prop in ipairs(area.props) do
        if prop.assetId==profile.fernAssetId and self:Data():GetValue(fact('plant',site,i))==0 then
            local cell=area:Find(prop.q,prop.r,prop.layer)
            if self:Near(actor,cell,row.range,false) then return i end
        end
    end
end
function Exploration:Rumor(actor,row)
    local facility,reason=self:Facility(actor,'tavern',row.range);if not facility then return nil,reason end
    local siteId=self.adventure.data.Areas.ActiveSiteId;local source=assert(self.adventure.sites[siteId])
    if self:Data():GetValue(fact('rumor_day',siteId))==self:Day() then return nil,L.ProfessionExploreDaily end
    local selected,nearest
    for _,site in ipairs(self.adventure.sites) do
        if site.id~=siteId and not self.adventure.data:HasVisited(site.id) and self:Data():GetValue(fact('rumor_known',site.id))==0 then
            local distance=Hex.Distance(source.q,source.r,site.q,site.r)
            if distance<=row.amount and (not nearest or distance<nearest or distance==nearest and site.id<selected.id) then selected,nearest=site,distance end
        end
    end
    if not selected then return nil,L.ProfessionExploreNoRumor end
    return {facility=facility,site=selected}
end
function Exploration:CurseWeapon(actor)
    local data=self.adventure.equipment.data
    for hand=1,2 do
        local weapon
        if hand==1 then weapon=data:Equipped(actor.Id) else weapon=data:Offhand(actor.Id) end
        if weapon then local row=self.curses:Find(weapon.ItemId)
            if row and self:Data():GetValue(fact('curse_clean',weapon.Id))==0 then return weapon,row end
        end
    end
end
function Exploration:OnEquip(actor,weapon)
    local row=self.curses:Find(weapon.ItemId);if not row then return end
    local data=self:Data()
    if data:GetValue(fact('curse_clean',weapon.Id))~=0 or data:GetValue(fact('curse_owner',weapon.Id))~=0 then return end
    local before={};for i=0,actor.Effects.Count-1 do before[actor.Effects:GetAt(i).Id]=true end
    assert(self.adventure.battle.gameEffects:Apply(row.applyEffectId,actor,actor))
    local applied
    for i=0,actor.Effects.Count-1 do local effect=actor.Effects:GetAt(i)
        if effect.EffectId==row.triggerBuffId and not before[effect.Id] then assert(not applied,'Curse must create one independent effect');applied=effect.Id end
    end
    assert(applied,'Cursed equipment must create an independent persistent buff')
    data:SetValue(fact('curse_owner',weapon.Id),actor.Id);data:SetValue(fact('curse_effect',weapon.Id),applied)
end
function Exploration:ObserveTracks()
    local adventure=self.adventure;if adventure.data.Phase~='area' then return end
    local area,state=adventure.areas:ActiveLayout(),adventure.data.Areas.Active
    local siteId=adventure.data.Areas.ActiveSiteId;local data=self:Data()
    for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
        for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j)
            if actor.HP>0 and actor.AnimalOwnerId==0 and adventure.battle.stats.animals.byUnit[actor.TemplateId] then
                local cell=area:Find(actor.Q,actor.R)
                if cell and self:Visible(cell.index) then
                    local key=fact('track',siteId,actor.Id);local old=data:GetValue(key..'_current')
                    if old~=cell.index then
                        data:SetValue(key..'_previous',old);data:SetValue(key..'_current',cell.index)
                        data:SetValue(key..'_time',math.floor(data.Minutes)+1);data:SetValue(key..'_template',actor.TemplateId)
                    end
                end
            end
        end
    end
end
function Exploration:Track(actor,row)
    local area=self.adventure.areas:ActiveLayout();local data=self:Data();local origin=self:Origin(actor)
    if not origin then return end
    local prefix=fact('track',self.adventure.data.Areas.ActiveSiteId)..'_';local best,nearest
    for i=0,data.ValueCount-1 do local key=data:GetValueKeyAt(i)
        if key:sub(1,#prefix)==prefix and key:sub(-8)=='_current' then
            local stem=key:sub(1,-9);local current=data:GetValue(key);local previous=data:GetValue(stem..'_previous')
            local minute=data:GetValue(stem..'_time')-1
            local cell=area.cells[previous>0 and previous or current]
            if minute>=0 and data.Minutes-minute<=row.amount and cell then
                local distance=Hex.Distance(origin.q,origin.r,cell.q,cell.r)
                if distance<=row.range and (not nearest or distance<nearest) then
                    local currentCell=assert(area.cells[current]);best={previous=previous,current=current,minute=minute,
                        from=cell,to=currentCell,templateId=data:GetValue(stem..'_template')};nearest=distance
                end
            end
        end
    end
    return best
end
function Exploration:CanUse(actor,targetId,row)
    if not self:Origin(actor) then return false,L.ProfessionExploreNotDeployed end
    if row.kind=='extract' then
        if not self:Plant(actor,row) then return false,L.ProfessionExploreNoPlant end
        if not self.adventure.equipment:CanGrant({row.rewardItemId},{row.rewardCount}) then return false,L.ProfessionExploreBagFull end
    elseif row.kind=='rumor' then local result,reason=self:Rumor(actor,row);if not result then return false,reason end
    elseif row.kind=='care' then
        local target=self:Actor(targetId)
        if not target or target.HP<=0 or not self:Near(actor,self:Origin(target),row.range,false) then return false,L.ProfessionExploreCareTarget end
        if self:Data():GetValue(fact('care_day',target.Id))==self:Day() then return false,L.ProfessionExploreDaily end
        if not CS.ProjectY.Data.ProfessionExplorationState.CanCare(target,self:Data().Minutes,row.minutes) then return false,L.ProfessionExploreNoRecovery end
        if self.adventure.equipment.data:CountItem(row.itemId)<row.itemCount then return false,L.ProfessionExploreCareMaterial end
    elseif row.kind=='curse' then
        local weapon,curse=self:CurseWeapon(actor);if not weapon then return false,L.ProfessionExploreNoCurse end
        if self:Data():GetValue(fact('curse_known',weapon.Id))~=0 and self.adventure.equipment.data:CountItem(curse.cleanseItemId)<1 then return false,L.ProfessionExploreCleanseMaterial end
    elseif row.kind=='track' then if not self:Track(actor,row) then return false,L.ProfessionExploreNoTrack end
    else error('Unsupported profession exploration kind: '..row.kind) end
    return true,''
end
function Exploration:Use(actor,targetId,row)
    local ok,reason=self:CanUse(actor,targetId,row);if not ok then return false,reason end
    local data=self:Data();local message
    if row.kind=='extract' then
        local index=assert(self:Plant(actor,row));assert(self.adventure.equipment:Grant(row.rewardItemId,row.rewardCount))
        data:SetValue(fact('plant',self.adventure.data.Areas.ActiveSiteId,index),1)
        message=string.format(L.ProfessionExploreExtracted,self.adventure.equipment.rules.items:Get(row.rewardItemId).name,row.rewardCount)
    elseif row.kind=='rumor' then
        local rumor=assert(self:Rumor(actor,row));data:SetValue(fact('rumor_day',self.adventure.data.Areas.ActiveSiteId),self:Day())
        data:SetValue(fact('rumor_known',rumor.site.id),1)
        message=string.format(L.ProfessionExploreRumor,rumor.facility.name,rumor.site.name,rumor.site.q,rumor.site.r)
    elseif row.kind=='care' then
        local target=assert(self:Actor(targetId))
        assert(CS.ProjectY.Data.ProfessionExplorationState.Care(target,self.adventure.equipment.data,row.itemId,row.itemCount,data.Minutes,row.minutes,row.amount))
        data:SetValue(fact('care_day',target.Id),self:Day())
        message=string.format(L.ProfessionExploreCared,self.adventure.battle.stats:Template(target).name,row.amount)
    elseif row.kind=='curse' then
        local weapon,curse=self:CurseWeapon(actor)
        if data:GetValue(fact('curse_known',weapon.Id))==0 then
            data:SetValue(fact('curse_known',weapon.Id),1);message=curse.description..'\n'..curse.clue
        else
            self.adventure.equipment.data:ConsumeStack(curse.cleanseItemId,1)
            local owner=self:Actor(data:GetValue(fact('curse_owner',weapon.Id)));local effectId=data:GetValue(fact('curse_effect',weapon.Id))
            if owner then for i=0,owner.Effects.Count-1 do
                if owner.Effects:GetAt(i).Id==effectId then self.adventure.battle.gameEffects:Remove(owner,effectId);break end
            end end
            data:SetValue(fact('curse_clean',weapon.Id),1)
            message=string.format(L.ProfessionExploreCleansed,self.adventure.equipment.rules.items:Get(weapon.ItemId).name)
        end
    elseif row.kind=='track' then
        local trace=assert(self:Track(actor,row));local name=self.adventure.battle.stats.units:Get(trace.templateId).name
        message=string.format(trace.previous>0 and L.ProfessionExploreTrackMoved or L.ProfessionExploreTrackStill,
            name,trace.from.q,trace.from.r,trace.to.q,trace.to.r,math.floor(data.Minutes-trace.minute))
    end
    self:Advance(row);self:Record(actor,row,message);return true,message
end
function Exploration:RegisterHandlers(skills)
    for _,definition in ipairs(self.rules:All()) do if supported[definition.kind] then
        local row=definition
        skills:Register('profession_life_'..row.kind,{
            CanUse=function(actor,id)return self:CanUse(actor,id,row)end,
            Use=function(actor,id)return self:Use(actor,id,row)end,
            Targets=function(actor)
                if row.kind~='care' then return {actor.Id} end
                local targets={};for i=0,self.adventure.data.PartyCount-1 do local target=self.adventure.data:GetPartyAt(i)
                    if target.HP>0 and self:Origin(target) then targets[#targets+1]=target.Id end
                end
                return targets
            end})
    end end
end
return Exploration

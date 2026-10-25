-- GM 只选择当前场景的独立敌人/动物；生命、倒地清理及掉落仍归原系统。
local LuaLanguage=require('Language')
local Kill={};Kill.__index=Kill
function Kill.New(adventure) return setmetatable({adventure=adventure},Kill) end
function Kill:Target(id)
    local adventure=self.adventure;local phase=adventure.data.Phase
    if phase~='battle' and phase~='area' then return nil,LuaLanguage.GMKillRequiresScene end
    if adventure.narrative.data.DialogueOpen then return nil,LuaLanguage.GMKillDialogueOpen end
    if type(id)~='number' or id%1~=0 or id<=0 then return nil,LuaLanguage.GMKillInvalidTarget end
    local target
    if phase=='battle' then
        if adventure.battle.data.Winner~='' then return nil,LuaLanguage.GMKillBattleEnded end
        target=adventure.battle:FindUnit(id)
    else
        local state=adventure.data.Areas.Active
        for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
            for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j)
                if actor.Id==id then target=actor;break end
            end
            if target then break end
        end
    end
    if not target then return nil,LuaLanguage.GMKillInvalidTarget end
    if target.Team==1 or target.AnimalOwnerId~=0 then return nil,LuaLanguage.GMKillProtectedTarget end
    local hostile=phase=='battle' and adventure.battle:IsHostile(1,target) or phase=='area' and target.Team==2
    if not hostile and not (target.Team==0 and target.AnimalSpeciesId>0) then return nil,LuaLanguage.GMKillProtectedTarget end
    if target.HP<=0 then return nil,LuaLanguage.GMKillAlreadyDefeated end
    return target
end
function Kill:Execute(id)
    local target,reason=self:Target(id);if not target then return false,reason end
    local adventure=self.adventure;local battle=adventure.battle;local effects=battle.gameEffects
    -- 当前骑乘契约只允许玩家持有坐骑，而玩家与其动物已在目标边界排除。
    assert(not target.MountedAnimal,'GM enemy target cannot be a player rider')
    local name=battle.stats:Template(target).name;local before=target.HP
    local amount=target:Damage(before)
    assert(target.HP==0,'GM lethal damage did not defeat the target')
    local message=string.format(LuaLanguage.GMKillSuccess,name)
    effects:Notify('damage',message,0,target,amount,false,{hpBefore=before,hpAfter=0,maxHP=target.MaxHP,
        shot=1,critical=false,defeated=true,damageColor='',sourceName=LuaLanguage.GMKillSource,actionName=LuaLanguage.GMKillSource})
    effects:Notify('defeated',message,0,target,0)
    effects:Clear(target,'death');battle.professions:OnDefeated(target)
    if adventure.data.Phase=='battle' then
        if not battle:CheckWinner() and battle.data.ActiveId==target.Id then battle:AdvanceTurn() end
        if adventure.data.AreaEncounterId>0 then adventure.areas:RevealBattle(battle) end
        adventure:SettleBattle()
    else
        adventure.equipment:GenerateActorDrops(adventure.areas,{target},battle.stats)
    end
    return true,message
end
return Kill

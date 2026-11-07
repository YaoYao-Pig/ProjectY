local L=require('Language')
local Identity=require('Game.Presentation.CharacterIdentity')
local Roster={};Roster.__index=Roster
local function native() return CS.ProjectY.Data.PartyRoster end
function Roster.New(model)
    return setmetatable({model=model,adventure=model.adventure,rule=model.adventure.config:GetTable('CampRosterTable'):Get(1)},Roster)
end
function Roster:Advance(now)
    native().AdvanceRecovery(self.adventure.data,now,self.rule.healthPerDay,self.rule.traumaPerDay,self.rule.scheduleSpeed)
end
function Roster:Move(id,reserve,revision)
    local ok,reason=self.model:Session(revision);if not ok then return false,reason end
    self.adventure.narrative:TickBuffs()
    reason=native().Move(self.adventure.data,id,reserve,revision)
    if reason~='' then return false,assert(L[reason]) end
    self.adventure.fog:Update();return true
end
function Roster:Swap(activeId,reserveId,revision)
    local ok,reason=self.model:Session(revision);if not ok then return false,reason end
    self.adventure.narrative:TickBuffs()
    reason=native().Swap(self.adventure.data,activeId,reserveId,revision)
    if reason~='' then return false,assert(L[reason]) end
    self.adventure.fog:Update();return true
end
function Roster:Build(s,state)
    local a=self.adventure;local data=a.data;local bridge=native();local selected
    s.panelTitle=L.RosterTitle;s.panelSubtitle=string.format(L.RosterCounts,data.PartyCount,bridge.ActiveLimit,bridge.ReserveCount(data),bridge.ReserveLimit)
    for i=0,bridge.Count(data)-1 do
        local actor=bridge.At(data,i);local reserve=bridge.IsReserve(data,actor.Id)
        if not state.swapActiveId or reserve then
            local identity=Identity.Read(a.battle.stats,actor)
            local row={key=tostring(actor.Id),actor=actor,identity=identity,reserve=reserve,title=Identity.Format(identity,20,12,'E3BE73'),itemId=0,iconPath='',
                subtitle=string.format(L.RosterMemberStatus,reserve and L.RosterReserve or L.RosterActive,actor.Growth.Level,actor.HP,actor.MaxHP)}
            s.rows[#s.rows+1]=row;if row.key==state.selected then selected=row end
        end
    end
    selected=selected or assert(s.rows[1],'Camp requires a roster member');state.selected=selected.key
    for _,row in ipairs(s.rows) do row.selected=row==selected end
    local actor=selected.actor
    s.detailTitle=Identity.Format(selected.identity,25,14,'805723');s.detailText=string.format(L.RosterRecoveryHelp,self.rule.healthPerDay*100,self.rule.traumaPerDay,self.rule.scheduleSpeed)
    local injuries={};local body=CS.ProjectY.Data.BodyHealth
    for part=0,5 do
        local name=a.config:GetTable('BodyPartTable'):Get(part+1).name
        injuries[#injuries+1]=string.format(L.RosterBodyStatus,name,body.HP(actor,part),body.MaximumHP(actor,part),body.Damage(actor,part),body.Permanent(actor,part) and L.RosterPermanent or '')
    end
    s.detailText=s.detailText..'\n\n'..table.concat(injuries,'\n')
    local _,_,_,needs=a.economy:Needs()
    for _,row in ipairs(needs) do if row.actor.Id==actor.Id then s.cost=string.format(L.RosterDailyCost,row.food,row.wage);break end end
    s.previewPawn=a.appearances:Template(actor.TemplateId,a.equipment.rules:ActorVisual(actor),actor.CustomizationJson)
    if state.swapActiveId then
        s.actionLabel=L.RosterConfirmSwap;s.actionEnabled=true;s.operation={command='camp_roster_swap',id=state.swapActiveId,count=actor.Id}
        s.secondary[1]={title=L.RosterCancelSwap,available=true};s.status=L.RosterChooseReplacement
    else
        local reserve=not selected.reserve;local reason=bridge.CanMove(data,actor.Id,reserve)
        s.actionLabel=reserve and L.RosterRestAction or L.RosterDeployAction;s.actionEnabled=reason=='';s.reason=reason=='' and '' or assert(L[reason])
        s.operation={command='camp_roster_move',id=actor.Id,count=reserve and 1 or 0}
        if not selected.reserve and bridge.ReserveCount(data)>0 then s.secondary[1]={title=L.RosterSwapAction,available=true} end
    end
    return s
end
return Roster

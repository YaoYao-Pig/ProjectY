local L=require('Language')
local Hex=require('Game.Map.HexGrid')
local Board=require('Game.Battle.BattleBoard')
local Duels={};Duels.__index=Duels
local function bridge()return CS.ProjectY.Data.ProfessionDuelState end
function Duels:RegisterHandler(skills)
    skills:Register(self.adventure.config:GetTable('CombatSkillTable'):Get(self.skill.id).skillGroup,{
        CanUse=function(actor,id)return self:CanUse(actor,id)end,
        Use=function(actor,id)return self:Use(actor,id)end,
        Targets=function(actor)return {actor.Id}end,
    })
end
function Duels.Register(skills,adventure)
    local self=setmetatable({adventure=adventure,rule=adventure.config:GetTable('ProfessionDuelTable'):Get(1)},Duels)
    for _,row in ipairs(adventure.config:GetTable('ProfessionExplorationTable'):All())do if row.kind=='duel'then
        assert(not self.skill,'Duplicate duel exploration ability');self.skill=row
    end end
    assert(self.skill,'Missing duel exploration ability')
    local encounter=adventure.config:GetTable('CombatEncounterTable'):Get(self.rule.encounterId)
    assert(#encounter.enemyIds==1 and encounter.rewardCoins==0 and encounter.experience==0,'Duel requires one opponent without ordinary rewards')
    self.encounter=encounter;adventure.professionDuels=self;self:RegisterHandler(skills)
end
function Duels:DailyKey()return 'flag:profession_duel_day_'..self.adventure.data.Areas.ActiveSiteId end
function Duels:Plan(actor)
    local adventure=self.adventure;local area=adventure.areas:ActiveLayout();local origin=adventure.professionExploration:Origin(actor)
    if not origin or origin.layer~=0 then return nil,L.ProfessionDuelGroundOnly end
    local board=Board.FromArea(area,origin.q,origin.r,self.encounter.radius,0)
    -- A duel uses the actual ground floor and never folds upstairs cells onto it.
    local cells={};for _,cell in ipairs(board.cells)do
        if cell.layer==0 then cells[#cells+1]=cell else board.byIndex[cell.index]=nil;board.byKey[Hex.Key(cell.q,cell.r)..':'..cell.layer]=nil end
    end
    board.cells=cells;board.externalOccupied=adventure.battle.beasts:AreaOccupied(adventure,{[actor.Id]=true})
    board.allowed=function(cell)return adventure.data.Areas.Active:IsKnown(cell.index)end
    local reachable=board:Search(origin.q,origin.r,board.externalOccupied,self.encounter.radius,board.allowed)
    local target
    for _,cell in ipairs(reachable)do
        local distance=Hex.Distance(origin.q,origin.r,cell.q,cell.r)
        if distance>=2 and distance<=self.encounter.radius and not board.externalOccupied[Hex.Key(cell.q,cell.r)]
            and (not target or distance>Hex.Distance(origin.q,origin.r,target.q,target.r))then target=cell end
    end
    if not target then return nil,L.ProfessionDuelNoSpace end
    return {board=board,origin=origin,target=target}
end
function Duels:CanUse(actor,id)
    local adventure=self.adventure
    if adventure.data.Phase~='area' or id~=actor.Id or actor.HP<=0 then return false,L.ProfessionDuelUnavailable end
    if actor.MountedAnimal then return false,L.ProfessionDuelNoMount end
    if actor.HP<=math.ceil(actor.MaxHP*self.rule.minimumHealthPercent/100)then return false,L.ProfessionDuelLowHealth end
    if adventure.player.Coins<self.rule.lossCoins then return false,L.ProfessionDuelDeposit end
    local facility,reason=adventure.professionExploration:Facility(actor,self.rule.facilityKind,self.skill.range)
    if not facility then return false,reason end
    if adventure.data.Narrative:GetValue(self:DailyKey())==adventure.professionExploration:Day()then return false,L.ProfessionDuelDaily end
    local plan,why=self:Plan(actor);return plan~=nil,why
end
function Duels:Use(actor,id)
    local ok,reason=self:CanUse(actor,id);if not ok then return false,reason end
    local adventure=self.adventure;local battle=adventure.battle;local plan=assert(self:Plan(actor))
    local enemy=CS.ProjectY.Data.CombatActorData(9000000+actor.Id,self.encounter.enemyIds[1])
    local birthSeed=(adventure.data.Seed ~ (adventure.professionExploration:Day()*65537) ~ (adventure.data.Areas.ActiveSiteId*104729))&0xffffffff
    battle.stats.birth:Initialize(enemy,birthSeed)
    enemy:Deploy(2,plan.target.q,plan.target.r)
    local pool=battle.appearances:Group(self.encounter.appearancePoolId,(adventure.data.Seed ~ enemy.Id)&0xffffffff)
    battle.appearances:Assign(enemy,pool);adventure.equipment:InitializeEnemy(enemy)
    enemy:SetMaxHP(battle.stats:MaximumHP(enemy));enemy:Restore()
    assert(adventure.player:TrySpendCoins(self.rule.lossCoins),'Duel deposit changed after validation')
    adventure.data.Narrative:SetValue(self:DailyKey(),adventure.professionExploration:Day())
    bridge().Begin(adventure.data,actor.Id,self.rule.minimumHealthPercent)
    battle:StartArea(self.encounter.id,plan.board,{{actor=actor,q=plan.origin.q,r=plan.origin.r}},{enemy})
    battle.data:AddLog(L.ProfessionDuelStarted)
    return true
end
function Duels:Settle(result)
    local adventure=self.adventure;if not bridge().Active(adventure.data)then return false end
    local actor=assert(adventure.characterSkills:Actor(bridge().ActorId(adventure.data)))
    local message=result=='victory'and L.ProfessionDuelWon or L.ProfessionDuelLost
    if result=='victory'then adventure.player:AddCoins(self.rule.lossCoins+self.rule.rewardCoins)end
    local active=adventure.data.Areas.Active;local area=adventure.areas:ActiveLayout();local ids,cells={},{}
    for i=0,active.MemberCount-1 do local id=active:GetMemberIdAt(i);ids[#ids+1]=id
        cells[#cells+1]=id==actor.Id and assert(area:Find(actor.Q,actor.R)).index or active:GetMemberCellAt(i)
    end
    active:DeployMembers(ids,cells)
    adventure.professionExploration:Record(actor,self.skill,message)
    adventure.partyStory:Reset()
    for _,unit in ipairs(adventure.battle:Units())do if unit.Team~=1 then CS.ProjectY.Data.EquipmentCombatState.RemoveActor(adventure.equipment.data,unit.Id)end end
    bridge().Finish(adventure.data,message);adventure.battle.board=nil;adventure.areas:RevealSquad(area,active)
    return true
end
return Duels

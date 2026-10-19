-- Requires real compiled C# data and exported config; the host must supply an isolated save file.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={};local function test(name,run) run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(781)
    local data,battle,growth=adventure.data,adventure.battle,adventure.growth
    local function path(value) return value:gsub('\\','/'):lower() end
    assert(path(adventure.characterSaves.FilePath)~=path(CS.UnityEngine.Application.persistentDataPath..'/Characters/party-v1.json'),
        'Social save validation requires an isolated save file')
    local target,source=data:GetPartyAt(0),data:GetPartyAt(2)
    assert(source.TemplateId==3,'Configured starting party must include a mage in slot three')
    target:AddTrait(3);target:AddTrait(6)
    local defense=battle.stats:Get(target,'defense');local bystander=data:GetPartyAt(1)
    local bystanderHistory=#growth.chronicle:Rows(bystander.Id)
    data.Narrative:AdvanceMinutes(1505-data.Narrative.Minutes)
    local initialHistory=data.JournalCount
    local function beginBattle()
        target:Restore();source:Restore()
        data:BeginEvent(1,6);data:ResolveChoice(7);data:BeginBattle()
        battle:Start(201,{target,source},781)
        assert(loadfile('Tools/Tests/combat_phase_fixture.lua'))()(battle)
        for _=1,12 do if battle:Active().Id==source.Id then break end;assert(battle:EndTurn()) end
        assert(battle:Active().Id==source.Id)
    end
    local function injure()
        local enemy
        for _,actor in ipairs(battle:Units()) do if actor.Team==2 then enemy=actor;break end end
        assert(enemy);local low=math.max(1,math.floor(target.MaxHP*.2))
        battle.gameEffects:Execute(battle.effects:Get(1),target,target.HP-low,enemy.Id,battle.stats:Template(enemy).name,'验收敌袭',enemy,true)
        assert(target.HP>0 and target.HP*100<=target.MaxHP*25)
    end
    local function finishBattle()
        for _,actor in ipairs(battle:Units()) do if actor.Team==2 and actor.HP>0 then
            battle.gameEffects:Execute(battle.effects:Get(1),actor,100000,source.Id,battle.stats:Template(source).name,'验收终结',source,true)
        end end
        assert(battle:CheckWinner() and battle.data.Winner=='victory')
        adventure:SettleBattle();assert(data.Phase=='result');adventure:ReturnToMap()
    end
    test('real enemy damage and real allied treatment create a dated pair history and remove both configured traits',function()
        beginBattle();injure();assert(battle:TrySkill(5,target.Id))
        assert(data.PartyBonds:Score(source.Id,target.Id)==25 and data.PartyBonds:RescueCount(source.Id)==1)
        assert(not target:HasTrait(3) and not target:HasTrait(6) and battle.stats:Get(target,'defense')==defense+2)
        local entry=data:GetJournalAt(initialHistory)
        assert(entry.SubjectId==source.Id and entry.ObjectId==target.Id and entry.RelationDelta==25)
        assert(entry.Day==2 and math.floor(entry.Minutes)==1505 and entry.ParticipantCount==2)
        assert(entry:Involves(source.Id) and entry:Involves(target.Id) and not entry:Involves(bystander.Id))
        assert(entry.Location==adventure.sites[1].name and #growth.chronicle:Rows(bystander.Id)==bystanderHistory)
        local rows=data.JournalCount;injure();assert(battle.gameEffects:Apply(5,source,target))
        assert(data.JournalCount==rows and data.PartyBonds:RescueCount(source.Id)==1,'Repeated healing must not count twice in one encounter')
        finishBattle();assert(data.PartyBonds:Score(source.Id,target.Id)==35)
        local after=data.JournalCount;assert(not adventure.partyStory:Settle('victory',adventure.sites[1].name));assert(data.JournalCount==after)
    end)
    test('three real rescues across encounters unlock a single automatic honor',function()
        for _=1,2 do beginBattle();injure();assert(battle:TrySkill(5,target.Id));finishBattle() end
        assert(data.PartyBonds:RescueCount(source.Id)==3 and data.PartyBonds:HasHonor(source.Id,1))
        assert(data.PartyBonds:Find(source.Id,target.Id).SharedBattles==3 and data.PartyBonds:Score(source.Id,target.Id)==100)
        assert(data.PartyBonds:Score(source.Id,bystander.Id)==0)
        local found=false
        for _,row in ipairs(adventure.partyStory:OverviewRows(source)) do if row.title=='★ 荣誉 · 守望者' then found=true end end
        assert(found)
    end)
    local saved={count=data.JournalCount,rows={},sourceId=source.Id,targetId=target.Id}
    for i=0,data.JournalCount-1 do
        local row=data:GetJournalAt(i)
        saved.rows[i+1]={sequence=row.Sequence,minutes=row.Minutes,title=row.Title,body=row.Body,subject=row.SubjectId,object=row.ObjectId,
            location=row.Location,delta=row.RelationDelta,participants=row.ParticipantCount}
    end
    test('save and reload replace regenerated histories and restore exact relationships, challenge progress and honors',function()
        local save=require('Game.Adventure.CharacterSave');assert(save.Write(adventure))
        data.PartyBonds:Clear();target:AddTrait(6)
        growth.chronicle:Record('growth',target,'不应恢复的临时记录','读取时必须被存档覆盖。','测试',false)
        assert(save.Read(adventure))
        assert(data.JournalCount==saved.count and data.PartyBonds:Score(saved.sourceId,saved.targetId)==100)
        assert(data.PartyBonds:RescueCount(saved.sourceId)==3 and data.PartyBonds:HasHonor(saved.sourceId,1))
        assert(not data:GetPartyAt(0):HasTrait(3) and not data:GetPartyAt(0):HasTrait(6))
        for i=0,data.JournalCount-1 do
            local row,expected=data:GetJournalAt(i),saved.rows[i+1]
            assert(row.Sequence==expected.sequence and row.Minutes==expected.minutes and row.Title==expected.title and row.Body==expected.body)
            assert(row.SubjectId==expected.subject and row.ObjectId==expected.object and row.Location==expected.location and
                row.RelationDelta==expected.delta and row.ParticipantCount==expected.participants)
        end
        local sourceRestored=data:GetPartyAt(2);growth.chronicle:Record('growth',sourceRestored,'读取后的新经历','序号继续递增。','营地',false)
        assert(data:GetJournalAt(data.JournalCount-1).Sequence==saved.count+1)
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0) end
return table.concat(messages,'\n')

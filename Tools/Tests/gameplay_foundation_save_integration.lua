-- Combined public gameplay and persistence flow. The host must provide an isolated save path.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(713)
    local growth,battle,eq=adventure.growth,adventure.battle,adventure.equipment
    local save=require('Game.Adventure.CharacterSave')
    local function path(value)return value:gsub('\\','/'):lower()end
    assert(path(adventure.characterSaves.FilePath)~=path(CS.UnityEngine.Application.persistentDataPath..'/Characters/party-v1.json'),
        'Combined save validation requires the host to supply an isolated save file')
    local actor
    for i=0,adventure.data.PartyCount-1 do local member=adventure.data:GetPartyAt(i);if member.TemplateId==3 then actor=member;break end end
    assert(actor and actor.Growth.CurrentProfessionId==3,'The configured starting party must include its mage')
    local function weapon(itemId)
        for i=0,eq.data.WeaponCount-1 do local row=eq.data:GetWeaponAt(i);if row.ItemId==itemId then return row end end
        error('Required configured starter weapon is absent: '..itemId)
    end
    local iron,knight=weapon(40),weapon(41)
    test('mage trains through public growth commands and retains actively learned skills across professions',function()
        growth:AddExperience(actor,40,'联合存档验收')
        assert(actor.Growth.Level==2 and actor.Growth.PendingCount==2)
        for _=1,4 do assert(growth:InvestAttribute(actor.Id,4)) end
        assert(battle.stats:Get(actor,'strength',true)==6 and actor.Growth:GetAttribute('strength')==4)
        assert(growth:InvestTalent(actor.Id,301));assert(actor.Growth:GetRank(301)==1)
        assert(growth:Learn(actor.Id,103));assert(growth:ChangeProfession(actor.Id,1));assert(growth:Learn(actor.Id,101))
        assert(actor.Growth:HasSkill(101) and actor.Growth:HasSkill(103) and actor.Growth.PendingCount==0)
        assert(growth:ChangeProfession(actor.Id,3));assert(actor.Growth:GetRank(301)==1 and not actor.Growth:HasSkill(401))
    end)
    test('ordinary main-hand sword and specialized offhand adapter provide the selected spell catalyst',function()
        assert(eq:Command('equip',actor.Id,iron.Id,0,0))
        assert(eq:Command('equip_offhand',actor.Id,knight.Id,0,0))
        assert(eq:Command('attach',actor.Id,knight.Id,7,93))
        local allowed,reason,selected=eq.rules:CheckSkillEquipment(actor,battle:Skill(actor,103),battle.stats)
        assert(allowed,reason);assert(selected==knight and eq.data:CountItem(93)==0)
        assert(iron.Hand=='weapon' and knight.Hand=='offhand' and knight.OwnerActorId==actor.Id and knight:GetRune(7)==93)
    end)
    local snapshot={actorId=actor.Id,profession=actor.Growth.CurrentProfessionId,professionCount=actor.Growth.ProfessionCount,
        learnedCount=actor.Growth.SkillCount,specialization=actor.Growth:GetRank(301),mainId=iron.Id,offId=knight.Id,
        healing=eq.data:CountItem(91),preparation=eq.data:CountItem(92),gridCount=eq.data.Grid.Count,
        level=actor.Growth.Level,trainedStrength=actor.Growth:GetAttribute('strength')}
    test('saved mage, adapter and consumables can be changed independently before restoration',function()
        assert(snapshot.healing>0 and snapshot.preparation>0)
        assert(save.Write(adventure))
        assert(growth:ChangeProfession(actor.Id,2));assert(eq:Command('attach',actor.Id,knight.Id,7,0))
        assert(eq:Command('unequip_offhand',actor.Id,0,0,0))
        eq.data:ConsumeStack(91,1);eq.data:ConsumeStack(92,1)
        assert(actor.Growth.CurrentProfessionId==2 and not eq.data:Offhand(actor.Id) and eq.data:CountItem(93)==1)
        assert(eq.data:CountItem(91)==snapshot.healing-1 and eq.data:CountItem(92)==snapshot.preparation-1)
        assert(not eq.rules:CheckSkillEquipment(actor,battle:Skill(actor,103),battle.stats))
        assert(save.Read(adventure))
    end)
    local restored
    for i=0,adventure.data.PartyCount-1 do local member=adventure.data:GetPartyAt(i);if member.Id==snapshot.actorId then restored=member;break end end
    test('read restores profession, learned skills, specialization and exact equipped instance ownership',function()
        assert(restored and restored~=actor)
        assert(restored.Growth.CurrentProfessionId==snapshot.profession and restored.Growth.ProfessionCount==snapshot.professionCount)
        assert(restored.Growth:HasProfession(1) and restored.Growth:HasProfession(3) and not restored.Growth:HasProfession(2))
        assert(restored.Growth.Level==snapshot.level and restored.Growth:GetAttribute('strength')==snapshot.trainedStrength)
        assert(restored.Growth.SkillCount==snapshot.learnedCount and restored.Growth:HasSkill(101) and restored.Growth:HasSkill(103))
        assert(restored.Growth:GetRank(301)==snapshot.specialization and restored.Growth.PendingCount==0)
        local main,off=eq.data:Equipped(restored.Id),eq.data:Offhand(restored.Id)
        assert(main.Id==snapshot.mainId and main.ItemId==40 and main.OwnerActorId==restored.Id and main.Hand=='weapon')
        assert(off.Id==snapshot.offId and off.ItemId==41 and off.OwnerActorId==restored.Id and off.Hand=='offhand' and off:GetRune(7)==93)
        assert(eq.data:CountItem(93)==0 and eq.data:CountItem(91)==snapshot.healing and eq.data:CountItem(92)==snapshot.preparation)
        assert(eq.data.Grid.Count==snapshot.gridCount and not eq.data.Grid:Find('w'..off.Id))
        local allowed,reason,selected=eq.rules:CheckSkillEquipment(restored,battle:Skill(restored,103),battle.stats)
        assert(allowed,reason);assert(selected.Id==snapshot.offId)
    end)
    test('restored mage can change to warrior and cast the retained spell through the saved offhand catalyst',function()
        assert(growth:ChangeProfession(restored.Id,1))
        assert(restored.Growth.CurrentProfessionId==1 and restored.Growth:HasSkill(103) and restored.Growth:GetRank(301)==1)
        local allowed,reason,selected=eq.rules:CheckSkillEquipment(restored,battle:Skill(restored,103),battle.stats)
        assert(allowed,reason);assert(selected.Id==snapshot.offId)
        -- Use the normal open-field encounter and bounded public movement/turn commands to reach a target.
        battle:Start(201,{restored},713)
        assert(loadfile('Tools/Tests/combat_phase_fixture.lua'))()(battle)
        local target
        for _,unit in ipairs(battle:Units())do if unit.Team==2 then target=unit;break end end
        assert(target)
        local Hex=require('Game.Map.HexGrid');local cast=false
        for _=1,12 do
            if battle:Active().Id==restored.Id then
                if not battle:CanUseSkill(103,target.Id) then
                    local closest,distance
                    for _,cell in ipairs(battle:Reachable())do
                        local value=Hex.Distance(cell.q,cell.r,target.Q,target.R)
                        if not distance or value<distance then closest,distance=cell,value end
                    end
                    if closest then assert(battle:TryMove(closest.q,closest.r)) end
                end
                if battle:CanUseSkill(103,target.Id) then
                    local hp,ap=target.HP,restored.AP;local skill=battle:Skill(restored,103)
                    assert(battle:TrySkill(103,target.Id));assert(target.HP<hp and restored.AP==ap-skill.cost)
                    assert(restored.MainUsed and restored:GetCooldown(103)==skill.cooldownTurns)
                    cast=true;break
                end
            end
            assert(battle:EndTurn())
        end
        assert(cast,'Retained spell was not cast within the bounded encounter traversal')
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return table.concat(messages,'\n')

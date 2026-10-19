-- Real C# save/restore regression. Run only with isolated FrameworkServices and a temporary save path.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
local listener
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(815)
    local data,player,eq=adventure.data,adventure.player,adventure.equipment.data
    local save=require('Game.Adventure.CharacterSave')
    local service=adventure.characterSaves;local file=service.FilePath
    local function normalized(value)return value:gsub('\\','/'):lower()end
    assert(normalized(file)~=normalized(CS.UnityEngine.Application.persistentDataPath..'/Characters/party-v1.json'),
        'v6 regression requires an isolated save file')
    local disk=CS.System.IO.File
    local camp=adventure.camp;local physical=CS.ProjectY.Data.EquipmentCombatState
    local condition=CS.ProjectY.Data.EquipmentConditionData
    player:AddCoins(2000)
    for _,id in ipairs({81,82,83})do assert(adventure.equipment:Grant(id,60))end
    assert(camp:Open())
    assert(camp:Deposit(81,camp.data.Revision,20));assert(camp:Deposit(82,camp.data.Revision,20))
    assert(camp:Upgrade(1,camp.data.Revision));assert(camp:Produce(1,camp.data.Revision));camp:Close()
    local first,second=data:GetPartyAt(0),data:GetPartyAt(1)
    for _=1,3 do
        data.PartyBonds:BeginBattle();data.PartyBonds:AddParticipant(first);data.PartyBonds:AddParticipant(second)
        assert(data.PartyBonds:TryRescue(first.Id,second.Id,25));assert(data.PartyBonds:SettleBattle(true,10))
    end
    data.PartyBonds:AwardHonor(first.Id,1)
    data.Narrative:AdvanceMinutes(37)
    data:RecordPair('relationship','联合存档的救援记录','日期、双方和关系增量均须原样恢复。','营地',0,0,first.Id,second.Id,25)
    local carried=eq:GetWeaponAt(0);local weaponId=carried.Id
    physical.DamageWeapon(eq,weaponId,51)
    assert(condition.Of(carried).Current==49 and condition.Of(carried).Maximum==95)
    physical.Initialize(eq,9901,2,0,{52},{'body'})
    local enemyWeapon=eq:Equipped(9901);local enemyWeaponId=enemyWeapon.Id
    local enemyMagazine=eq:AddMagazine(21,31,12,7);local enemyMagazineId=enemyMagazine.Id
    assert(eq:AttachMagazine(enemyWeaponId,enemyMagazineId))
    local snapshot={coins=player.Coins,minutes=data.Narrative.Minutes,journal=data.JournalCount,
        stock=camp.data.StoredTotal,ready=camp.data:GetJobAt(0).ReadyAt,grid=eq.Grid.Count,
        weapons=eq.WeaponCount-1,wearables=eq.WearableCount-1,magazines=eq.MagazineCount-1,
        first=first.Id,second=second.Id,profession=first.Growth.CurrentProfessionId,pending=first.Growth.PendingCount}
    assert(save.Write(adventure));local saved=disk.ReadAllText(file)
    test('v6 capture filters enemy equipment and its loaded magazine while preserving item condition and backpack ownership',function()
        local prepared=service:Prepare(eq);save.Validate(adventure,prepared)
        assert(prepared.Equipment.WeaponCount==snapshot.weapons and prepared.Equipment.WearableCount==snapshot.wearables)
        assert(prepared.Equipment.MagazineCount==snapshot.magazines and prepared.Equipment.Grid.Count==snapshot.grid)
        assert(not pcall(function()prepared.Equipment:GetWeapon(enemyWeaponId)end))
        assert(not pcall(function()prepared.Equipment:GetMagazine(enemyMagazineId)end))
        local value=condition.Of(prepared.Equipment:GetWeapon(weaponId))
        assert(value.Current==49 and value.Maximum==95 and value.BaseMaximum==100 and not value.ThresholdArmed)
    end)
    test('one commit restores camp, relationships and journal before publishing the player change notification',function()
        local prepared=service:Prepare(eq);save.Validate(adventure,prepared)
        camp.data:Clear();data.PartyBonds:Clear();data.Narrative:AdvanceMinutes(13);player:AddCoins(3)
        local observed=0
        listener=function()
            observed=observed+1
            assert(player.Coins==snapshot.coins and data.Narrative.Minutes==snapshot.minutes)
            assert(camp.data.StoredTotal==snapshot.stock and camp.data:GetLevel(1)==1)
            assert(camp.data.JobCount==1 and camp.data:GetJobAt(0).ReadyAt==snapshot.ready)
            assert(data.PartyBonds:Score(snapshot.first,snapshot.second)==100 and data.PartyBonds:HasHonor(snapshot.first,1))
            assert(data.JournalCount==snapshot.journal and data:GetJournalAt(snapshot.journal-1).Title=='联合存档的救援记录')
        end
        player:AddChangedListener(listener);service:Apply(prepared,data,player)
        player:RemoveChangedListener(listener);listener=nil
        assert(observed==1 and not pcall(function()service:Apply(prepared,data,player)end))
        assert(not physical.IsInitialized(eq,9901) and eq.WeaponCount==snapshot.weapons)
    end)
    local function replace(text,pattern,value)
        local next,count=text:gsub(pattern,value,1);assert(count==1,'Corruption fixture did not match '..pattern);return next
    end
    local function rejected(text)
        disk.WriteAllText(file,text)
        local actor,coins,clock,journal,stocks,revision=data:GetPartyAt(0),player.Coins,data.Narrative.Minutes,data.JournalCount,camp.data.StoredTotal,eq.Revision
        local accepted=save.Read(adventure)
        assert(not accepted,'Malformed v6 save was accepted')
        assert(data:GetPartyAt(0)==actor and player.Coins==coins and data.Narrative.Minutes==clock and data.JournalCount==journal)
        assert(camp.data.StoredTotal==stocks and eq.Revision==revision and data.PartyBonds:Score(snapshot.first,snapshot.second)==100)
    end
    test('bad condition, camp count, rescue accounting and future journal dates reject without changing any live subsystem',function()
        rejected(replace(saved,'("version"%s*:%s*)6','%199'))
        rejected(replace(saved,'("maximum"%s*:%s*)95','%193'))
        rejected(replace(saved,'("storage"%s*:%s*%[%s*{.-"count"%s*:%s*)%d+','%1-1'))
        rejected(replace(saved,'("rescues"%s*:%s*)3','%14'))
        local future=replace(saved,'("journal"%s*:%s*%[%s*{.-"minutes"%s*:%s*)[%d%.]+',function(prefix)return prefix..(snapshot.minutes+1)end)
        rejected(future)
        disk.WriteAllText(file,saved)
    end)
    test('versions one through five explicitly migrate fresh condition and empty new systems before configuration validation',function()
        for version=1,5 do
            disk.WriteAllText(file,replace(saved,'("version"%s*:%s*)6',function(prefix)return prefix..version end))
            local prepared=service:Prepare(eq);save.Validate(adventure,prepared)
            local value=condition.Of(prepared.Equipment:GetWeapon(weaponId));local migrated=CS.ProjectY.Data.CampData.Prepared(prepared)
            assert(value.Current==100 and value.Maximum==100 and value.ThresholdArmed)
            assert(migrated.LevelCount==0 and migrated.StorageCount==0 and migrated.JobCount==0)
            assert(prepared.PartyBonds.BondCount==0 and prepared.PartyBonds.HonorCount==0)
            assert(prepared.LegacyNarrative==(version==1) and prepared.LegacyProfessions==(version<5))
            assert(prepared:GetActorAt(0).Growth.PendingCount==snapshot.pending)
        end
        disk.WriteAllText(file,saved)
        assert(save.Read(adventure))
        assert(camp:Open());assert(camp:Wait(60,camp.data.Revision));assert(camp:Claim(1,camp.data.Revision));camp:Close()
        assert(camp.data.JobCount==0,'Restored production must still be claimable through the public camp flow')
    end)
end,debug.traceback)
if listener then Services.Player:RemoveChangedListener(listener)end
registry:Shutdown();if not ok then error(err,0)end
return table.concat(messages,'\n')

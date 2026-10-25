-- Real save service, actors and exported rules. Host must supply isolated FrameworkServices
-- whose explicit characterSavePath is under System.IO.Path.GetTempPath(). No Play required.
local disk,path=CS.System.IO.File,CS.System.IO.Path
local bridge=CS.ProjectY.Data.CampaignSaves
local service=Services.CharacterSaves
local legacyFile=service.FilePath
local function normalize(value)return value:gsub('\\','/'):lower()end
local tempRoot=normalize(path.GetTempPath()):gsub('/+$','')..'/'
assert(normalize(legacyFile):sub(1,#tempRoot)==tempRoot,'Multi-slot regression requires a dedicated OS-temporary directory')
assert(not disk.Exists(legacyFile),'Multi-slot fixture must start with an unused legacy file')
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
local listener
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(815)
    local data,player,inventory=adventure.data,adventure.player,adventure.equipment.data
    local rules=require('Game.Adventure.CharacterSave')
    service:Save(data,player)
    local legacyBytes,replaced=disk.ReadAllText(legacyFile):gsub('"worldName":"",','',1)
    assert(replaced==1);disk.WriteAllText(legacyFile,legacyBytes) -- Pre-feature save with no name field.
    local slotA,slotB,fileA,fileB,bytesA,bytesB,coinsA
    local function entries()
        local list=bridge.List(service);local byId={}
        for i=0,list.Length-1 do local row=list[i];assert(not byId[row.Id]);byId[row.Id]=row end
        return byId,list.Length
    end
    test('new campaigns allocate independent paths without creating files or touching legacy',function()
        slotA=bridge.NewCampaign(service,'  晨风 "群岛" <b>  ');fileA=service.FilePath
        assert(#slotA==32 and bridge.CurrentId(service)==slotA and not disk.Exists(fileA) and not service.HasSave)
        local before,count=entries();assert(count==1 and before.legacy and not before[slotA])
        assert(disk.ReadAllText(legacyFile)==legacyBytes)
        service:Save(data,player);bytesA=disk.ReadAllText(fileA);coinsA=player.Coins
        slotB=bridge.NewCampaign(service);fileB=service.FilePath
        assert(slotB~=slotA and fileB~=fileA and not disk.Exists(fileB))
        assert(path.GetDirectoryName(fileA)==path.GetDirectoryName(fileB))
        player:AddCoins(7);service:Save(data,player);bytesB=disk.ReadAllText(fileB)
        assert(disk.ReadAllText(fileA)==bytesA and disk.ReadAllText(legacyFile)==legacyBytes)
    end)
    test('catalog lists local timestamps, seed, world size and readable party summaries',function()
        local byId,count=entries();assert(count==3)
        for _,id in ipairs({'legacy',slotA,slotB})do
            local row=assert(byId[id]);assert(row.CanLoad and row.Error=='')
            assert(row.SavedAt~='' and row.SavedAt~='时间未知' and row.SavedAtUtc~='')
            assert(row.Seed==data.Seed and row.PartyCount==data.PartyCount and row.PartySummary:find('名队员',1,true))
            assert(row.PartySummary:find('Lv',1,true) and not row.PartySummary:find('template',1,true))
            assert(row.HasWorld and row.TargetCells==CS.ProjectY.Data.ExpeditionPersistence.CurrentTarget(data))
            assert(row.Legacy==(id=='legacy'))
        end
        assert(bridge.CurrentId(service)==slotB,'Listing must not select another slot')
        assert(byId[slotA].WorldName=='晨风 "群岛" <b>' and byId[slotB].WorldName=='' and byId.legacy.WorldName=='')
    end)
    test('a cold inventory prepares a selected save before any new campaign is started',function()
        local coldData=CS.ProjectY.Data.AdventureData()
        local coldEquipment=require('Game.Equipment.EquipmentSystem')()
        coldEquipment:OnInit({services={Adventure=coldData},systems=registry})
        assert(coldData.PartyCount==0 and coldData.Equipment.Grid.Count==0)
        local prepared=bridge.PrepareSelected(service,slotA,coldData.Equipment)
        rules.Validate(adventure,prepared)
        assert(prepared.ActorCount==data.PartyCount and prepared.Coins==coinsA)
        assert(prepared.Equipment.Grid.Width==inventory.Grid.Width and prepared.Equipment.Grid.Height==inventory.Grid.Height)
        assert(coldData.PartyCount==0 and coldData.Equipment.Grid.Count==0,'Preparation must leave the cold session empty')
        assert(bridge.CurrentId(service)==slotB and service.FilePath==fileB and player.Coins==coinsA+7)
    end)
    test('selected preparation is isolated and successful Apply commits identity before notification',function()
        local prepared=bridge.PrepareSelected(service,slotA,inventory);rules.Validate(adventure,prepared)
        assert(bridge.CurrentId(service)==slotB and service.FilePath==fileB and player.Coins==coinsA+7)
        local observed=0
        listener=function()
            observed=observed+1
            assert(bridge.CurrentId(service)==slotA and service.FilePath==fileA and player.Coins==coinsA)
            assert(data.Equipment==inventory,'Apply replaced the cached EquipmentData identity')
        end
        player:AddChangedListener(listener);service:Apply(prepared,data,player)
        player:RemoveChangedListener(listener);listener=nil
        assert(observed==1 and not pcall(function()service:Apply(prepared,data,player)end))
        assert(bridge.CurrentId(service)==slotA)
    end)
    test('F5-compatible Save updates only the current slot and retains its backup',function()
        player:AddCoins(13);service:Save(data,player)
        assert(disk.ReadAllText(fileA)~=bytesA and disk.ReadAllText(fileA..'.bak')==bytesA)
        assert(disk.ReadAllText(fileB)==bytesB and disk.ReadAllText(legacyFile)==legacyBytes)
        local prepared=service:Prepare(inventory);assert(prepared.Coins==player.Coins)
        assert(entries()[slotA].WorldName=='晨风 "群岛" <b>','Loading and saving must retain the selected world name')
    end)
    test('bad and future-version files remain visible while opaque IDs cannot escape the slot directory',function()
        local directory=path.GetDirectoryName(fileA)
        local badId=CS.System.Guid.NewGuid():ToString('N');local futureId=CS.System.Guid.NewGuid():ToString('N')
        disk.WriteAllText(path.Combine(directory,badId..'.json'),'{ malformed json')
        local future,replaced=bytesB:gsub('"version"%s*:%s*%d+','"version":99',1);assert(replaced==1)
        disk.WriteAllText(path.Combine(directory,futureId..'.json'),future)
        local byId,count=entries();assert(count==5 and not byId[badId].CanLoad and byId[badId].Error~='')
        assert(not byId[futureId].CanLoad and byId[futureId].Error~='' and byId[slotA].CanLoad and byId[slotB].CanLoad)
        local current,coins=bridge.CurrentId(service),player.Coins
        for _,id in ipairs({badId,futureId,'../party-v1',legacyFile,'not-a-slot',CS.System.Guid.NewGuid():ToString('N')})do
            assert(not pcall(function()bridge.PrepareSelected(service,id,inventory)end))
            assert(bridge.CurrentId(service)==current and service.FilePath==fileA and player.Coins==coins)
        end
        assert(disk.ReadAllText(fileB)==bytesB and disk.ReadAllText(legacyFile)==legacyBytes)
    end)
    test('legacy party-v1 selection preserves schema compatibility and becomes current only on Apply',function()
        local prepared=bridge.PrepareSelected(service,'legacy',inventory);rules.Validate(adventure,prepared)
        assert(bridge.CurrentId(service)==slotA)
        service:Apply(prepared,data,player)
        assert(bridge.CurrentId(service)=='legacy' and service.FilePath==legacyFile and player.Coins==coinsA)
        service:Save(data,player)
        assert(disk.Exists(legacyFile..'.bak') and disk.ReadAllText(fileB)==bytesB)
        local text=disk.ReadAllText(legacyFile)
        assert(text:match('"version"%s*:%s*(%d+)')==legacyBytes:match('"version"%s*:%s*(%d+)'),'Multi-slot catalog must retain the current world save schema')
        assert(entries().legacy.WorldName=='','Loading unnamed legacy data must clear the prior named session')
    end)
end,debug.traceback)
if listener then Services.Player:RemoveChangedListener(listener)end
registry:Shutdown()
if not ok then error(err)end
return table.concat(messages,'\n')

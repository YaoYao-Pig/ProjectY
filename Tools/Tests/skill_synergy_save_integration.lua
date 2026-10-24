-- Real C# bitset and save-service regression. Run only in an authorized, isolated Edit Mode LuaEnv.
-- Caller supplies FrameworkServices with an unused explicit save path under the OS temporary directory.
local discovery=CS.ProjectY.Data.SkillSynergyDiscovery
local disk,path=CS.System.IO.File,CS.System.IO.Path
local service=Services.CharacterSaves
local savePath=service.FilePath
local function normalize(value)return value:gsub('\\','/'):lower()end
local tempRoot=normalize(path.GetTempPath()):gsub('/+$','')..'/'
assert(normalize(savePath):sub(1,#tempRoot)==tempRoot,'Synergy regression requires an OS-temporary save path')
assert(not disk.Exists(savePath),'Synergy fixture must start with an unused save file')
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages,listener={}
local function test(name,run)run();messages[#messages+1]='PASS '..name end
local function hasIds(prepared,expected)
    local ids=discovery.PreparedIds(prepared)
    assert(ids.Length==#expected,'Unexpected number of discovered synergies')
    for i,id in ipairs(expected)do assert(ids[i-1]==id,'Stable synergy bit ID changed')end
end
local ok,err=xpcall(function()
    test('bit boundaries, idempotence and campaign reset',function()
        local data=CS.ProjectY.Data.AdventureData()
        local revision=discovery.Revision(data)
        for _,id in ipairs({1,8,9,65535})do
            assert(not discovery.Has(data,id) and discovery.Discover(data,id) and discovery.Has(data,id))
            assert(not discovery.Discover(data,id))
        end
        assert(discovery.Revision(data)==revision+4)
        for _,id in ipairs({0,-1,65536,2147483647})do
            assert(not pcall(function()discovery.Discover(data,id)end))
            assert(not pcall(function()discovery.Has(data,id)end))
        end
        data:Reset(17)
        for _,id in ipairs({1,8,9,65535})do assert(not discovery.Has(data,id))end
    end)
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(20261023,3,2500)
    local data,inventory,player=adventure.data,adventure.data.Equipment,Services.Player
    for _,id in ipairs({1,8,9,65535})do discovery.Discover(data,id)end
    service:Save(data,player)
    local bytes=disk.ReadAllText(savePath)
    assert(bytes:find('"version":14',1,true) and bytes:find('"skillSynergies":',1,true))
    local function replaceDiscovery(json,record)
        local changed,count=json:gsub('"skillSynergies"%s*:%s*%b{}',record,1)
        assert(count==1,'Missing discovery record in test fixture')
        return changed
    end
    test('roundtrip retains stable ids and Prepare stays isolated until one atomic Apply',function()
        local prepared=service:Prepare(inventory);hasIds(prepared,{1,8,9,65535})
        discovery.Discover(data,97)
        local copy=discovery.PreparedIds(prepared);copy[0]=42;hasIds(prepared,{1,8,9,65535})
        assert(discovery.Has(data,97),'Preparing a save mutated live discoveries')
        local observed=0
        listener=function()
            observed=observed+1
            assert(not discovery.Has(data,97) and discovery.Has(data,65535),'Player notification observed partial discovery commit')
            assert(data.Equipment==inventory,'Applying discoveries replaced shared inventory identity')
        end
        player:AddChangedListener(listener);service:Apply(prepared,data,player)
        player:RemoveChangedListener(listener);listener=nil
        assert(observed==1 and not pcall(function()service:Apply(prepared,data,player)end))
        assert(not pcall(function()discovery.PreparedIds(prepared)end))
    end)
    test('malformed or missing current discovery records reject without touching live state',function()
        discovery.Discover(data,97)
        local initialRevision=discovery.Revision(data)
        local bad={
            '"unusedDiscovery":{}',
            '"skillSynergies":{"format":1}',
            '"skillSynergies":{"format":0,"bits":""}',
            '"skillSynergies":{"format":2,"bits":"AQ=="}',
            '"skillSynergies":{"format":1,"bits":"??"}',
            '"skillSynergies":{"format":1,"bits":"AQ== "}',
            '"skillSynergies":{"format":1,"bits":"AA=="}',
            '"skillSynergies":{"format":1,"bits":"'..string.rep('A',10928)..'"}',
        }
        -- Valid Base64 length, but the final byte sets the reserved ID 65536 bit.
        local raw=string.rep('\0',8191)..string.char(128) -- xLua marshals byte[] as a binary Lua string.
        bad[#bad+1]='"skillSynergies":{"format":1,"bits":"'..CS.System.Convert.ToBase64String(raw)..'"}'
        for _,record in ipairs(bad)do
            disk.WriteAllText(savePath,replaceDiscovery(bytes,record))
            assert(not pcall(function()service:Prepare(inventory)end),'Malformed discovery record was accepted')
            assert(discovery.Revision(data)==initialRevision and discovery.Has(data,97))
            assert(data.Equipment==inventory)
        end
        disk.WriteAllText(savePath,bytes)
    end)
    test('v12 migrates discoveries explicitly to empty instead of revealing installed runes',function()
        local legacy,count=bytes:gsub('"version"%s*:%s*14','"version":12',1);assert(count==1)
        -- Even injected knowledge in an old-version document must not become discovered state.
        disk.WriteAllText(savePath,legacy)
        local prepared=service:Prepare(inventory);hasIds(prepared,{})
        assert(discovery.Has(data,97),'Legacy preparation mutated the current campaign')
        service:Apply(prepared,data,player)
        for _,id in ipairs({1,8,9,97,65535})do assert(not discovery.Has(data,id))end
        service:Save(data,player)
        hasIds(service:Prepare(inventory),{})
        assert(disk.ReadAllText(savePath):find('"skillSynergies":{"format":1,"bits":""}',1,true))
    end)
end,debug.traceback)
if listener then Services.Player:RemoveChangedListener(listener)end
registry:Shutdown()
if not ok then error(err)end
return table.concat(messages,'\n')

-- Actual menu command bridge, world generation and save selection in an isolated native host.
-- The host must use a new OS-temporary save path, never the player's default service.
local path=Services.CharacterSaves.FilePath:gsub('\\','/'):lower()
assert(path:find('project%-y%-menu%-flow%-'),'Isolated menu-flow save path required')
local registry=require('Main');local adventure=registry:Get('Adventure')
local bridge=require('Game.Adventure.DemoBridge');local slots=CS.ProjectY.Data.CampaignSaves
local messages={}
local function test(name,run)run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    assert(not adventure.map and adventure.data.PartyCount==0,'Startup must not eagerly create a world')
    local initial=slots.CurrentId(adventure.characterSaves)
    test('menu validates seed and size before creating a world or file',function()
        for _,args in ipairs({{2500,'-1'},{2500,'4294967296'},{2500,'abc'},{2500,'1.5'},{1234,'1'}})do
            local map,state=bridge('menu_start',args[1],args[2]);assert(map==nil and state.error~='')
        end
        assert(not adventure.map and slots.CurrentId(adventure.characterSaves)==initial and slots.List(adventure.characterSaves).Length==0)
        local map,state=bridge('menu_load',0,'legacy');assert(map==nil and state.error~='')
        assert(not adventure.map,'Failed initial load must remain on the menu without asking for a map snapshot')
    end)
    local first,second
    test('creating a selected seed and size writes an independent initial campaign',function()
        local map,state=bridge('menu_start',2500,'0')
        assert(map and state and not state.error and not state.warning)
        assert(adventure.data.Seed==0 and CS.ProjectY.Data.ExpeditionPersistence.CurrentTarget(adventure.data)==2500)
        assert(adventure.player.Coins==60 and adventure.data.PartyCount==3)
        first=slots.CurrentId(adventure.characterSaves);assert(#first==32)
        assert(CS.System.IO.File.Exists(adventure.characterSaves.FilePath))
        local list=bridge('campaign_saves');assert(list.Length==1 and list[0].Id==first and list[0].CanLoad and list[0].Seed==0 and list[0].TargetCells==2500)
        -- The real presentation decoder must accept the new-game response before any map is displayed.
        CS.ProjectY.Samples.AdventureViewData.Read(state)
    end)
    test('another world keeps the first save; loading a selected slot restores its world and F5 target',function()
        local map,state=bridge('menu_start',2500,'1234');assert(map and not state.error and not state.warning)
        second=slots.CurrentId(adventure.characterSaves);assert(second~=first and slots.List(adventure.characterSaves).Length==2)
        assert(adventure.data.Seed==1234)
        map,state=bridge('menu_load',0,first);assert(map and state and not state.error)
        assert(adventure.data.Seed==0 and slots.CurrentId(adventure.characterSaves)==first)
        local before=adventure.player.Coins;adventure.player:AddCoins(1)
        state=bridge('save_characters');assert(state.error=='')
        local prepared=slots.PrepareSelected(adventure.characterSaves,first,adventure.data.Equipment)
        assert(prepared.Coins==before+1 and slots.CurrentId(adventure.characterSaves)==first)
    end)
    test('a rejected slot path preserves the running campaign',function()
        local seed=adventure.data.Seed;local coins=adventure.player.Coins
        local map,state=bridge('menu_load',0,'../party-v1')
        assert(map==nil and state.error~='' and adventure.data.Seed==seed and adventure.player.Coins==coins)
        assert(slots.CurrentId(adventure.characterSaves)==first and slots.List(adventure.characterSaves).Length==2)
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return table.concat(messages,'\n')

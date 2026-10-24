-- Exercise the actual command bridge without Unity: unchanged polls must do no snapshot or narrative work.
package.path='Lua/?.lua;'..package.path
local Effects=require('Game.Presentation.VisualEffects')
local current
package.loaded.Main={Get=function(_,name)assert(name=='Adventure');return current end}
CS={ProjectY={Data={CampaignSaves={List=function()return {}end}}}}
local function actor(id)
    return {Id=id,TemplateId=1,Team=1,HP=30,MaxHP=40,AP=4,Q=0,R=0,Guard=0,Moved=false,MainUsed=false,
        ActionSequence=0,MovementSequence=0,Growth={Revision=1},Effects={Revision=1},CustomizationJson='appearance',
        TraitCount=0,traits={},GetTraitAt=function(self,i)return self.traits[i+1]end,
        AnimalSpeciesId=0,AnimalOwnerId=0,AnimalBond=0,TameRetryTurns=0}
end
local function fixture()
    local member=actor(1);local site={Revision=1}
    local adventure={map={},data={Phase='map',Equipment={Revision=1},Areas={ActiveSiteId=0},
        JournalCount=0,ResultText='',PartyCount=1,GetPartyAt=function()return member end},
        travel={data={Paused=true,Revision=1}},parties={data={Revision=1,Clock=600}},
        narrative={data={Revision=1,Minutes=600}},factions={data={Revision=1,SiteCount=1,GetSiteAt=function()return site end}},
        player={Coins=100,Level=1},characterSaves={Status='saved',HasSave=true},battle={},
        snapshots=0,refreshes=0,commands=0}
    function adventure:Snapshot()self.snapshots=self.snapshots+1;return {phase=self.data.Phase,serial=self.snapshots}end
    function adventure.narrative:Refresh()adventure.refreshes=adventure.refreshes+1 end
    function adventure.parties:Command()adventure.commands=adventure.commands+1;return true end
    function adventure.travel:Command(command)
        assert(command=='travel_pause');self.data.Paused=not self.data.Paused;self.data.Revision=self.data.Revision+1;return true
    end
    current=adventure
    return adventure,assert(loadfile('Lua/Game/Adventure/DemoBridge.lua'))(),member,site
end
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end

test('stable paused polling returns a fresh tiny response without narrative refresh or snapshot',function()
    local adventure,bridge=fixture()
    assert(bridge('snapshot').unchanged==false and adventure.snapshots==1 and adventure.refreshes==1, 'Full response must publish unchanged=false for C# bool reads')
    local previous
    for i=1,20 do
        local result=bridge('snapshot');assert(result.unchanged and next(result,'unchanged')==nil and result~=previous)
        previous=result
    end
    assert(adventure.snapshots==1 and adventure.refreshes==1)
end)

test('observable state changes and independent settlement revisions produce a full response',function()
    local adventure,bridge,member,site=fixture();bridge('snapshot')
    local changes={
        function()adventure.travel.data.Revision=2 end,
        function()adventure.parties.data.Revision=2 end,
        function()adventure.parties.data.Clock=601 end,
        function()adventure.data.Equipment.Revision=2 end,
        function()adventure.narrative.data.Revision=2 end,
        function()adventure.narrative.data.Minutes=601 end,
        function()adventure.factions.data.Revision=2 end,
        function()site.Revision=2 end,
        function()adventure.player.Coins=90 end,
        function()adventure.player.Level=2 end,
        function()adventure.data.JournalCount=1 end,
        function()adventure.data.ResultText='new result'end,
        function()adventure.characterSaves.Status='save failed'end,
        function()adventure.characterSaves.HasSave=false end,
        function()member.HP=20 end,
        function()member.MaxHP=45 end,
        function()member.Growth.Revision=2 end,
        function()member.CustomizationJson='new appearance'end,
        function()member.Effects.Revision=2 end,
        function()member.TraitCount=1;member.traits[1]=7 end,
        function()member.traits[1]=8 end,
        function()member.Id=2 end,
    }
    for _,change in ipairs(changes)do
        local before=adventure.snapshots;change()
        assert(bridge('snapshot').unchanged==false and adventure.snapshots==before+1)
        assert(bridge('snapshot').unchanged and adventure.snapshots==before+1)
    end
end)

test('member mounts and world identity invalidate the paused fingerprint',function()
    local adventure,bridge,member=fixture();bridge('snapshot')
    member.MountedAnimal=actor(200);assert(bridge('snapshot').unchanged==false)
    member.MountedAnimal.HP=10;assert(bridge('snapshot').unchanged==false)
    member.MountedAnimal=nil;assert(bridge('snapshot').unchanged==false)
    adventure.map={};assert(bridge('snapshot').unchanged==false)
    assert(bridge('snapshot').unchanged)
end)

test('commands including early-return queries invalidate stable polling',function()
    local adventure,bridge=fixture();bridge('snapshot');assert(bridge('snapshot').unchanged)
    local result=bridge('world_wait');assert(result.unchanged==false and adventure.commands==1 and adventure.snapshots==2)
    assert(bridge('snapshot').unchanged)
    bridge('campaign_saves');assert(bridge('snapshot').unchanged==false and adventure.snapshots==3)
end)

test('running maps and every other phase continue producing full responses',function()
    local adventure,bridge=fixture();bridge('snapshot')
    bridge('travel_pause');assert(not adventure.travel.data.Paused)
    assert(bridge('snapshot').unchanged==false and bridge('snapshot').unchanged==false)
    bridge('travel_pause');assert(bridge('snapshot').unchanged)
    for _,phase in ipairs({'area','battle','event','result'})do
        adventure.data.Phase=phase
        assert(bridge('snapshot').unchanged==false and bridge('snapshot').unchanged==false)
    end
    adventure.data.Phase='map';assert(bridge('snapshot').unchanged==false and bridge('snapshot').unchanged)
end)

test('visual events are delivered once and new events invalidate otherwise stable polling',function()
    local adventure,bridge,member=fixture()
    Effects.Item(adventure.battle,91,member,0,0,'use')
    local first=bridge('snapshot');assert(#first.visualEffects==1)
    local idle=bridge('snapshot');assert(idle.unchanged and idle.visualEffects==nil and idle.gmTeleport==nil)
    adventure.player.Coins=101
    assert(#bridge('snapshot').visualEffects==0,'Full updates must not replay the prior event')
    Effects.Item(adventure.battle,92,member,0,0,'use')
    assert(#bridge('snapshot').visualEffects==1 and bridge('snapshot').unchanged)
end)

test('the fingerprint records changes made by the narrative refresh itself',function()
    local adventure,bridge=fixture()
    function adventure.narrative:Refresh()
        adventure.refreshes=adventure.refreshes+1;self.data.Revision=self.data.Revision+1
    end
    bridge('snapshot');assert(bridge('snapshot').unchanged and adventure.refreshes==1)
end)

test('a missing required bridge field fails instead of truncating the fingerprint',function()
    local adventure,bridge,member=fixture();bridge('snapshot')
    member.ActionSequence=nil
    local ok,reason=pcall(bridge,'snapshot')
    assert(not ok and tostring(reason):find('Paused snapshot requires public state field',1,true))
    assert(adventure.snapshots==1)
end)

print('PASS paused snapshot: '..count..' focused checks')

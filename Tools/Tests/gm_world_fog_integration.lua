-- Isolated Edit Mode GM/world fog checks; run with Tools/GM/run_checks.cs using this script path.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
local function test(name,body) body();messages[#messages+1]='PASS '..name end
function CloseGMPreview() registry:Shutdown();CloseGMPreview=nil end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure')
    local gm,ui=registry:Get('GM'),registry:Get('UI')
    test('reveal world rejects an uninitialized expedition',function()
        local success,reason=gm:Execute('reveal_world')
        assert(not success and reason==require('Language').GMWorldMapUnavailable)
    end)
    adventure:Start(412)
    local first,second=adventure.data:GetPartyAt(0),adventure.data:GetPartyAt(1)
    test('full world vision reveals remote parties, survives travel and is idempotent',function()
        local fog=adventure.fog;local data=fog.data;local distant
        for i=0,adventure.parties.data.Count-1 do local party=adventure.parties.data:GetAt(i)
            if not party.Defeated and party.Role~='garrison' and party.Mission~='occupy'
                and not fog:Visible(party.Travel.Q,party.Travel.R)
                and adventure.factions:Relation(0,party.FactionId)=='hostile' then distant=party;break end
        end
        assert(distant,'Fixture needs an enemy outside normal vision')
        for _,row in ipairs(adventure.parties:Snapshot().rows) do assert(row.id~=distant.Id) end
        local q,r=adventure.travel.data.Q,adventure.travel.data.R
        assert(gm:Execute('reveal_world',0))
        assert(data.KnownCount==data.CellCount and data.VisibleCount==data.CellCount)
        local found=false;for _,row in ipairs(adventure.parties:Snapshot().rows) do if row.id==distant.Id then found=true end end
        assert(found,'Remote enemy must reach the normal world party snapshot')
        local revision=data.Revision;assert(gm:Execute('reveal_world') and data.Revision==revision)
        assert(adventure.travel.data.Q==q and adventure.travel.data.R==r,'Revealing must not move the squad')
        local travel=adventure.travel;local origin=adventure.map:GetCell(q,r);local target
        for _,cell in ipairs(adventure.map:GetCells()) do
            if require('Game.Map.HexGrid').Distance(q,r,cell.q,cell.r)==1 and travel:Cost(origin,cell) then target=cell;break end
        end
        assert(target and travel:Plan(target,0))
        while travel.data.Active do travel.data:Step(travel.data.RemainingMinutes);fog:Update() end
        assert(travel:Arrive());assert(travel.data.Q~=q or travel.data.R~=r)
        assert(data.VisibleCount==data.CellCount and data.Revision==revision,'Travel must not shrink GM vision')
        fog:Bind(adventure.map);fog:Update()
        assert(not fog.fullVision and data.KnownCount==data.CellCount and data.VisibleCount<data.CellCount,'Rebind restores normal sight and keeps discovery')
        assert(gm:Execute('reveal_world'));fog:Reset(adventure.map)
        assert(not fog.fullVision and data.KnownCount==data.VisibleCount and data.KnownCount<data.CellCount,'A new world must not inherit GM vision')
    end)
    assert(gm:Execute('goto_npc',1))
    local demo={BattleHUDRevision=0,SelectedCharacterId=first.Id,LastError='',commands=0}
    function demo:SetGMOpen(value) self.open=value end
    function demo:SendCommand(command,slot,id)
        local success,why=gm:Execute(command:sub(4),slot,id)
        self.LastError=success and '' or why;self.BattleHUDRevision=self.BattleHUDRevision+1;self.commands=self.commands+1
    end
    local panel=ui:Open('GM',{demo=demo,font=GMFont})
    test('full world button ignores actor fields and preserves local exploration and pause',function()
        local fog=adventure.fog;local area=adventure.data.Areas.Active
        local site,index=adventure.data.Areas.ActiveSiteId,area.CellIndex
        local before=demo.commands
        panel.view.Slot.text='0';panel.view.SkillId.text='invalid'
        panel.view.RevealWorld.onClick:Invoke()
        assert(demo.commands==before+1 and panel.view.Result.text==require('Language').GMRevealWorldSuccess)
        assert(fog.data.VisibleCount==fog.data.CellCount and Services.UI.IsWorldPaused)
        assert(adventure.data.Areas.ActiveSiteId==site and area.CellIndex==index)
        local revision=fog.data.Revision;panel.view.RevealWorld.onClick:Invoke();assert(fog.data.Revision==revision)
        panel.view.Close.onClick:Invoke();assert(not Services.UI.IsWorldPaused)
        assert(adventure.areas:Leave());fog:Update();assert(fog.data.VisibleCount==fog.data.CellCount)
        panel=ui:Open('GM',{demo=demo,font=GMFont})
        panel.view.Result.text=require('Language').GMRevealWorldSuccess
    end)
end,debug.traceback)
if not ok then CloseGMPreview();error(err,0) end
return 'GM world fog integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')

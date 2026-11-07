-- Real C# roster, economy, recovery, save and controller checks in disposable services.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseCampPreview() registry:Shutdown();CloseCampPreview=nil end
registry:Start()
local ui,a=registry:Get('UI'),registry:Get('Adventure')
a:Start(412)
local R=CS.ProjectY.Data.PartyRoster;local Body=CS.ProjectY.Data.BodyHealth
local camp=a.camp;local data=a.data;local leader=data:GetPartyAt(0);local messages={}
local function test(name,body) body();messages[#messages+1]='PASS '..name end
test('minimum one active and stale actions are atomic',function()
    assert(camp:Open())
    local original={};for i=0,data.PartyCount-1 do original[#original+1]=data:GetPartyAt(i) end
    for i=2,#original do assert(camp.roster:Move(original[i].Id,true,camp.data.Revision)) end
    assert(data.PartyCount==1 and R.ReserveCount(data)==3)
    local rev=camp.data.Revision
    assert(not camp.roster:Move(leader.Id,true,rev));assert(data.PartyCount==1 and camp.data.Revision==rev)
    assert(camp.roster:Move(original[2].Id,false,rev))
    assert(not camp.roster:Move(original[3].Id,false,rev));assert(data.PartyCount==2)
    for i=3,#original do assert(camp.roster:Move(original[i].Id,false,camp.data.Revision)) end
    camp:Close();assert(not camp.roster:Move(leader.Id,true,camp.data.Revision))
end)
test('recruits overflow into six reserve slots and retain identity',function()
    for _,npcId in ipairs({1,201,202,203,204,205}) do
        local definition=a.narrative.rules.npcs:Get(npcId)
        local actor=data:PrepareRecruitActor(10000+npcId,definition.actorTemplateId)
        a.characterAppearances:Party(actor,data.Seed);a.growth:PrepareActor(actor)
        actor:SetMaxHP(a.battle.stats:MaximumHP(actor));actor:Restore();data:AddPreparedRecruit(actor)
        a.narrative.data:SetValue('recruited:'..npcId,actor.Id)
        assert(R.IsReserve(data,actor.Id) and R.Find(data,actor.Id)==actor)
        a.growth:RecordJoined(actor,'test camp')
    end
    assert(data.PartyCount==4 and R.ReserveCount(data)==6 and R.Count(data)==10)
    assert(not pcall(function()data:PrepareRecruitActor(81000,leader.TemplateId)end))
end)
local patient=R.Find(data,10001)
test('full-roster swap preserves protagonist wage exemption and physical equipment',function()
    assert(camp:Open());local equipped=a.equipment.rules:Weapon(leader)
    assert(not camp.roster:Move(leader.Id,true,camp.data.Revision))
    assert(camp.roster:Swap(leader.Id,patient.Id,camp.data.Revision))
    assert(R.IsReserve(data,leader.Id) and R.IsProtagonist(data,leader.Id) and data.PartyCount==4 and R.ReserveCount(data)==6)
    if equipped then assert(a.equipment.rules:Weapon(leader)==equipped and equipped.OwnerActorId==leader.Id) end
    local _,_,_,needs=a.economy:Needs();assert(#needs==10)
    for _,row in ipairs(needs) do assert((row.wage==0)==(row.actor.Id==leader.Id),'Wage exemption followed squad position') end
    assert(camp.roster:Swap(patient.Id,leader.Id,camp.data.Revision));camp:Close()
end)
test('one day charges every member and heals reserves without repairing permanent injury',function()
    a.player:AddCoins(5000);assert(a.equipment:Grant(9100,100))
    Body.Hit(patient,5,Body.HP(patient,5),1);Body.Hit(patient,5,1,1);assert(Body.Permanent(patient,5))
    patient:Damage(math.floor(patient.HP/2))
    Body.Injure(patient,0,1,60);Body.Injure(patient,2,1,60)
    Body.ScheduleRecovery(patient,2,40,a.narrative.data.Minutes+2880)
    local current=patient.HP;local maximum=Body.RecoverableHP(patient)
    local summary=a.economy:Summary();local coins=a.player.Coins
    local active=data:GetPartyAt(1);active:Damage(1);local activeHP=active.HP
    a.narrative:AdvanceMinutes(1440)
    assert(patient.HP==math.min(maximum,current+math.floor(maximum*.25)), 'Reserve HP daily rate')
    assert(Body.Damage(patient,0)==40 and Body.Damage(patient,2)==20,'Natural treatment or accelerated schedule')
    assert(Body.Permanent(patient,5) and Body.HP(patient,5)==0 and Body.Damage(patient,5)==100)
    assert(active.HP==activeHP,'Active member received reserve healing')
    assert(a.player.Coins==coins-summary.dailyWages and a.economy:Summary().food==summary.food-summary.dailyFood,'Reserves not charged at midnight')
    local hp=patient.HP;local money=a.player.Coins;a.narrative:TickBuffs()
    assert(patient.HP==hp and a.player.Coins==money,'Same minute applied twice')
end)
test('native camp entry, roster actions and full-roster swap',function()
    assert(camp:Open())
    local definition=Services.UI:GetConfig('Camp');local view=Services.UI:CreateView('Camp');AttachCampPreview(view)
    local ctrl=require(definition.ControllerModule)(ui.context,view)
    ctrl.panelName='Camp';ctrl.panel=Services.UI:GetPanel(view);ctrl:Bind();ui.panels.Camp={name='Camp',ctrl=ctrl,view=view,definition=definition}
    local demo={WorldCamera=CampWorldCamera,LastError='',BattleHUDRevision=0}
    function demo:SetStoryOpen(value) self.storyOpen=value end
    function demo:SendCommand(command,id,revision,count)
        local ok,reason
        if command=='camp_close' then camp:Close();ui:Close('Camp');return
        elseif command=='camp_roster_move' then ok,reason=camp.roster:Move(id,count==1,revision)
        elseif command=='camp_roster_swap' then ok,reason=camp.roster:Swap(id,count,revision)
        else error(command) end
        self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    ui:Open('Camp',{demo=demo});CaptureCamp('roster-entry')
    view:Get('Roster').onClick:Invoke();assert(ctrl.state.page=='roster' and #ctrl.snapshot.rows==10)
    CaptureCamp('roster-members');ClickCamp('secondary:0');assert(#ctrl.snapshot.rows==6)
    ClickCamp('primary');assert(demo.LastError=='' and data.PartyCount==4 and R.ReserveCount(data)==6)
    assert(R.IsReserve(data,leader.Id));CaptureCamp('roster-swapped')
    ClickCamp('back');ClickCamp('close');assert(not Services.UI.IsWorldPaused)
end)
test('full save roundtrip keeps reserves, gear, injuries, wages and fractional rest progress',function()
    a.narrative:AdvanceMinutes(17)
    local Save=require('Game.Adventure.CharacterSave');assert(Save.Write(a))
    local prepared=a.characterSaves:Prepare(a.equipment.data);Save.Validate(a,prepared)
    assert(prepared.ActorCount==10 and R.PreparedActiveCount(prepared)==4)
    local hp=patient.HP;local trauma=Body.Damage(patient,0);local summary=a.economy:Summary()
    assert(Save.Read(a));data=a.data;patient=R.Find(data,10001)
    assert(R.Count(data)==10 and R.ReserveCount(data)==6 and R.IsReserve(data,leader.Id))
    assert(patient.HP==hp and Body.Damage(patient,0)==trauma and Body.Permanent(patient,5))
    assert(a.economy:Summary().dailyWages==summary.dailyWages and a.economy:Summary().food==summary.food)
    a.narrative:TickBuffs();assert(patient.HP==hp,'Loading replayed resting time')
end)
return table.concat(messages,'\n')

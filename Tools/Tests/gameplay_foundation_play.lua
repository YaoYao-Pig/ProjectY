-- Controlled Play acceptance, step 1. Run once in a fresh AdventureDemo runtime via LuaConsole.
local systems=console.systems
local adventure=systems:Get('Adventure');local ui=systems:Get('UI')
assert(adventure.data.Phase=='map' and adventure.data.PartyCount==4)
local demo=assert(ui.panels.MainHud).ctrl.demo
assert(demo and not demo.LastError)
local actor=adventure.data:GetPartyAt(0)
assert(actor.Growth.CurrentProfessionId==1 and actor.Growth:HasSkill(401))
assert(adventure.data.Equipment:CountItem(91)==4 and adventure.data.Equipment:CountItem(92)==2 and adventure.data.Equipment:CountItem(93)==1)
demo:OpenGrowth()
local panel=assert(ui.panels.CharacterGrowth).ctrl
panel.view.SkillsTab.onClick:Invoke()
local function click(command,id)
    for _,widget in ipairs(panel.pools.SkillRows) do
        if widget.row and widget.row.command==command and widget.row.id==id then
            assert(widget.view.Button.interactable,'Expected enabled career action')
            widget.view.Button.onClick:Invoke();return
        end
    end
    error('Missing real UI action: '..command)
end
click('select_course',101)
assert(panel.view.Invest.interactable);panel.view.Invest.onClick:Invoke()
assert(actor.Growth:HasSkill(101) and actor.Growth.PendingCount==0)
click('choose_profession',nil);click('growth_profession',3)
assert(actor.Growth.CurrentProfessionId==3 and actor.Growth:HasSkill(101) and not actor.Growth:HasSkill(403))
panel.view.Close.onClick:Invoke()
assert(not ui:IsOpen('CharacterGrowth') and not console.services.UI.IsWorldPaused)
local mage=adventure.data:GetPartyAt(2)
local skill=adventure.battle:Skill(mage,3)
assert(not adventure.equipment.rules:CheckSkillEquipment(mage,skill,adventure.battle.stats))
local staff
for i=0,adventure.data.Equipment.WeaponCount-1 do local weapon=adventure.data.Equipment:GetWeaponAt(i)
    if weapon.ItemId==1 then staff=weapon;break end
end
assert(staff and adventure.equipment:Command('equip',mage.Id,staff.Id,0,0))
assert(adventure.equipment.rules:CheckSkillEquipment(mage,adventure.battle:Skill(mage,3),adventure.battle.stats))
demo:SendCommand('snapshot')
return 'PASS live scene: initial careers/supplies, real career UI learning/switching, learned-skill retention and staff catalyst'

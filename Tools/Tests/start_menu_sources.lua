-- Syntax/localization contract only; no Unity startup or world generation.
package.path='Lua/?.lua;Lua/?/init.lua;'..package.path
for _,path in ipairs({'Lua/UI/Panel/StartMenuCtr.lua','Lua/UI/Widget/CampaignSaveEntry.lua','Lua/Game/Adventure/DemoBridge.lua'}) do
    local f,reason=loadfile(path);assert(f,reason)
end
local Language=require('Language')
for _,key in ipairs({'MenuDelete','MenuDeletePrompt','MenuDeleteActive','MenuPreviewMissing','MenuPreviewUnreadable','MenuSelectedInfo','MenuAboutVersion','MenuReducedMotion'})do
    assert(type(Language[key])=='string' and Language[key]~='',key)
end
assert(string.format(Language.MenuSelectedInfo,'4294967295',100000,'party','preview'):find('100000',1,true))
assert(string.format(Language.MenuDeletePrompt,'test world'):find('test world',1,true))
print('PASS menu Lua syntax and localization templates')

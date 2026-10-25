-- Execute in a separate LuaEnv with saved prefab clones and native widget factories.
-- Does not use the running game's LuaEnv, UIHost, time scale, data or scene objects.
local adventure=dofile('Tools/Tests/faction_tree.lua')
local errors={};local panel
local host={
    CreateWidget=function(_,name,parent)return CreateFactionPreviewWidget(name,parent)end,
    SetWidgetVisible=function(_,reference,value)reference.gameObject:SetActive(value)end,
    DestroyWidget=function(_,reference)DestroyFactionPreviewWidget(reference)end,
}
local ui={Close=function(_,name)assert(name=='FactionRelations');panel:Hide()end}
local context={services={UI=host},log=function(message)errors[#errors+1]=message end,
    systems={Get=function(_,name)if name=='Adventure' then return adventure elseif name=='UI' then return ui end;error(name)end}}
panel=require('UI.Panel.FactionRelationsCtr')(context,FactionPreviewRoot);panel.panelName='FactionRelations'
local function check()
    assert(#errors==0,table.concat(errors,'\n'))
    local shown=0
    for _,widget in ipairs(panel.nodes) do
        if widget.row then
            shown=shown+1;assert(widget.view.Root.gameObject.activeSelf)
            assert(widget.view.Name.text==widget.row.name)
            assert(widget.view.Button.interactable==widget.row.discovered)
            if widget.row.discovered then assert(widget.view.Detail.text:find(tostring(widget.row.value),1,true))
            else assert(widget.view.Detail.text==require('Language').UIFactionUnknownHint) end
        else assert(not widget.view.Root.gameObject.activeSelf) end
    end
    assert(shown==#panel.tree.nodes)
    for i,widget in ipairs(panel.edges) do assert(widget.view.Root.gameObject.activeSelf==(i<=#panel.tree.edges)) end
end
local ok,err=xpcall(function()
    panel:Bind();panel:Show({});check();assert(panel.rootId==0 and not panel.view.Home.interactable)
    CaptureFactionPreview('faction-relations-player')
    local target=panel.nodes[1].row.id;panel.nodes[1].view.Button.onClick:Invoke();check()
    assert(panel.rootId==target and panel.view.Home.interactable)
    local total=#panel.widgets
    for _,policy in ipairs(adventure.factions.rules.policies:All()) do panel:Select(policy.id);check() end
    panel:Select(4);check();CaptureFactionPreview('faction-relations-orcs')
    panel.view.Home.onClick:Invoke();assert(panel.rootId==0);check()
    panel.view.Close.onClick:Invoke();assert(not panel.visible)
    panel:Show({rootId=1});check();assert(panel.rootId==1)
    assert(#panel.widgets<total+20,'Switching roots must reuse widget pools')
    panel.view.GraphScroll.verticalNormalizedPosition=0
    panel.nodes[1].view.Button.onClick:Invoke();assert(panel.view.GraphScroll.verticalNormalizedPosition==1)
    for _,policy in ipairs(adventure.factions.rules.policies:All()) do adventure.narrative.data:SetValue('faction_seen:'..policy.id,0) end
    panel:Select(0);check();assert(panel.tree.unknownCount==15 and panel.view.UnknownTitle.gameObject.activeSelf)
    panel.nodes[1].view.Button.onClick:Invoke();assert(panel.rootId==0,'Unknown native button leaked a viewpoint')
    require('Game.Adventure.FactionDiscovery').Mark(adventure.factions,1)
    require('Game.Adventure.FactionDiscovery').Mark(adventure.factions,4)
    panel:Hide();panel:Show({});check();assert(panel.tree.unknownCount==13)
    CaptureFactionPreview('faction-relations-discovery')
    print('PASS unknown native cards are masked and disabled; reopening reveals only encountered factions')
    print('PASS native buttons, all roots, localized relationship values, node/edge pooling, close/reopen and scroll reset')
end,debug.traceback)
panel:Dispose()
if not ok then error(err,0) end
return 'PASS isolated native faction tree controller and saved prefab bindings'

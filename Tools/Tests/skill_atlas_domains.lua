-- Exercise the real controller callbacks with only the six declared domain bindings.
-- No Editor, prefab mutation or gameplay transaction is involved.
package.path='Lua/?.lua;'..package.path
CS={UnityEngine={Color=function(...)return {...}end}}
local Atlas=require('UI.Panel.SkillAtlasCtr')
local Language=require('Language')
local function signal()
    return {AddListener=function(self,fn)self.fn=fn end,RemoveListener=function(self,fn)if self.fn==fn then self.fn=nil end end,
        Invoke=function(self)assert(self.fn)()end}
end
local function component()
    return {gameObject={activeSelf=true,SetActive=function(self,value)self.activeSelf=value end},onClick=signal(),onEndEdit=signal(),text=''}
end
local function fixture(count)
    local domains,byId,categories,nodes,skills={},{},{},{},{}
    for index=1,count do
        local id=100+index*7
        local domain={id=id,name='Domain '..index,order=index}
        domains[count-index+1]=domain;byId[id]=domain
        for sub=1,2 do categories[id*10+sub]={id=id*10+sub,name='Category '..sub,disciplineId=id}end
        nodes[9000+index]={id=9000+index,categoryId=id*10+1,x=index,y=0}
        skills[9000+index]={id=9000+index,name='Skill '..index}
    end
    local function lookup(rows)
        return {Get=function(_,id)return assert(rows[id],'Unexpected identity '..tostring(id))end,
            All=function()local result={};for _,row in pairs(rows)do result[#result+1]=row end;return result end}
    end
    local calls={}
    local atlas={disciplines={All=function()return domains end,Get=function(_,id)return assert(byId[id])end},
        categories=lookup(categories),nodes=lookup(nodes),skills=lookup(skills),
        Categories=function(_,id)
            assert(byId[id],'Only a real discipline may be passed to Categories')
            calls[#calls+1]=id;return {categories[id*10+1],categories[id*10+2]}
        end,
        Owned=function()return {}end,Nodes=function()return {}end,Path=function(_,id)return 'Path '..id end,
        Search=function(_,query)return query~='' and {nodes[9000+count]} or {}end}
    local actors={{Id=1,Growth={CurrentProfessionId=1,Revision=0}},{Id=2,Growth={CurrentProfessionId=2,Revision=0}}}
    local data={PartyCount=2,Equipment={Revision=0},GetPartyAt=function(_,index)return actors[index+1]end}
    local professions={professions=lookup({[1]={id=1,initialSkillIds={9000+count}},[2]={id=2,initialSkillIds={9001}}})}
    local growth={stats={Template=function(_,actor)return {name='Actor '..actor.Id}end},data=data,rules={atlas=atlas,professions=professions}}
    local view={Style={Prepare=function()end,Highlight=function(_,button,selected)button.highlighted=selected end},
        Geometry={Dismiss=function()end,Focus=function()end,Follow=function()end}}
    for _,name in ipairs({'Close','TipClose','Dismiss','SearchButton','ClearSearch','Search','SearchResults','CloseText','SearchSummary','Categories','Results'})do view[name]=component()end
    for index=1,4 do view['Party'..index]=component();view['Party'..index..'Text']=component()end
    for index=1,6 do view['Domain'..index]=component();view['Domain'..index..'Text']=component()end
    setmetatable(view,{__index=function(_,key)error('Undeclared binding '..key)end})
    local panel=setmetatable({view=view,context={systems={Get=function(_,name)assert(name=='Growth');return growth end}},lifetime={Add=function()end}},Atlas)
    function panel:Listen(button,callback)button.onClick:AddListener(callback)end
    function panel:Graph()self.graphCategory=self.categoryId end
    function panel:CreateWidget(name)
        assert(name=='SkillAtlasCategory')
        return {SetData=function(self,label,summary,style,selected,callback)self.label=label;self.action=callback;self.selected=selected end}
    end
    panel:Bind();panel:OnShow({demo={SetGrowthOpen=function()end}})
    return panel,calls
end
local passed=0
local function test(name,run)run();passed=passed+1;print('PASS '..name)end

test('eight domains open on the entrants profession page and expose every domain through real buttons',function()
    local panel=fixture(8)
    assert(panel.domainPage==2 and panel.disciplineId==156)
    assert(panel.view.Domain3Text.text=='Domain 8' and panel.view.Domain3.highlighted)
    assert(not panel.view.Domain4.gameObject.activeSelf and not panel.view.Domain5.gameObject.activeSelf)
    assert(panel.view.Domain6Text.text==string.format(Language.SkillAtlasDomainNextPage,2,2))
    local seen={}
    for page=1,2 do
        for slot=1,5 do
            if panel.view['Domain'..slot].gameObject.activeSelf then
                panel.view['Domain'..slot].onClick:Invoke()
                seen[panel.disciplineId]=true
                assert(panel.atlas.categories:Get(panel.categoryId).disciplineId==panel.disciplineId)
            end
        end
        panel.view.Domain6.onClick:Invoke()
    end
    local total=0;for _ in pairs(seen)do total=total+1 end;assert(total==8)
    assert(panel.domainPage==2 and panel.disciplineId==142,'Cycling must select the new page first real domain')
end)

test('category selection and actor switch retain the visible page; search follows cross-page results',function()
    local panel=fixture(8)
    panel.categories[2].action();assert(panel.categoryId==1562 and panel.domainPage==2)
    panel.view.Party2.onClick:Invoke();assert(panel.actorIndex==1 and panel.domainPage==2 and panel.categoryId==1562)
    panel.view.Domain6.onClick:Invoke();assert(panel.domainPage==1)
    panel.view.Search.text='last';panel.view.SearchButton.onClick:Invoke()
    assert(panel.view.SearchResults.gameObject.activeSelf and #panel.results==1)
    panel.results[1].action()
    assert(panel.domainPage==2 and panel.disciplineId==156 and panel.selectedId==9008)
    assert(not panel.view.SearchResults.gameObject.activeSelf and panel.view.Domain3.highlighted)
    panel.view.ClearSearch.onClick:Invoke();assert(panel.domainPage==2 and panel.selectedId==9008)
end)

test('six and fewer domains retain all original slots without a pager',function()
    local panel=fixture(6)
    assert(panel.domainPage==1 and panel.view.Domain6Text.text=='Domain 6')
    panel.view.Domain6.onClick:Invoke();assert(panel.disciplineId==142)
    local small=fixture(1)
    assert(small.view.Domain1.gameObject.activeSelf and not small.view.Domain2.gameObject.activeSelf)
    assert(not small.view.Domain6.gameObject.activeSelf)
end)

test('future thirteen-domain content cycles every page and search repositions from the last page',function()
    local panel,calls=fixture(13)
    assert(panel.domainPage==3 and panel.view.Domain3Text.text=='Domain 13')
    local seen={}
    for page=1,3 do
        for slot=1,5 do
            if panel.view['Domain'..slot].gameObject.activeSelf then
                panel.view['Domain'..slot].onClick:Invoke();seen[panel.disciplineId]=true
            end
        end
        panel.view.Domain6.onClick:Invoke()
    end
    local total=0;for _ in pairs(seen)do total=total+1 end;assert(total==13)
    panel:Jump(9001);assert(panel.domainPage==1 and panel.view.Domain1.highlighted)
    panel:Jump(9013);assert(panel.domainPage==3 and panel.view.Domain3.highlighted)
    panel:OnShow({demo={SetGrowthOpen=function()end},actorIndex=1})
    assert(panel.domainPage==1 and panel.disciplineId==107,'Cached reopen must align to the entrants current profession')
    assert(#calls>13)
end)
print('PASS skill_atlas_domains: '..passed..' groups')

local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Atlas=Class('SkillAtlasCtr',Base)
function Atlas:Bind()
    self.growth=self.context.systems:Get('Growth');self.stats=self.growth.stats;self.atlas=self.growth.rules.atlas
    self.categories,self.nodes,self.edges,self.results,self.links={},{},{},{},{}
    self.view.Style:Prepare()
    self:Listen(self.view.Close,function() self:Close() end)
    self:Listen(self.view.TipClose,function() self:Deselect() end)
    self:Listen(self.view.Dismiss,function() self:Deselect() end)
    self:Listen(self.view.SearchButton,function() self:Search() end)
    self:Listen(self.view.ClearSearch,function() self.view.Search.text='';self:Search() end)
    for i=1,4 do self:Listen(self.view['Party'..i],function() self.actorIndex=i-1;self:Refresh() end) end
    for i=1,6 do self:Listen(self.view['Domain'..i],function()
        local domain=self.domains[i];self.disciplineId=domain.id;self.categoryId=self.atlas:Categories(domain.id)[1].id;self.selectedId=nil;self.view.Geometry:Dismiss();self:Refresh()
    end) end
    local function query() self:Search() end
    self.view.Search.onEndEdit:AddListener(query);self.lifetime:Add(function() self.view.Search.onEndEdit:RemoveListener(query) end)
end
function Atlas:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetGrowthOpen(true)
    self.actorIndex,self.disciplineId,self.categoryId,self.selectedId=0,3,31,nil
    self.domains={};for _,row in ipairs(self.atlas.disciplines:All()) do self.domains[#self.domains+1]=row end
    table.sort(self.domains,function(a,b) return a.order<b.order end)
    assert(#self.domains<=6,'Skill atlas layout supports six primary domains')
    self.view.Search.text='';self.view.SearchResults.gameObject:SetActive(false);self.view.Geometry:Dismiss();self:Refresh()
end
function Atlas:Deselect() self.selectedId=nil;self.view.Geometry:Dismiss();self:Graph() end
function Atlas:Refresh()
    local data=self.growth.data;self.actor=assert(data:GetPartyAt(self.actorIndex));self.owned=self.atlas:Owned(self.actor,self.stats)
    for i=1,4 do
        self.view['Party'..i].gameObject:SetActive(i<=data.PartyCount)
        if i<=data.PartyCount then self.view['Party'..i..'Text'].text=self.stats:Template(data:GetPartyAt(i-1)).name end
        self.view.Style:Highlight(self.view['Party'..i],i-1==self.actorIndex)
        self.view['Party'..i..'Text'].color=i-1==self.actorIndex and CS.UnityEngine.Color(.94,.88,.74) or CS.UnityEngine.Color(.20,.25,.22)
    end
    for i=1,6 do
        local domain=self.domains[i];self.view['Domain'..i].gameObject:SetActive(domain~=nil)
        if domain then
            local selected=domain.id==self.disciplineId;self.view['Domain'..i..'Text'].text=domain.name
            self.view.Style:Highlight(self.view['Domain'..i],selected)
            self.view['Domain'..i..'Text'].color=selected and CS.UnityEngine.Color(.94,.88,.74) or CS.UnityEngine.Color(.20,.25,.22)
        end
    end
    local rows=self.atlas:Categories(self.disciplineId)
    for i,row in ipairs(rows) do
        if not self.categories[i] then self.categories[i]=self:CreateWidget('SkillAtlasCategory',self.view.Categories) end
        self.categories[i]:SetData(row.name,#self.atlas:Nodes(row.id)..' 项技艺',self.view.Style,row.id==self.categoryId,function()
            self.categoryId=row.id;self.selectedId=nil;self.view.Geometry:Dismiss();self:Refresh();self.view.Geometry:Focus(0,0)
        end)
    end
    for i=#rows+1,#self.categories do self.categories[i]:SetData(nil) end
    self:Graph()
    self.revision=self.actor.Growth.Revision;self.equipmentRevision=data.Equipment.Revision
end
function Atlas:Graph()
    local rows=self.atlas:Nodes(self.categoryId);local visible={};local width,height=910,425
    local related=self.selectedId and self.atlas:Related(self.selectedId)
    for _,row in ipairs(rows) do visible[row.id]=row;width=math.max(width,row.x+100);height=math.max(height,row.y+90) end
    self.view.Graph.sizeDelta=CS.UnityEngine.Vector2(width,height)
    local category=self.atlas.categories:Get(self.categoryId)
    self.view.TreeTitle.text=self.atlas.disciplines:Get(category.disciplineId).name..' / '..category.name
    self.view.Empty.gameObject:SetActive(#rows==0)
    local edgeCount=0
    for _,row in ipairs(rows) do for _,id in ipairs(row.prerequisiteIds) do if visible[id] then
        edgeCount=edgeCount+1;if not self.edges[edgeCount] then self.edges[edgeCount]=self:CreateWidget('SkillAtlasEdge',self.view.Graph) end
        local edge=self.edges[edgeCount]
        edge:SetData(visible[id],row,self.view.Style,self.owned[id] and self.owned[row.id],not related or (related[id] and related[row.id]))
        edge.view.Root:SetAsFirstSibling()
    end end end
    for i=edgeCount+1,#self.edges do self.edges[i]:SetData(nil) end
    for i,row in ipairs(rows) do
        if not self.nodes[i] then self.nodes[i]=self:CreateWidget('SkillAtlasNode',self.view.Graph) end
        local state,label=self.atlas:State(row.id,self.actor,self.stats,self.owned)
        if row.categoryId~=self.categoryId then label='关联 · '..self.atlas.categories:Get(row.categoryId).name end
        self.nodes[i]:SetData(row,self.atlas.skills:Get(row.id),state,label,self.view.Style,self.view.Geometry,self.selectedId==row.id,
            not related or related[row.id],function(id,anchor)
                if self.atlas.nodes:Get(id).categoryId~=self.categoryId then self:Jump(id) else self:Select(id,anchor) end
            end)
    end
    for i=#rows+1,#self.nodes do self.nodes[i]:SetData(nil) end
    if self.selectedId and visible[self.selectedId] then self:Tip() end
end
function Atlas:Select(id,anchor)
    self.selectedId=id;self:Graph();self:Tip();self.view.Geometry:Follow(anchor)
end
function Atlas:Tip()
    local id=self.selectedId;local skill=self.atlas.skills:Get(id)
    local detail,node=self.atlas:Details(id,self.actor,self.stats,self.owned)
    self.view.TipTitle.text=skill.name;self.view.TipPath.text=self.atlas:Path(id)
    self.view.TipDetail.text=detail;self.view.TipDetail.rectTransform.sizeDelta=CS.UnityEngine.Vector2(272,self.view.TipDetail.preferredHeight+6)
    self.view.TipBody.sizeDelta=CS.UnityEngine.Vector2(280,self.view.TipDetail.preferredHeight+12)
    self.view.PrerequisiteTitle.text=#node.prerequisiteIds==0 and '无前置技能' or (node.prerequisiteMode=='all' and '前置：全部掌握' or '前置：任意掌握')
    for i,other in ipairs(node.prerequisiteIds) do
        if not self.links[i] then self.links[i]=self:CreateWidget('SkillAtlasCategory',self.view.Prerequisites) end
        self.links[i]:SetData((self.owned[other] and '✓ ' or '○ ')..self.atlas.skills:Get(other).name,self.atlas:Path(other),self.view.Style,false,function() self:Jump(other) end)
    end
    for i=#node.prerequisiteIds+1,#self.links do self.links[i]:SetData(nil) end
end
function Atlas:Jump(id)
    local node=self.atlas.nodes:Get(id);local category=self.atlas.categories:Get(node.categoryId)
    self.disciplineId,self.categoryId,self.selectedId=category.disciplineId,category.id,id
    self.view.SearchResults.gameObject:SetActive(false);self.view.Geometry:Dismiss();self:Refresh();self.view.Geometry:Focus(node.x,node.y)
    for _,widget in ipairs(self.nodes) do if widget.node and widget.node.id==id then self.view.Geometry:Follow(widget.view.Root);break end end
end
function Atlas:Search()
    local query=self.view.Search.text:match('^%s*(.-)%s*$');local rows=self.atlas:Search(query)
    if query~='' then self.view.Geometry:Dismiss() end
    self.view.SearchResults.gameObject:SetActive(query~='')
    self.view.SearchSummary.text=#rows..' 项匹配结果'
    for i,row in ipairs(rows) do
        if not self.results[i] then self.results[i]=self:CreateWidget('SkillAtlasCategory',self.view.Results) end
        self.results[i]:SetData(self.atlas.skills:Get(row.id).name,self.atlas:Path(row.id),self.view.Style,false,function() self:Jump(row.id) end)
    end
    for i=#rows+1,#self.results do self.results[i]:SetData(nil) end
end
function Atlas:Tick()
    if self.view.Geometry.BackPressed then
        if self.view.SearchResults.gameObject.activeSelf then self.view.Search.text='';self:Search()
        elseif self.view.Geometry.PopupVisible then self:Deselect() else self:Close() end
        return
    end
    if self.revision~=self.actor.Growth.Revision or self.equipmentRevision~=self.growth.data.Equipment.Revision then self:Refresh() end
end
function Atlas:OnHide() self.view.Geometry:Dismiss();if self.demo then self.demo:SetGrowthOpen(false);self.demo=nil end end
return Atlas

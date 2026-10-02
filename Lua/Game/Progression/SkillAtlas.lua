-- 技能目录、依赖与只读显示查询。技能身份始终来自 CombatSkillTable。
local Atlas={};Atlas.__index=Atlas
local function contains(values,id) for _,value in ipairs(values) do if value==id then return true end end return false end
function Atlas.New(config)
    local self=setmetatable({skills=config:GetTable('CombatSkillTable'),nodes=config:GetTable('SkillAtlasTable'),
        disciplines=config:GetTable('SkillDisciplineTable'),categories=config:GetTable('SkillCategoryTable'),
        pools=config:GetTable('ActiveSkillPoolTable'),attributes=config:GetTable('GrowthAttributeTable'),
        construction=config:GetTable('ConstructionTable'),items=config:GetTable('EquipmentItemTable'),children={},universal={}},Atlas)
    for _,row in ipairs(self.construction:All()) do if row.kind=='demolish' then self.universal[row.id]=true end end
    for _,category in ipairs(self.categories:All()) do self.disciplines:Get(category.disciplineId) end
    for _,skill in ipairs(self.skills:All()) do self.nodes:Get(skill.id);self.children[skill.id]={} end
    for _,node in ipairs(self.nodes:All()) do
        self.skills:Get(node.id);self.categories:Get(node.categoryId)
        local seen={}
        for _,id in ipairs(node.relatedCategoryIds) do assert(id~=node.categoryId and not seen[id],'Duplicate skill category');self.categories:Get(id);seen[id]=true end
        seen={}
        for _,id in ipairs(node.prerequisiteIds) do
            assert(id~=node.id and not seen[id],'Invalid skill prerequisite');self.nodes:Get(id);seen[id]=true
            self.children[id][#self.children[id]+1]=node.id
        end
    end
    local visiting,done={},{}
    local function visit(id)
        assert(not visiting[id],'Cyclic active skill prerequisites: '..id)
        if done[id] then return end
        visiting[id]=true
        for _,other in ipairs(self.nodes:Get(id).prerequisiteIds) do visit(other) end
        visiting[id]=nil;done[id]=true
    end
    for _,node in ipairs(self.nodes:All()) do visit(node.id) end
    return self
end
function Atlas:Owned(actor,stats)
    local result={}
    for _,id in ipairs(stats.equipment:SkillIds(actor,stats:Template(actor))) do result[id]=true end
    if stats.animals then for _,id in ipairs(stats.animals:AddSkills(actor,{})) do result[id]=true end end
    -- 破坏工事是人人可用的战场动作，不进入升级研习候选。
    for id in pairs(self.universal) do result[id]=true end
    return result
end
function Atlas:Prerequisites(id,owned)
    local node=self.nodes:Get(id);local count=0
    for _,other in ipairs(node.prerequisiteIds) do if owned[other] then count=count+1 end end
    return #node.prerequisiteIds==0 or (node.prerequisiteMode=='any' and count>0) or count==#node.prerequisiteIds
end
function Atlas:Categories(discipline)
    local result={}
    for _,row in ipairs(self.categories:All()) do if row.disciplineId==discipline then result[#result+1]=row end end
    table.sort(result,function(a,b) return a.order==b.order and a.id<b.id or a.order<b.order end)
    return result
end
function Atlas:Nodes(category)
    local result={}
    for _,row in ipairs(self.nodes:All()) do if row.categoryId==category or contains(row.relatedCategoryIds,category) then result[#result+1]=row end end
    return result
end
function Atlas:Path(id)
    local category=self.categories:Get(self.nodes:Get(id).categoryId)
    return self.disciplines:Get(category.disciplineId).name..' / '..category.name
end
function Atlas:Search(query)
    local result={};query=query:lower():match('^%s*(.-)%s*$')
    if query=='' then return result end
    for _,node in ipairs(self.nodes:All()) do
        local skill=self.skills:Get(node.id)
        local text=skill.name..' '..skill.description..' '..self:Path(node.id)..' '..table.concat(node.tags,' ')
        if text:lower():find(query,1,true) then result[#result+1]=node end
    end
    return result
end
function Atlas:Related(id)
    local result={[id]=true}
    local function ancestors(value)
        for _,other in ipairs(self.nodes:Get(value).prerequisiteIds) do if not result[other] then result[other]=true;ancestors(other) end end
    end
    ancestors(id)
    for _,other in ipairs(self.children[id]) do result[other]=true end
    return result
end
function Atlas:State(id,actor,stats,owned)
    if owned[id] then return 'owned',actor.Growth:HasSkill(id) and '已掌握' or '当前可用' end
    if not self:Prerequisites(id,owned) then return 'locked','前置未满足' end
    local hasPool=false
    for _,pool in ipairs(self.pools:All()) do if pool.skillId==id then
        hasPool=true
        local value=stats:Get(actor,self.attributes:Get(pool.attributeId).code,not stats.growth.settings.includeEquipment)
        if value>=pool.minValue and value<=pool.maxValue then return 'eligible','满足研习条件' end
    end end
    return hasPool and 'locked' or 'source',hasPool and '属性未满足' or '特定途径获取'
end
function Atlas:Details(id,actor,stats,owned)
    local skill=self.skills:Get(id);local node=self.nodes:Get(id)
    local _,status=self:State(id,actor,stats,owned)
    local contexts={};for _,value in ipairs(skill.contexts) do contexts[#contexts+1]=value=='battle' and '战斗' or '探索' end
    local lines={table.concat(contexts,' / ')..' · '..(skill.action=='main' and '主要行动' or '次要行动'),
        '行动点 '..skill.cost..'    距离 '..skill.range..' 格    冷却 '..skill.cooldownTurns..' 回合',skill.description}
    local construction=self.construction:Find(id)
    if construction then
        local material={}
        for i,item in ipairs(construction.itemIds) do material[#material+1]=self.items:Get(item).name..' ×'..construction.itemCounts[i] end
        lines[#lines+1]=#material>0 and ('材料：'..table.concat(material,'、')) or '材料：无'
        if construction.maxHP>0 then lines[#lines+1]='结构耐久：'..construction.maxHP..' + 巧匠 ×'..construction.hpPerCrafting end
        if construction.toolTag~='' then lines[#lines+1]='工具：角色须装备铲子；仅可挖掘未铺装的泥土、草地' end
        if construction.kind~='demolish' then lines[#lines+1]='占地：1 格 · 保留至本次远征结束' end
        if construction.kind=='demolish' then lines[#lines+1]='探索时每次消耗 '..construction.workRounds..' 回合，可清理战后遗留工事' end
    end
    local requirements,seen={},{}
    for _,pool in ipairs(self.pools:All()) do if pool.skillId==id then
        local row=self.attributes:Get(pool.attributeId);local text=row.name..' ≥ '..pool.minValue
        if not seen[text] then seen[text]=true;requirements[#requirements+1]=text end
    end end
    if #requirements>0 then lines[#lines+1]='研习属性（任一）：'..table.concat(requirements,' / ');lines[#lines+1]='获取：升级研习中随机出现，点击图谱不会学习'
    elseif self.universal[id] then lines[#lines+1]='获取：战斗中的通用动作'
    else lines[#lines+1]='获取：角色固有、装备或骑乘能力' end
    lines[#lines+1]=status
    return table.concat(lines,'\n\n'),node
end
return Atlas

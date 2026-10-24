-- 定向检查：真实导表二进制、技能独立表现、物品类别继承与缺配置失败边界。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Catalog=require('Game.Presentation.VisualEffectCatalog')
local profiles=config:GetTable('VisualEffectTable')
local skills=config:GetTable('CombatSkillTable')
local items=config:GetTable('EquipmentItemTable')
local categories=config:GetTable('VisualEffectItemCategoryTable')
local passed=0
local function test(name,run) run();passed=passed+1;print('PASS '..name) end
local function fails(run,message)
    local ok,reason=pcall(run)
    assert(not ok,'Invalid visual content must fail')
    assert(tostring(reason):find(message,1,true),tostring(reason))
end
local function copy(row)
    local result={};for key,value in pairs(row) do result[key]=value end;return result
end
-- Keep every unmodified table and row on the real ConfigSystem/binary path.
local function withRows(name,extra)
    local original=config:GetTable(name)
    local rows,byId={},{}
    local key=name=='VisualEffectItemCategoryTable' and 'kind' or 'id'
    for _,row in ipairs(original:All()) do rows[#rows+1]=row;byId[row[key]]=row end
    for _,row in ipairs(extra) do
        assert(not byId[row[key]],'Fixture must append a new identity')
        rows[#rows+1]=row;byId[row[key]]=row
    end
    local replacement={Count=#rows,All=function() return rows end,
        Get=function(_,id) return assert(byId[id],name..': missing row '..tostring(id)) end}
    return {GetTable=function(_,requested) return requested==name and replacement or config:GetTable(requested) end}
end

test('all exported profiles use supported patterns, finite bounds and HTML colors',function()
    local patterns={slash=true,thrust=true,burst=true,ring=true,shield=true,spiral=true,beam=true,arc=true,
        rain=true,cross=true,column=true,scatter=true,rune=true,shards=true,tether=true,footprint=true}
    local bounds={count={1,128},lifetime={.05,8},size={.005,.5},radius={.01,4},height={.01,5},
        emission={0,8},speed={0,12},gravity={-5,12}}
    for _,profile in ipairs(profiles:All()) do
        assert(patterns[profile.pattern],'Unknown particle pattern: '..profile.pattern)
        assert(profile.id>0 and #profile.name>0)
        for _,key in ipairs({'color','accent'}) do
            assert(profile[key]:match('^#%x%x%x%x%x%x$'),'Invalid HTML color: '..profile.id..'.'..key)
        end
        for key,range in pairs(bounds) do
            local value=profile[key]
            assert(type(value)=='number' and value==value and value>-math.huge and value<math.huge,
                'Non-finite profile field: '..profile.id..'.'..key)
            assert(value>=range[1] and value<=range[2],'Out-of-range profile field: '..profile.id..'.'..key)
        end
        assert(profile.count%1==0,'Particle counts must be integers')
    end
    assert(profiles.Count>=104,'Expected the complete skill and item visual library')
end)

test('every skill has a unique profile and a structural signature beyond its colors',function()
    local snapshot=Catalog.Snapshot(config)
    assert(rawlen(snapshot.profiles)==profiles.Count,'C# bridge needs a concrete array, not a read-only proxy')
    local seen,signatures={},{}
    assert(skills.Count>=72 and #snapshot.skills==skills.Count)
    for _,entry in ipairs(snapshot.skills) do
        local skill=skills:Get(entry.id)
        assert(entry.profileId==skill.visualEffectId and entry.trajectory==skill.trajectory)
        assert(not seen[entry.profileId],'Duplicate skill profile: '..entry.id)
        seen[entry.profileId]=true
        local profile=profiles:Get(entry.profileId)
        local parts={}
        for _,key in ipairs({'pattern','count','lifetime','size','radius','height','speed','gravity'}) do
            parts[#parts+1]=tostring(profile[key])
        end
        local signature=table.concat(parts,'|')
        assert(not signatures[signature],'Only color differentiates skill '..entry.id)
        signatures[signature]=true
    end
end)

test('all current items resolve explicit overrides or one of eight complete categories',function()
    local snapshot=Catalog.Snapshot(config)
    local kindCount,usedCategories,overrides,defaults=0,{},0,0
    for _,category in ipairs(categories:All()) do
        profiles:Get(category.visualEffectId);usedCategories[category.kind]=false;kindCount=kindCount+1
    end
    assert(kindCount==8 and items.Count>=116 and #snapshot.items==items.Count)
    local projected={};for _,entry in ipairs(snapshot.items) do projected[entry.id]=entry.profileId end
    for _,item in ipairs(items:All()) do
        assert(usedCategories[item.kind]~=nil,'Unmapped item kind: '..item.kind)
        usedCategories[item.kind]=true
        local expected=item.visualEffectId
        if expected==0 then expected=categories:Get(item.kind).visualEffectId;defaults=defaults+1
        else overrides=overrides+1 end
        assert(Catalog.Item(config,item.id).id==expected and projected[item.id]==expected,
            'Item lookup and snapshot disagree: '..item.id)
    end
    for kind,used in pairs(usedCategories) do assert(used,'Unused item category fixture: '..kind) end
    assert(overrides>0 and defaults>0,'Both item resolution paths must be exercised')
    assert(Catalog.Item(config,91).id==701 and Catalog.Item(config,92).id==702,
        'Consumable use and item display must share the medical and potion identities')
end)

test('future items inherit each category automatically and can override it explicitly',function()
    local appended={}
    for index,category in ipairs(categories:All()) do
        local item=copy(items:All()[1]);item.id=900000+index;item.kind=category.kind;item.visualEffectId=0
        appended[#appended+1]=item
    end
    local special=copy(appended[1]);special.id=900100;special.visualEffectId=profiles:All()[1].id
    appended[#appended+1]=special
    local future=withRows('EquipmentItemTable',appended)
    for _,item in ipairs(appended) do
        local expected=item.visualEffectId~=0 and item.visualEffectId or categories:Get(item.kind).visualEffectId
        assert(Catalog.Item(future,item.id).id==expected)
    end
    local snapshot=Catalog.Snapshot(future)
    assert(#snapshot.items==items.Count+#appended,'New items must appear in the C# snapshot')
end)

test('new skills missing a profile or reusing another skill profile fail clearly',function()
    for _,id in ipairs({0,999999}) do
        local skill=copy(skills:All()[1]);skill.id=910000+id;skill.visualEffectId=id
        fails(function() Catalog.Snapshot(withRows('CombatSkillTable',{skill})) end,'VisualEffectTable: missing row '..id)
    end
    local skill=copy(skills:All()[1]);skill.id=920000;skill.visualEffectId=nil
    fails(function() Catalog.Snapshot(withRows('CombatSkillTable',{skill})) end,'VisualEffectTable: missing row nil')
    skill.visualEffectId=skills:All()[1].visualEffectId
    fails(function() Catalog.Snapshot(withRows('CombatSkillTable',{skill})) end,'Each skill requires its own visual effect')
end)

test('unknown future categories and broken item overrides cannot silently disappear',function()
    local item=copy(items:All()[1]);item.id=930000;item.kind='unregistered_kind';item.visualEffectId=0
    fails(function() Catalog.Item(withRows('EquipmentItemTable',{item}),item.id) end,
        'VisualEffectItemCategoryTable: missing row unregistered_kind')
    item.kind='weapon';item.visualEffectId=999999
    fails(function() Catalog.Item(withRows('EquipmentItemTable',{item}),item.id) end,'VisualEffectTable: missing row 999999')
end)

test('particle Resources shader and supporting assets have importable Unity metadata',function()
    local paths={
        'Assets/GameFramework/Resources/Rendering/BlockParticle.shader',
        'Assets/GameFramework/Samples/Adventure/BlockParticleEffects.cs',
        'Assets/GameFramework/Samples/Adventure/BlockEffectCatalog.cs',
        'Assets/GameFramework/Samples/Adventure/AdventureVisualEffects.cs',
        'Assets/GameFramework/Samples/Adventure/EquipmentEffectDisplay.cs',
        'Assets/GameFramework/Editor/BlockEffectPreviewWindow.cs',
        'Assets/GameFramework/Resources/_Gen/Config/VisualEffectTable.bytes',
        'Assets/GameFramework/Resources/_Gen/Config/VisualEffectItemCategoryTable.bytes',
    }
    local seen={}
    for _,path in ipairs(paths) do
        local asset=assert(io.open(path,'rb'),'Missing effect asset: '..path);asset:close()
        local file=assert(io.open(path..'.meta','rb'),'Missing Unity metadata: '..path)
        local text=file:read('*a');file:close()
        text=text:gsub('\r\n','\n')
        local guid=text:match('\nguid: ([^\n]+)\n')
        assert(guid and #guid==32 and guid:match('^%x+$'),'Unity ignores assets with invalid GUIDs: '..path)
        assert(not seen[guid],'Duplicate effect asset GUID: '..path);seen[guid]=true
        local importer=path:match('%.shader$') and 'ShaderImporter:' or path:match('%.cs$') and 'MonoImporter:' or 'TextScriptImporter:'
        assert(text:find('\n'..importer..'\n',1,true),'Incorrect effect asset importer: '..path)
    end
end)

config:OnShutdown()
print('PASS visual_effect_catalog: '..passed..' groups')

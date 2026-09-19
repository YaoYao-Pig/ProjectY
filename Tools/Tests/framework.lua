package.path = 'Lua/?.lua;' .. package.path
local tests = 0
local function test(name, callback)
    local ok, err = xpcall(callback, debug.traceback)
    if not ok then error(name .. '\n' .. err) end
    tests = tests + 1; print('PASS ' .. name)
end
local function throws(callback, pattern)
    local ok, err = pcall(callback); assert(not ok, 'Expected failure')
    if pattern then assert(tostring(err):find(pattern), tostring(err)) end
end
local function read(name)
    local file = assert(io.open('Assets/GameFramework/Resources/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end
local Table = require('Config.ConfigTable')
test('generated binaries round trip Unicode, arrays, booleans, floats and formulas', function()
    local table = Table.Load(require('Generated.Rewards'), read('Rewards'))
    assert(table.Count == 2 and table:Get(1).tags[2] == '基础奖励')
    assert(table:Get(1).enabled == true)
    assert(table:Get(1).amount:Evaluate({base=10, level=2}) == 20)
    assert(table:Get(2).amount:Evaluate({base=25, level=10}) == 1000)
    assert(Table.Load(require('Generated.RewardGroups'), read('RewardGroups')):Get('starter').multiplier == 1.5)
    assert(table:Find(999) == nil); throws(function() table:Get(999) end, 'missing row')
    assert(#table:All() == 2)
end)
test('configuration records, arrays, tables and formulas are read-only', function()
    local table = Table.Load(require('Generated.Rewards'), read('Rewards'))
    throws(function() table:Get(1).base = 999 end, 'read%-only')
    throws(function() table:Get(1).tags[1] = 'changed' end)
    throws(function() table:Get(1).amount.Evaluate = function() end end)
    throws(function() table.Count = 0 end)
    local count = 0; for _ in pairs(table:Get(1)) do count = count + 1 end; assert(count == 8)
end)
test('reject malformed, truncated, trailing and mismatched binary data', function()
    local schema = require('Generated.Rewards'); local bytes = read('Rewards')
    for _, value in ipairs({ '', bytes:sub(1, -2), bytes .. 'extra', 'BAD!' .. bytes:sub(5), bytes:sub(1, 4) .. '\2' .. bytes:sub(6), bytes:sub(1,10) .. 'x' .. bytes:sub(12) }) do
        throws(function() Table.Load(schema, value) end)
    end
    throws(function() Table.Load(require('Generated.RewardGroups'), bytes) end, 'schema mismatch')
end)
test('formula runtime rejects missing variables and numerical faults', function()
    local formula = Table.Load(require('Generated.Rewards'), read('Rewards')):Get(1).amount
    throws(function() formula:Evaluate({base=1}) end, 'Missing')
    throws(function() formula:Evaluate({base=1,level=math.huge}) end)
end)
local Class = require('Core.Class'); local System = require('Core.LuaSystem'); local Registry = require('Core.SystemRegistry')
test('system dependency order, tick, pause and reverse teardown', function()
    local calls = {}; local services = {LogError=function(_, err) error(err) end}
    local function system(name)
        local cls = Class(name, System)
        function cls:OnInit(context) System.OnInit(self, context); calls[#calls+1] = 'init'..name end
        function cls:Tick(dt) calls[#calls+1] = 'tick'..name..dt end
        function cls:OnPause(value) calls[#calls+1] = 'pause'..tostring(value) end
        function cls:OnShutdown() calls[#calls+1] = 'stop'..name end
        return cls
    end
    local registry = Registry(services); registry:Register('B',system('B'),{'A'}); registry:Register('A',system('A'))
    registry:Start(); assert(calls[1] == 'initA' and calls[2] == 'initB')
    registry:Dispatch('Tick',1); assert(calls[3] == 'tickA1' and calls[4] == 'tickB1')
    registry:Dispatch('OnPause',true); assert(calls[5] == 'pausetrue')
    registry:Shutdown(); assert(calls[7] == 'stopB' and calls[8] == 'stopA'); registry:Shutdown(); assert(#calls == 8)
end)
test('missing/cyclic dependencies, duplicate registrations and startup rollback', function()
    local registry = Registry({LogError=function() end}); registry:Register('A',System,{'Missing'}); throws(function() registry:Start() end, 'Missing')
    registry = Registry({}); registry:Register('A',System,{'B'}); registry:Register('B',System,{'A'}); throws(function() registry:Start() end, 'Cyclic')
    throws(function() registry:Register('A',System) end, 'Duplicate')
    local stopped = false; local broken = Class('Broken',System)
    function broken:OnInit() error('init failure') end
    function broken:OnShutdown() stopped = true end
    registry = Registry({LogError=function() end}); registry:Register('Broken',broken); throws(function() registry:Start() end); assert(stopped)
end)
test('a faulting system is reported once while others keep ticking', function()
    local errors, ticks = 0, 0; local a = Class('Fault',System); local b = Class('Healthy',System)
    function a:Tick() error('fault') end; function b:Tick() ticks=ticks+1 end
    local registry=Registry({LogError=function() errors=errors+1 end}); registry:Register('A',a); registry:Register('B',b); registry:Start()
    registry:Dispatch('Tick',1); registry:Dispatch('Tick',1); assert(errors==1 and ticks==2); registry:Shutdown()
end)
test('signal supports unsubscribe/subscribe during notification without skipping listeners', function()
    local signal = require('Core.Signal')(); local calls={}; local offB
    signal:Subscribe(function() calls[#calls+1]='a'; offB(); signal:Subscribe(function() calls[#calls+1]='c' end) end)
    offB=signal:Subscribe(function() calls[#calls+1]='b' end)
    signal:Emit(); assert(table.concat(calls)=='a'); signal:Emit(); assert(table.concat(calls)=='aac')
    signal:Clear(); signal:Emit(); assert(#calls==3)
end)
test('widget ownership, cached visibility and Unity event listener release', function()
    local Widget = require('UI.UIWidgetCtrl'); local Signal=require('Core.Signal'); local signal=Signal()
    local event={listeners={}}; function event:AddListener(fn) self.listeners[fn]=true end; function event:RemoveListener(fn) self.listeners[fn]=nil end
    local widgetType=Class('Child',Widget); local shown=0
    function widgetType:Bind() self:Listen({onClick=event},function() end) end
    function widgetType:OnShow() self.visibleScope:Add(signal:Subscribe(function() shown=shown+1 end)) end
    local parent=Widget({log=error},{}); local child=parent:AddWidget(widgetType,{})
    parent:Show(); signal:Emit(); assert(shown==1); parent:Hide(); signal:Emit(); assert(shown==1)
    parent:Show(); signal:Emit(); assert(shown==2); parent:Dispose(); parent:Dispose()
    assert(child.disposed and next(event.listeners)==nil and #signal.listeners==0)
end)
test('UI modal stack, cached panels, Back and failed creation cleanup', function()
    local Panel=require('UI.UIPanelCtrl'); local UI=require('UI.UISystem'); local destroyed=0
    local definitions={ Home={ControllerModule='Test.Home',Layer='Main',Cache=true,CloseOnBack=false}, Popup={ControllerModule='Test.Home',Layer='Popup',Modal=true}, Broken={ControllerModule='Test.Broken',Layer='Popup'} }
    package.preload['Test.Home']=function() return Class('Home',Panel) end
    package.preload['Test.Broken']=function() local c=Class('Broken',Panel); function c:Bind() error('binding failed') end; return c end
    local host={SceneVersion=0}; function host:CreateView() return {} end; function host:SetVisible(view,v) view.visible=v end
    function host:GetConfig(name) return assert(definitions[name]) end; function host:GetPanel(view) return view end
    function host:SetOrder(view,order) view.order=order end; function host:SetInteractable(view,v) view.interactable=v end
    function host:DestroyView() destroyed=destroyed+1 end
    local ui=UI(); local context={services={UI=host},log=error,systems={Get=function() return ui end}}
    ui:OnInit(context); local home=ui:Open('Home'); ui:Open('Popup'); assert(not home.reference.interactable)
    assert(ui:Back()); assert(home.reference.interactable and destroyed==1); assert(not ui:Back())
    ui:Close('Home'); assert(not home.visible); assert(ui:Open('Home')==home)
    throws(function() ui:Open('Broken') end); assert(destroyed==2)
    ui:OnShutdown(); assert(destroyed==3 and home.disposed)
end)

test('view proxy caches components, rejects rebinding and reports missing keys', function()
    local calls=0; local button={}
    local view=require('UI.UIView').Create({Get=function(_, key) calls=calls+1; assert(key=='Confirm', 'missing key'); return button end})
    assert(view.Confirm == button and view.Confirm == button and calls == 1)
    throws(function() view.Confirm = {} end, 'read%-only')
    throws(function() return view.Missing end, 'missing key')
end)

test('scene change destroys opted-in cached panels and preserves persistent panels', function()
    local UI=require('UI.UISystem'); local Panel=require('UI.UIPanelCtrl'); local destroyed=0
    package.preload['Test.ScenePanel']=function() return Class('ScenePanel', Panel) end
    local defs={Keep={Layer='Main',ControllerModule='Test.ScenePanel',Cache=true}, Close={Layer='Main',ControllerModule='Test.ScenePanel',Cache=true,CloseOnSceneChange=true}}
    local host={SceneVersion=0}
    function host:GetConfig(name) return defs[name] end
    function host:CreateView() return {} end
    function host:GetPanel(view) return view end
    function host:SetVisible() end; function host:SetOrder() end; function host:SetInteractable() end
    function host:DestroyView() destroyed=destroyed+1 end
    local ui=UI(); ui:OnInit({services={UI=host},log=error})
    local keep=ui:Open('Keep'); local close=ui:Open('Close'); ui:Close('Close')
    host.SceneVersion=1; ui:Tick(0,0.016)
    assert(close.disposed and ui.panels.Close==nil and destroyed==1)
    assert(ui.panels.Keep.ctrl==keep and keep.visible)
    ui:OnShutdown(); assert(destroyed==2)
end)

test('generated widget ownership cleans up failed Bind and hidden cached parents', function()
    local Widget=require('UI.UIWidgetCtrl'); local destroyed=0
    package.preload['UI.Widget.Fixture']=function() return Class('Fixture', Widget) end
    package.preload['UI.Widget.BadFixture']=function() local c=Class('BadFixture', Widget); function c:Bind() error('bad bind') end; return c end
    local host={}
    function host:CreateWidget() return {} end
    function host:SetWidgetVisible(view,visible) view.active=visible end
    function host:DestroyWidget() destroyed=destroyed+1 end
    local parent=Widget({services={UI=host},log=error},{transform={}})
    local child=parent:CreateWidget('Fixture'); assert(not child.visible)
    parent:Show(); assert(child.reference.active); parent:Hide(); assert(not child.reference.active)
    throws(function() parent:CreateWidget('BadFixture') end, 'bad bind'); assert(destroyed==1 and #parent.widgets==1)
    parent:Dispose(); parent:Dispose(); assert(destroyed==2 and child.disposed)
end)
test('Language prioritizes exported rows, supports empty overrides and falls back before export', function()
    local proxy = require('Config.LanguageProxy')
    local language = require('Language')
    proxy.Bind(nil)
    assert(language.Confirm == '确认' and language.Unknown == nil)
    local overrides = { Confirm = 'Changed', Cancel = '' }
    proxy.Bind(function(id) return overrides[id] end)
    assert(language.Confirm == 'Changed' and language.Cancel == '')
    assert(language.RewardReceived == '已获得奖励')
    throws(function() language.Confirm = 'wrong' end, 'read%-only')
    proxy.Bind(nil); assert(language.Confirm == '确认')
end)
test('text schemas and module catalogs preserve types and immutable constants', function()
    local texts = Table.Load(require('Generated.LuaTxt'), read('LuaTxt'))
    assert(texts:Get('Confirm').desc == '通用确认按钮')
    local Config = require('Config.ConfigSystem'); local config = Config()
    config:OnInit({services={ReadConfig=function(_, name) return read(name) end}})
    assert(config:HasTable('LuaTxt') and not config:HasTable('Missing'))
    assert(config:GetEnum('Demo', 'Rarity').Rare == 1)
    assert(config:GetConstant('Demo', 'DefaultRarity') == 0)
    throws(function() config:GetEnum('Demo', 'Rarity').Rare = 20 end, 'read%-only')
    throws(function() config:GetConstant('Demo', 'Missing') end, 'Unknown constant')
end)
test('numeric enum fields decode as int32 and keep subsequent fields aligned', function()
    local schema = {name='EnumFixture',key='id',fingerprint='fixture',fields={
        {name='id',type='int'}, {name='rarity',type='enum',enumType='int'}, {name='label',type='text'}
    }}
    local bytes = 'YCFG' .. string.pack('<I2s4I4i4i4s4', 1, 'fixture', 1, 42, 7, '测试')
    local row = Table.Load(schema, bytes):Get(42)
    assert(row.rarity == 7 and row.label == '测试')
end)
print(string.format('All %d Lua tests passed (%s, native xLua plugin).', tests, _VERSION))

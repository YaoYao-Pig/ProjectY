local LuaLanguage = require('Language')
local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Random = require('Game.Map.SeededRandom')
local Loading = Class('LoadingSystem', System)

function Loading:OnInit(context)
    System.OnInit(self, context)
    self.ui = context.systems:Get('UI')
    self.config = context.systems:Get('Config')
    self.sequence = 0
    self.random = Random(os.time() % 4294967296)
end

-- Token ownership prevents an old operation from closing a later loading screen.
function Loading:Begin(title, font)
    assert(not self.active, 'A loading operation is already active')
    assert(type(title) == 'string' and title ~= '', 'Loading requires a title')
    local tips = {}
    for _, row in ipairs(self.config:GetTable('LoadingTipTable'):All()) do
        if row.enabled then
            assert(row.content ~= '' and row.duration > 0, 'Invalid loading tip: ' .. row.id)
            tips[#tips + 1] = row
        end
    end
    assert(#tips > 0, 'LoadingTipTable needs at least one enabled tip')
    self.sequence = self.sequence + 1
    local state = { token = self.sequence, title = title, font = assert(font), progress = 0,
        stage = LuaLanguage.UILoadingSystemStage, tips = tips, random = self.random }
    self.active = state
    local ok, err = pcall(self.ui.Open, self.ui, 'Loading', state)
    if not ok then self.active = nil; error(err, 0) end
    return state.token
end

function Loading:Report(token, progress, stage)
    local state = assert(self.active, 'No active loading operation')
    assert(state.token == token, 'Stale loading token')
    assert(type(progress) == 'number' and progress >= state.progress and progress <= 1,
        'Loading progress must be monotonic in 0..1')
    assert(type(stage) == 'string' and stage ~= '', 'Loading requires a stage label')
    state.progress, state.stage = progress, stage
end

function Loading:Finish(token)
    assert(self.active and self.active.token == token, 'Stale loading token')
    self.ui:Close('Loading')
    self.active = nil
end

function Loading:OnShutdown()
    if self.active then self:Finish(self.active.token) end
end
return Loading

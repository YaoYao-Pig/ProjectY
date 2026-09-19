local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Proxy = require('Config.LanguageProxy')
local Localization = Class('LocalizationSystem', System)
function Localization:OnInit(context)
    System.OnInit(self, context)
    self.service = context.services.Localization
    self.service:Clear()
    local config = context.systems:Get('Config')
    for _, name in ipairs({ 'LuaTxt', 'PrefabTxt' }) do
        if config:HasTable(name) then
            for _, row in ipairs(config:GetTable(name):All()) do
                self.service:SetText(name, row.id, row.txt)
            end
        end
    end
    Proxy.Bind(function(id) return self.service:Find('LuaTxt', id) end)
    self.service:NotifyChanged()
end
function Localization:OnShutdown()
    Proxy.Bind(nil)
    if self.service then self.service:Clear(); self.service = nil end
end
return Localization

-- Catalog-only GM queries; equipment generation and bag capacity remain in EquipmentSystem.
local LuaLanguage=require('Language')
local Commands={};Commands.__index=Commands
local function supported(item)return item and (item.kind=='weapon' or item.kind=='wearable')end
function Commands.New(adventure)
    return setmetatable({adventure=adventure,equipment=adventure.equipment},Commands)
end
function Commands:Search(query)
    query=(query or ''):match('^%s*(.-)%s*$'):lower()
    local rows={}
    for _,item in ipairs(self.equipment.rules.items:All())do
        if supported(item) and (query=='' or tostring(item.id):find(query,1,true) or item.name:lower():find(query,1,true)) then
            rows[#rows+1]={id=item.id,name=item.name,kind=item.kind,width=item.width,height=item.height}
        end
    end
    table.sort(rows,function(a,b)return a.id<b.id end)
    return rows
end
function Commands:Grant(id)
    if type(id)~='number' or id%1~=0 or id<1 then return false,LuaLanguage.GMEquipmentInvalid end
    local item=self.equipment.rules.items:Find(id)
    if not supported(item) then return false,LuaLanguage.GMEquipmentInvalid end
    if not self.adventure.map then return false,LuaLanguage.GMEquipmentRequiresWorld end
    local ok,reason=self.equipment:Grant(id,1)
    if not ok then return false,reason end
    return true,string.format(LuaLanguage.GMEquipmentGranted,item.name)
end
return Commands

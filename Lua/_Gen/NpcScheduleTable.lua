-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class NpcScheduleTableRow
---@field id number 稳定配置 ID
---@field npcId number NPC 身份
---@field startMinute number 起始分钟，含端点
---@field endMinute number 结束分钟，不含端点
---@field facilityId number 此时段的目的设施
---@field activity string 日程说明
return {["name"]="NpcScheduleTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="npcId",["type"]="int",["description"]="NPC \232\186\171\228\187\189",["ref"]="NpcTable"},{["name"]="startMinute",["type"]="int",["description"]="\232\181\183\229\167\139\229\136\134\233\146\159\239\188\140\229\144\171\231\171\175\231\130\185",["min"]=0,["max"]=1439},{["name"]="endMinute",["type"]="int",["description"]="\231\187\147\230\157\159\229\136\134\233\146\159\239\188\140\228\184\141\229\144\171\231\171\175\231\130\185",["min"]=1,["max"]=1440},{["name"]="facilityId",["type"]="int",["description"]="\230\173\164\230\151\182\230\174\181\231\154\132\231\155\174\231\154\132\232\174\190\230\150\189",["ref"]="MapAreaTownFacilityTable"},{["name"]="activity",["type"]="text",["description"]="\230\151\165\231\168\139\232\175\180\230\152\142"}},["fingerprint"]="a8e203d2dad26098f82233919cda63d0d9e0312141063210d97a4f2d5fc0ade8"}

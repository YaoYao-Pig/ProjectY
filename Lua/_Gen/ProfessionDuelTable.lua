-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class ProfessionDuelTableRow
---@field id number 规则 ID
---@field facilityKind "guild" 允许发起的设施
---@field encounterId number 实际单挑遭遇
---@field minimumHealthPercent number 认输生命百分比
---@field rewardCoins number 胜利奖励
---@field lossCoins number 失败代价
---@field description string 单挑的明确规则
return {["name"]="ProfessionDuelTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\232\167\132\229\136\153 ID"},{["name"]="facilityKind",["type"]="enum",["description"]="\229\133\129\232\174\184\229\143\145\232\181\183\231\154\132\232\174\190\230\150\189",["values"]={"guild"}},{["name"]="encounterId",["type"]="int",["description"]="\229\174\158\233\153\133\229\141\149\230\140\145\233\129\173\233\129\135",["ref"]="CombatEncounterTable"},{["name"]="minimumHealthPercent",["type"]="int",["description"]="\232\174\164\232\190\147\231\148\159\229\145\189\231\153\190\229\136\134\230\175\148",["min"]=1,["max"]=99},{["name"]="rewardCoins",["type"]="int",["description"]="\232\131\156\229\136\169\229\165\150\229\138\177",["min"]=0},{["name"]="lossCoins",["type"]="int",["description"]="\229\164\177\232\180\165\228\187\163\228\187\183",["min"]=0},{["name"]="description",["type"]="text",["description"]="\229\141\149\230\140\145\231\154\132\230\152\142\231\161\174\232\167\132\229\136\153"}},["fingerprint"]="43b27f69f3ff599a347b4b30783565be3d19a81f2c7e902b31b07dd3e8e77c8f"}

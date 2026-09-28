-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class MapAreaForestSpawnTableRow
---@field id number 稳定配置 ID
---@field areaId number 森林地图
---@field encounterId number 遭遇模板
---@field chance number 本类刷新百分比
---@field minCount number 最少组数
---@field maxCount number 最多组数
---@field neutralChance number 中立百分比，仅动物可为中立
return {["name"]="MapAreaForestSpawnTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="areaId",["type"]="int",["description"]="\230\163\174\230\158\151\229\156\176\229\155\190",["ref"]="MapAreaTable"},{["name"]="encounterId",["type"]="int",["description"]="\233\129\173\233\129\135\230\168\161\230\157\191",["ref"]="CombatEncounterTable"},{["name"]="chance",["type"]="int",["description"]="\230\156\172\231\177\187\229\136\183\230\150\176\231\153\190\229\136\134\230\175\148",["min"]=0,["max"]=100},{["name"]="minCount",["type"]="int",["description"]="\230\156\128\229\176\145\231\187\132\230\149\176",["min"]=0},{["name"]="maxCount",["type"]="int",["description"]="\230\156\128\229\164\154\231\187\132\230\149\176",["min"]=0},{["name"]="neutralChance",["type"]="int",["description"]="\228\184\173\231\171\139\231\153\190\229\136\134\230\175\148\239\188\140\228\187\133\229\138\168\231\137\169\229\143\175\228\184\186\228\184\173\231\171\139",["min"]=0,["max"]=100}},["fingerprint"]="1a3625fc12727594efe7595be8bff71cf65b926da6f82b6dd89ad3f0f03c320f"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class MoraleStageTableRow
---@field id number 阶段 ID，1 至 5
---@field stage number 阶段，逃跑 -3 至自信 1
---@field name string 士气阶段名称
---@field minimumPercent number 本阶段起始百分比，逃跑必须为 0
---@field hitScale number 命中率倍率
---@field defenseScale number 防御属性倍率
---@field checkBonus number 勇气检定的成功率加算
return {["name"]="MoraleStageTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["min"]=1,["max"]=5,["description"]="\233\152\182\230\174\181 ID\239\188\1401 \232\135\179 5"},{["name"]="stage",["type"]="int",["min"]=-3,["max"]=1,["description"]="\233\152\182\230\174\181\239\188\140\233\128\131\232\183\145 -3 \232\135\179\232\135\170\228\191\161 1"},{["name"]="name",["type"]="text",["description"]="\229\163\171\230\176\148\233\152\182\230\174\181\229\144\141\231\167\176"},{["name"]="minimumPercent",["type"]="int",["min"]=0,["max"]=100,["description"]="\230\156\172\233\152\182\230\174\181\232\181\183\229\167\139\231\153\190\229\136\134\230\175\148\239\188\140\233\128\131\232\183\145\229\191\133\233\161\187\228\184\186 0"},{["name"]="hitScale",["type"]="float",["min"]=0,["max"]=3,["description"]="\229\145\189\228\184\173\231\142\135\229\128\141\231\142\135"},{["name"]="defenseScale",["type"]="float",["min"]=0,["max"]=3,["description"]="\233\152\178\229\190\161\229\177\158\230\128\167\229\128\141\231\142\135"},{["name"]="checkBonus",["type"]="int",["description"]="\229\139\135\230\176\148\230\163\128\229\174\154\231\154\132\230\136\144\229\138\159\231\142\135\229\138\160\231\174\151"}},["fingerprint"]="debec9a29e849468dcdc71b09b78b79f683e68a8b9f36a2623102e6c37c36210"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class GrowthProfileTableRow
---@field id number 稳定配置 ID
---@field unitId number 角色模板
---@field treeIds number[] 初始开放树
---@field traitIds number[] 初始特质
---@field potential number 等待事件释放的额外天赋点
return {["name"]="GrowthProfileTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="unitId",["type"]="int",["description"]="\232\167\146\232\137\178\230\168\161\230\157\191",["ref"]="CombatUnitTable"},{["name"]="treeIds",["type"]="int[]",["description"]="\229\136\157\229\167\139\229\188\128\230\148\190\230\160\145",["ref"]="TalentTreeTable"},{["name"]="traitIds",["type"]="int[]",["description"]="\229\136\157\229\167\139\231\137\185\232\180\168",["ref"]="CombatTraitTable"},{["name"]="potential",["type"]="int",["description"]="\231\173\137\229\190\133\228\186\139\228\187\182\233\135\138\230\148\190\231\154\132\233\162\157\229\164\150\229\164\169\232\181\139\231\130\185",["min"]=0}},["fingerprint"]="a8010ca3b6252a5da9024151272c4a22004ad98351013845811b548e4f50c313"}

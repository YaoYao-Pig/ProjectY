-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentDeedTableRow
---@field id number 事迹规则身份
---@field kind string legendary_kill / mission / legendary_resolution
---@field name string 事迹名称
---@field description string 获得条件
---@field targetIds number[] 传奇为CombatUnit身份，任务为Mission身份
---@field sourceTargetIds number[] 任务与targetIds一一对应的传奇目标，其余为空
return {["name"]="EquipmentDeedTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\228\186\139\232\191\185\232\167\132\229\136\153\232\186\171\228\187\189",["min"]=1},{["name"]="kind",["type"]="string",["description"]="legendary_kill / mission / legendary_resolution"},{["name"]="name",["type"]="text",["description"]="\228\186\139\232\191\185\229\144\141\231\167\176"},{["name"]="description",["type"]="text",["description"]="\232\142\183\229\190\151\230\157\161\228\187\182"},{["name"]="targetIds",["type"]="int[]",["description"]="\228\188\160\229\165\135\228\184\186CombatUnit\232\186\171\228\187\189\239\188\140\228\187\187\229\138\161\228\184\186Mission\232\186\171\228\187\189"},{["name"]="sourceTargetIds",["type"]="int[]",["description"]="\228\187\187\229\138\161\228\184\142targetIds\228\184\128\228\184\128\229\175\185\229\186\148\231\154\132\228\188\160\229\165\135\231\155\174\230\160\135\239\188\140\229\133\182\228\189\153\228\184\186\231\169\186"}},["fingerprint"]="96482f66c0f79685d74b2311983b5d4bb84a4e6d89d071c3337643c5740f6c4c"}

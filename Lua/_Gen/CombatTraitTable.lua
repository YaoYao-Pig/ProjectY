-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class CombatTraitTableRow
---@field id number 稳定配置 ID
---@field name string 特质名称
---@field description string 特质说明
---@field attribute string 修正的属性名
---@field amount number 加算属性修正
---@field rarity "common"|"legendary" 特质稀有度
---@field onHitEffectIds number[] 伤害攻击命中后按顺序执行的效果；敌我共用，不附加到防御或治疗
return {["name"]="CombatTraitTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\231\137\185\232\180\168\229\144\141\231\167\176"},{["name"]="description",["type"]="text",["description"]="\231\137\185\232\180\168\232\175\180\230\152\142"},{["name"]="attribute",["type"]="string",["description"]="\228\191\174\230\173\163\231\154\132\229\177\158\230\128\167\229\144\141"},{["name"]="amount",["type"]="int",["description"]="\229\138\160\231\174\151\229\177\158\230\128\167\228\191\174\230\173\163",["min"]=-100,["max"]=100},{["name"]="rarity",["type"]="enum",["values"]={"common","legendary"},["description"]="\231\137\185\232\180\168\231\168\128\230\156\137\229\186\166",["default"]="common"},{["name"]="onHitEffectIds",["type"]="int[]",["description"]="\228\188\164\229\174\179\230\148\187\229\135\187\229\145\189\228\184\173\229\144\142\230\140\137\233\161\186\229\186\143\230\137\167\232\161\140\231\154\132\230\149\136\230\158\156\239\188\155\230\149\140\230\136\145\229\133\177\231\148\168\239\188\140\228\184\141\233\153\132\229\138\160\229\136\176\233\152\178\229\190\161\230\136\150\230\178\187\231\150\151",["ref"]="CombatEffectTable",["default"]={}}},["fingerprint"]="fd193cd0ed6a34e559a5d951f8c9a26fb88dc458d01e33b9fc13f20181cc6020"}

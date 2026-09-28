-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class CombatEffectTableRow
---@field id number 稳定配置 ID
---@field kind "damage"|"heal"|"guard"|"reload"|"tame"|"relocate" 效果处理器
---@field amount ConfigFormula 效果数值；defense/guard 来自目标，其余来自施法者
return {["name"]="CombatEffectTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="kind",["type"]="enum",["description"]="\230\149\136\230\158\156\229\164\132\231\144\134\229\153\168",["values"]={"damage","heal","guard","reload","tame","relocate"}},{["name"]="amount",["type"]="formula",["description"]="\230\149\136\230\158\156\230\149\176\229\128\188\239\188\155defense/guard \230\157\165\232\135\170\231\155\174\230\160\135\239\188\140\229\133\182\228\189\153\230\157\165\232\135\170\230\150\189\230\179\149\232\128\133",["variables"]={"vitality","endurance","intellect","strength","speed","defense","proficiency","guard","distance"}}},["fingerprint"]="1f9819e818be1dd274153f3bf14dc6fc6864e0a02b562e91ce51152cd17ad05b"}

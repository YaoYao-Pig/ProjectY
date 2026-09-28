-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class TalentTreeTableRow
---@field id number 稳定配置 ID
---@field name string 树名称
---@field description string 树介绍
---@field unlockRule "adjacent_any"|"prerequisite_all" adjacent_any：任意已学邻居；prerequisite_all：全部有向前置
---@field rootIds number[] 允许直接投入的起点
return {["name"]="TalentTreeTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\230\160\145\229\144\141\231\167\176"},{["name"]="description",["type"]="text",["description"]="\230\160\145\228\187\139\231\187\141"},{["name"]="unlockRule",["type"]="enum",["description"]="adjacent_any\239\188\154\228\187\187\230\132\143\229\183\178\229\173\166\233\130\187\229\177\133\239\188\155prerequisite_all\239\188\154\229\133\168\233\131\168\230\156\137\229\144\145\229\137\141\231\189\174",["values"]={"adjacent_any","prerequisite_all"}},{["name"]="rootIds",["type"]="int[]",["description"]="\229\133\129\232\174\184\231\155\180\230\142\165\230\138\149\229\133\165\231\154\132\232\181\183\231\130\185",["ref"]="TalentNodeTable"}},["fingerprint"]="17f24c0f83fa3a07707e67f28c79001b56cab0e0b14685a9510bfdd6fbe572e9"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class MapAreaTownNpcTableRow
---@field id number 稳定配置 ID
---@field name string 显示名称
---@field description string 居民身份说明
---@field partIds number[] 棋子部件
---@field stepSeconds number 巡游每格间隔
---@field idleSeconds number 抵达巡游节点的停留时间
return {["name"]="MapAreaTownNpcTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="string",["description"]="\230\152\190\231\164\186\229\144\141\231\167\176"},{["name"]="description",["type"]="text",["description"]="\229\177\133\230\176\145\232\186\171\228\187\189\232\175\180\230\152\142"},{["name"]="partIds",["type"]="int[]",["description"]="\230\163\139\229\173\144\233\131\168\228\187\182",["ref"]="PawnPartTable"},{["name"]="stepSeconds",["type"]="float",["description"]="\229\183\161\230\184\184\230\175\143\230\160\188\233\151\180\233\154\148",["min"]=0.3,["max"]=3},{["name"]="idleSeconds",["type"]="float",["description"]="\230\138\181\232\190\190\229\183\161\230\184\184\232\138\130\231\130\185\231\154\132\229\129\156\231\149\153\230\151\182\233\151\180",["min"]=0,["max"]=20}},["fingerprint"]="f72ace6a7ce28b73317327f315821108a8a0074a6824c4cd8310f2fdeee74018"}

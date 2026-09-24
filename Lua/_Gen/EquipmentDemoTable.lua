-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentDemoTableRow
---@field id number 稳定配置 ID
---@field starterItemIds number[] 初始共享背包
---@field starterCounts number[] 对应数量
---@field areaId number 放置搜刮点的局部地图
---@field lootTableIds number[] 搜刮点配置
---@field lootDistances number[] 相对入口的目标寻路距离
---@field interactionRadius number 可搜刮距离
return {["name"]="EquipmentDemoTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="starterItemIds",["type"]="int[]",["description"]="\229\136\157\229\167\139\229\133\177\228\186\171\232\131\140\229\140\133",["ref"]="EquipmentItemTable"},{["name"]="starterCounts",["type"]="int[]",["description"]="\229\175\185\229\186\148\230\149\176\233\135\143"},{["name"]="areaId",["type"]="int",["description"]="\230\148\190\231\189\174\230\144\156\229\136\174\231\130\185\231\154\132\229\177\128\233\131\168\229\156\176\229\155\190",["ref"]="MapAreaTable"},{["name"]="lootTableIds",["type"]="int[]",["description"]="\230\144\156\229\136\174\231\130\185\233\133\141\231\189\174",["ref"]="EquipmentLootTable"},{["name"]="lootDistances",["type"]="int[]",["description"]="\231\155\184\229\175\185\229\133\165\229\143\163\231\154\132\231\155\174\230\160\135\229\175\187\232\183\175\232\183\157\231\166\187"},{["name"]="interactionRadius",["type"]="int",["description"]="\229\143\175\230\144\156\229\136\174\232\183\157\231\166\187",["min"]=1,["max"]=3}},["fingerprint"]="0a742d5b25c4d7b5d2fea4373a02d768481bdae9704f15340a8dd96091aa3ebb"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class LootEntryTableRow
---@field id number 稳定配置 ID
---@field poolId number 所属掉落池
---@field itemId number 物品
---@field chance number 独立命中概率（百分比）
---@field minCount number 最小数量
---@field maxCount number 最大数量
---@field weight number weighted 池中的相对权重；0 不参与抽取
return {["name"]="LootEntryTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="poolId",["type"]="int",["description"]="\230\137\128\229\177\158\230\142\137\232\144\189\230\177\160",["ref"]="LootPoolTable"},{["name"]="itemId",["type"]="int",["description"]="\231\137\169\229\147\129",["ref"]="EquipmentItemTable"},{["name"]="chance",["type"]="float",["description"]="\231\139\172\231\171\139\229\145\189\228\184\173\230\166\130\231\142\135\239\188\136\231\153\190\229\136\134\230\175\148\239\188\137",["min"]=0,["max"]=100},{["name"]="minCount",["type"]="int",["description"]="\230\156\128\229\176\143\230\149\176\233\135\143",["min"]=1},{["name"]="maxCount",["type"]="int",["description"]="\230\156\128\229\164\167\230\149\176\233\135\143",["min"]=1},{["name"]="weight",["type"]="int",["description"]="weighted \230\177\160\228\184\173\231\154\132\231\155\184\229\175\185\230\157\131\233\135\141\239\188\1550 \228\184\141\229\143\130\228\184\142\230\138\189\229\143\150",["default"]=1,["min"]=0}},["fingerprint"]="588f76e7a4be3a962a90b789b80d99e5c68778d82aa8cec6fa745f15988b2da1"}

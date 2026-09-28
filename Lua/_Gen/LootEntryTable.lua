-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class LootEntryTableRow
---@field id number 稳定配置 ID
---@field poolId number 所属掉落池
---@field itemId number 物品
---@field chance number 独立命中概率（百分比）
---@field minCount number 最小数量
---@field maxCount number 最大数量
return {["name"]="LootEntryTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="poolId",["type"]="int",["description"]="\230\137\128\229\177\158\230\142\137\232\144\189\230\177\160",["ref"]="LootPoolTable"},{["name"]="itemId",["type"]="int",["description"]="\231\137\169\229\147\129",["ref"]="EquipmentItemTable"},{["name"]="chance",["type"]="float",["description"]="\231\139\172\231\171\139\229\145\189\228\184\173\230\166\130\231\142\135\239\188\136\231\153\190\229\136\134\230\175\148\239\188\137",["min"]=0,["max"]=100},{["name"]="minCount",["type"]="int",["description"]="\230\156\128\229\176\143\230\149\176\233\135\143",["min"]=1},{["name"]="maxCount",["type"]="int",["description"]="\230\156\128\229\164\167\230\149\176\233\135\143",["min"]=1}},["fingerprint"]="0d11d50e11d3c9ccd22ab476b5461c6968a81387840725f4010ce82b427e7c80"}

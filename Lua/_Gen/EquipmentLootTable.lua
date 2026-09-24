-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentLootTableRow
---@field id number 稳定配置 ID
---@field name string 显示名称
---@field kind "chest"|"ground" 展示形态
---@field assetId number 未搜刮模型
---@field openedAssetId number 宝箱开启后的模型；地面物品领取后隐藏
---@field itemIds number[] 掉落物品
---@field counts number[] 对应数量，必须为正
return {["name"]="EquipmentLootTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\230\152\190\231\164\186\229\144\141\231\167\176"},{["name"]="kind",["type"]="enum",["description"]="\229\177\149\231\164\186\229\189\162\230\128\129",["values"]={"chest","ground"}},{["name"]="assetId",["type"]="int",["description"]="\230\156\170\230\144\156\229\136\174\230\168\161\229\158\139",["ref"]="EquipmentAssetTable"},{["name"]="openedAssetId",["type"]="int",["description"]="\229\174\157\231\174\177\229\188\128\229\144\175\229\144\142\231\154\132\230\168\161\229\158\139\239\188\155\229\156\176\233\157\162\231\137\169\229\147\129\233\162\134\229\143\150\229\144\142\233\154\144\232\151\143",["ref"]="EquipmentAssetTable"},{["name"]="itemIds",["type"]="int[]",["description"]="\230\142\137\232\144\189\231\137\169\229\147\129",["ref"]="EquipmentItemTable"},{["name"]="counts",["type"]="int[]",["description"]="\229\175\185\229\186\148\230\149\176\233\135\143\239\188\140\229\191\133\233\161\187\228\184\186\230\173\163"}},["fingerprint"]="ed00488460487fe604f526d7afb7cd749fbc9afc5b39525301a002121e0d28ca"}

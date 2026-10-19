-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class CampUpgradeTableRow
---@field id number 升级配置ID
---@field facilityId number 设施
---@field level number 目标等级
---@field coins number 金币费用
---@field itemIds number[] 材料物品
---@field itemCounts number[] 对应材料数量
---@field storageCapacity number 升级后仓库总件数容量；生产设施为零
return {["name"]="CampUpgradeTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\229\141\135\231\186\167\233\133\141\231\189\174ID",["min"]=1},{["name"]="facilityId",["type"]="int",["description"]="\232\174\190\230\150\189",["ref"]="CampFacilityTable"},{["name"]="level",["type"]="int",["description"]="\231\155\174\230\160\135\231\173\137\231\186\167",["min"]=1},{["name"]="coins",["type"]="int",["description"]="\233\135\145\229\184\129\232\180\185\231\148\168",["min"]=0},{["name"]="itemIds",["type"]="int[]",["description"]="\230\157\144\230\150\153\231\137\169\229\147\129",["ref"]="EquipmentItemTable"},{["name"]="itemCounts",["type"]="int[]",["description"]="\229\175\185\229\186\148\230\157\144\230\150\153\230\149\176\233\135\143"},{["name"]="storageCapacity",["type"]="int",["description"]="\229\141\135\231\186\167\229\144\142\228\187\147\229\186\147\230\128\187\228\187\182\230\149\176\229\174\185\233\135\143\239\188\155\231\148\159\228\186\167\232\174\190\230\150\189\228\184\186\233\155\182",["min"]=0}},["fingerprint"]="5cecc29569f2a21af19c8f05f4346df5d2b809b66bb6aca3358bbd6cc652f716"}

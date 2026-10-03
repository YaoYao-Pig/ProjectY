-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class ShopEntryTableRow
---@field id number 稳定配置 ID
---@field templateId number 商品模板
---@field itemId number 出售物品
---@field chance number 独立上架概率，百分比，0 为从不出现，100 为必定出现
---@field minCount number 命中后最小库存
---@field maxCount number 命中后最大库存
---@field price number 每件售价，金币
return {["name"]="ShopEntryTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="templateId",["type"]="int",["description"]="\229\149\134\229\147\129\230\168\161\230\157\191",["ref"]="ShopTemplateTable"},{["name"]="itemId",["type"]="int",["description"]="\229\135\186\229\148\174\231\137\169\229\147\129",["ref"]="EquipmentItemTable"},{["name"]="chance",["type"]="float",["description"]="\231\139\172\231\171\139\228\184\138\230\158\182\230\166\130\231\142\135\239\188\140\231\153\190\229\136\134\230\175\148\239\188\1400 \228\184\186\228\187\142\228\184\141\229\135\186\231\142\176\239\188\140100 \228\184\186\229\191\133\229\174\154\229\135\186\231\142\176",["min"]=0,["max"]=100},{["name"]="minCount",["type"]="int",["description"]="\229\145\189\228\184\173\229\144\142\230\156\128\229\176\143\229\186\147\229\173\152",["min"]=1,["max"]=10000},{["name"]="maxCount",["type"]="int",["description"]="\229\145\189\228\184\173\229\144\142\230\156\128\229\164\167\229\186\147\229\173\152",["min"]=1,["max"]=10000},{["name"]="price",["type"]="int",["description"]="\230\175\143\228\187\182\229\148\174\228\187\183\239\188\140\233\135\145\229\184\129",["min"]=0,["max"]=1000000}},["fingerprint"]="c52fde9d69e6bd5e9072f5531dc0be7aa63312fa84fa1c7fa2c58c35fb681749"}

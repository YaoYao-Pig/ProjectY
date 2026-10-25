-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class MapAreaNaturalEntranceTableRow
---@field id number 配置ID
---@field regionType 1|2|3|4|5|6|7|8|9|10|11|12|13 目标地貌
---@field kind string 生成器入口标记
---@field areaId number 探索小地图
---@field itemId number 首次进入所需物品，0表示免费
---@field itemCount number 首次进入消耗数量
return {["name"]="MapAreaNaturalEntranceTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\233\133\141\231\189\174ID",["min"]=1},{["name"]="regionType",["type"]="enum",["description"]="\231\155\174\230\160\135\229\156\176\232\178\140",["enumRef"]="Map.E_MapRegion",["enumType"]="int",["values"]={1,2,3,4,5,6,7,8,9,10,11,12,13}},{["name"]="kind",["type"]="string",["description"]="\231\148\159\230\136\144\229\153\168\229\133\165\229\143\163\230\160\135\232\174\176"},{["name"]="areaId",["type"]="int",["description"]="\230\142\162\231\180\162\229\176\143\229\156\176\229\155\190",["ref"]="MapAreaTable"},{["name"]="itemId",["type"]="int",["description"]="\233\166\150\230\172\161\232\191\155\229\133\165\230\137\128\233\156\128\231\137\169\229\147\129\239\188\1400\232\161\168\231\164\186\229\133\141\232\180\185"},{["name"]="itemCount",["type"]="int",["description"]="\233\166\150\230\172\161\232\191\155\229\133\165\230\182\136\232\128\151\230\149\176\233\135\143",["min"]=0}},["fingerprint"]="50849e971046e45e55adc243fbf0a65328f4d9291c4f1db0709bef5a31e0f004"}

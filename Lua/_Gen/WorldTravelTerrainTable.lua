-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class WorldTravelTerrainTableRow
---@field id number 稳定ID
---@field regionType 1|2|3|4|5|6 地域类型
---@field name string 地形显示名
---@field costMultiplier number 该地域通行耗时倍率
---@field battleObstacleChance number 随机遭遇战场障碍率
---@field battleSurfaceId number 随机战场地面材质
---@field battlePropIds number[] 障碍物模型池；空时使用战场岩壁
return {["name"]="WorldTravelTerrainTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154ID"},{["name"]="regionType",["type"]="enum",["description"]="\229\156\176\229\159\159\231\177\187\229\158\139",["enumRef"]="Map.E_MapRegion",["enumType"]="int",["values"]={1,2,3,4,5,6}},{["name"]="name",["type"]="text",["description"]="\229\156\176\229\189\162\230\152\190\231\164\186\229\144\141"},{["name"]="costMultiplier",["type"]="float",["description"]="\232\175\165\229\156\176\229\159\159\233\128\154\232\161\140\232\128\151\230\151\182\229\128\141\231\142\135",["min"]=0.1},{["name"]="battleObstacleChance",["type"]="float",["description"]="\233\154\143\230\156\186\233\129\173\233\129\135\230\136\152\229\156\186\233\154\156\231\162\141\231\142\135",["min"]=0,["max"]=0.4},{["name"]="battleSurfaceId",["type"]="int",["ref"]="MapAreaSurfaceTable",["description"]="\233\154\143\230\156\186\230\136\152\229\156\186\229\156\176\233\157\162\230\157\144\232\180\168"},{["name"]="battlePropIds",["type"]="int[]",["ref"]="MapAssetTable",["description"]="\233\154\156\231\162\141\231\137\169\230\168\161\229\158\139\230\177\160\239\188\155\231\169\186\230\151\182\228\189\191\231\148\168\230\136\152\229\156\186\229\178\169\229\163\129"}},["fingerprint"]="7ab2fdc3e5c9c9e081db51815d5a080d5c1362b48d17368a11cf41ea5d8e8d54"}

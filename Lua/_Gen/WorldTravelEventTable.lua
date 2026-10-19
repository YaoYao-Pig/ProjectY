-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class WorldTravelEventTableRow
---@field id number 规则ID
---@field regionTypes (1|2|3|4|5|6)[] 适用地域，空为全部
---@field weight number 相对抽取权重
---@field eventId number 叙事事件ID；直接遇敌为0
---@field encounterId number 敌群ID；叙事事件为0
return {["name"]="WorldTravelEventTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\232\167\132\229\136\153ID"},{["name"]="regionTypes",["type"]="enum[]",["description"]="\233\128\130\231\148\168\229\156\176\229\159\159\239\188\140\231\169\186\228\184\186\229\133\168\233\131\168",["enumRef"]="Map.E_MapRegion",["enumType"]="int",["values"]={1,2,3,4,5,6}},{["name"]="weight",["type"]="int",["description"]="\231\155\184\229\175\185\230\138\189\229\143\150\230\157\131\233\135\141",["min"]=0},{["name"]="eventId",["type"]="int",["description"]="\229\143\153\228\186\139\228\186\139\228\187\182ID\239\188\155\231\155\180\230\142\165\233\129\135\230\149\140\228\184\1860"},{["name"]="encounterId",["type"]="int",["description"]="\230\149\140\231\190\164ID\239\188\155\229\143\153\228\186\139\228\186\139\228\187\182\228\184\1860"}},["fingerprint"]="64682df88d9feb8ccb894a29f74155b60403d3de9b2936e903f61818714d9d31"}

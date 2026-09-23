-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class MapAreaRoomPresetTableRow
---@field id number 稳定配置 ID
---@field name string 预设大房间名称
---@field radius number 本地轴向格罩半径
---@field tiles string[] 固定格罩：按 r 再 q 排列，. 为地面，# 为墙；宽高均为 2r+1
---@field floorAccent string 预设铺地色 #RRGGBB
---@field districtId number 所属功能分区
return {["name"]="MapAreaRoomPresetTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="string",["description"]="\233\162\132\232\174\190\229\164\167\230\136\191\233\151\180\229\144\141\231\167\176"},{["name"]="radius",["type"]="int",["description"]="\230\156\172\229\156\176\232\189\180\229\144\145\230\160\188\231\189\169\229\141\138\229\190\132",["min"]=6,["max"]=20},{["name"]="tiles",["type"]="string[]",["description"]="\229\155\186\229\174\154\230\160\188\231\189\169\239\188\154\230\140\137 r \229\134\141 q \230\142\146\229\136\151\239\188\140. \228\184\186\229\156\176\233\157\162\239\188\140# \228\184\186\229\162\153\239\188\155\229\174\189\233\171\152\229\157\135\228\184\186 2r+1"},{["name"]="floorAccent",["type"]="string",["description"]="\233\162\132\232\174\190\233\147\186\229\156\176\232\137\178 #RRGGBB"},{["name"]="districtId",["type"]="int",["description"]="\230\137\128\229\177\158\229\138\159\232\131\189\229\136\134\229\140\186",["ref"]="MapAreaDistrictTable"}},["fingerprint"]="df13799c6e0272a087e5fa446d4c9acb595f8b02e06354549674c72b681066a0"}

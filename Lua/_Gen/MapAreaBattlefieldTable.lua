-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class MapAreaBattlefieldTableRow
---@field id number 稳定配置 ID
---@field surfaceId number 地面材质
---@field heightStep number 相邻台阶最大高差（米）
---@field minElevation number 最低峰顶级数
---@field maxElevation number 最高峰顶级数
---@field plateauRadius number 峰顶平台半径；平台清除障碍以供站立
return {["name"]="MapAreaBattlefieldTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="surfaceId",["type"]="int",["description"]="\229\156\176\233\157\162\230\157\144\232\180\168",["ref"]="MapAreaSurfaceTable"},{["name"]="heightStep",["type"]="float",["min"]=0.1,["max"]=2,["default"]=1,["description"]="\231\155\184\233\130\187\229\143\176\233\152\182\230\156\128\229\164\167\233\171\152\229\183\174\239\188\136\231\177\179\239\188\137"},{["name"]="minElevation",["type"]="int",["min"]=2,["max"]=3,["default"]=2,["description"]="\230\156\128\228\189\142\229\179\176\233\161\182\231\186\167\230\149\176"},{["name"]="maxElevation",["type"]="int",["min"]=2,["max"]=3,["default"]=3,["description"]="\230\156\128\233\171\152\229\179\176\233\161\182\231\186\167\230\149\176"},{["name"]="plateauRadius",["type"]="int",["min"]=0,["max"]=1,["default"]=1,["description"]="\229\179\176\233\161\182\229\185\179\229\143\176\229\141\138\229\190\132\239\188\155\229\185\179\229\143\176\230\184\133\233\153\164\233\154\156\231\162\141\228\187\165\228\190\155\231\171\153\231\171\139"}},["fingerprint"]="c2e3a8f7bd8c953b9a0cb217fa1460ad2791f6fa816ccdb005fd294b39fee46e"}

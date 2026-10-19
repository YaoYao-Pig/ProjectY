-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class TorchTableRow
---@field id number 照明配方编号
---@field itemId number 背包中的火炬物品
---@field color string 火光的 HTML 颜色
---@field intensity number 局部点光强度
---@field range number 照明半径，米
---@field height number 相对领队脚底的光源高度，米
---@field description string 背包详情中的用途和操作说明
return {["name"]="TorchTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\133\167\230\152\142\233\133\141\230\150\185\231\188\150\229\143\183",["min"]=1},{["name"]="itemId",["type"]="int",["description"]="\232\131\140\229\140\133\228\184\173\231\154\132\231\129\171\231\130\172\231\137\169\229\147\129",["ref"]="EquipmentItemTable"},{["name"]="color",["type"]="string",["description"]="\231\129\171\229\133\137\231\154\132 HTML \233\162\156\232\137\178"},{["name"]="intensity",["type"]="float",["description"]="\229\177\128\233\131\168\231\130\185\229\133\137\229\188\186\229\186\166",["min"]=0.1},{["name"]="range",["type"]="float",["description"]="\231\133\167\230\152\142\229\141\138\229\190\132\239\188\140\231\177\179",["min"]=1},{["name"]="height",["type"]="float",["description"]="\231\155\184\229\175\185\233\162\134\233\152\159\232\132\154\229\186\149\231\154\132\229\133\137\230\186\144\233\171\152\229\186\166\239\188\140\231\177\179",["min"]=0.1},{["name"]="description",["type"]="text",["description"]="\232\131\140\229\140\133\232\175\166\230\131\133\228\184\173\231\154\132\231\148\168\233\128\148\229\146\140\230\147\141\228\189\156\232\175\180\230\152\142"}},["fingerprint"]="2fb7367642876bc93f8676011d0b923f6b0539d99a37661d0c10c8e68893597d"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentItemTableRow
---@field id number 稳定配置 ID
---@field name string 显示名称
---@field kind "weapon"|"rune"|"magazine"|"ammo"|"module" 物品类别
---@field assetId number 三维展示资源
---@field iconPath string UI Sprite 路径；空字符串显示留白图标
return {["name"]="EquipmentItemTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\230\152\190\231\164\186\229\144\141\231\167\176"},{["name"]="kind",["type"]="enum",["description"]="\231\137\169\229\147\129\231\177\187\229\136\171",["values"]={"weapon","rune","magazine","ammo","module"}},{["name"]="assetId",["type"]="int",["description"]="\228\184\137\231\187\180\229\177\149\231\164\186\232\181\132\230\186\144",["ref"]="EquipmentAssetTable"},{["name"]="iconPath",["type"]="string",["description"]="UI Sprite \232\183\175\229\190\132\239\188\155\231\169\186\229\173\151\231\172\166\228\184\178\230\152\190\231\164\186\231\149\153\231\153\189\229\155\190\230\160\135"}},["fingerprint"]="5a1b87b6e5f94adbd3a42b77228ff310599ba6c25b7f71df5479b7ef9330e566"}

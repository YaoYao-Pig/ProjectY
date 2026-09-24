-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentSocketTableRow
---@field id number 稳定配置 ID
---@field name string 显示名称
---@field weaponItemId number 所属武器
---@field kind "head"|"shaft"|"magazine" 可安装组件类型
---@field position number[] Unity 局部 xyz
---@field rotation number[] Unity 局部欧拉角 xyz
return {["name"]="EquipmentSocketTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\230\152\190\231\164\186\229\144\141\231\167\176"},{["name"]="weaponItemId",["type"]="int",["description"]="\230\137\128\229\177\158\230\173\166\229\153\168",["ref"]="EquipmentItemTable"},{["name"]="kind",["type"]="enum",["description"]="\229\143\175\229\174\137\232\163\133\231\187\132\228\187\182\231\177\187\229\158\139",["values"]={"head","shaft","magazine"}},{["name"]="position",["type"]="float[]",["description"]="Unity \229\177\128\233\131\168 xyz"},{["name"]="rotation",["type"]="float[]",["description"]="Unity \229\177\128\233\131\168\230\172\167\230\139\137\232\167\146 xyz"}},["fingerprint"]="cb81aa2df7f346b0f4d182b79971493102aa68109b67ed5da6070774fcaa34ae"}

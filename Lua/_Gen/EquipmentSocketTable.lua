-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentSocketTableRow
---@field id number 稳定配置 ID
---@field name string 显示名称
---@field weaponItemId number 所属武器
---@field kind "head"|"shaft"|"magazine"|"thruster" 可安装组件类型
---@field position number[] Unity 局部 xyz
---@field rotation number[] Unity 局部欧拉角 xyz
---@field calloutSide "left"|"right" 3D 工坊标签的外侧停靠列
return {["name"]="EquipmentSocketTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\230\152\190\231\164\186\229\144\141\231\167\176"},{["name"]="weaponItemId",["type"]="int",["description"]="\230\137\128\229\177\158\230\173\166\229\153\168",["ref"]="EquipmentItemTable"},{["name"]="kind",["type"]="enum",["description"]="\229\143\175\229\174\137\232\163\133\231\187\132\228\187\182\231\177\187\229\158\139",["values"]={"head","shaft","magazine","thruster"}},{["name"]="position",["type"]="float[]",["description"]="Unity \229\177\128\233\131\168 xyz"},{["name"]="rotation",["type"]="float[]",["description"]="Unity \229\177\128\233\131\168\230\172\167\230\139\137\232\167\146 xyz"},{["name"]="calloutSide",["type"]="enum",["description"]="3D \229\183\165\229\157\138\230\160\135\231\173\190\231\154\132\229\164\150\228\190\167\229\129\156\233\157\160\229\136\151",["values"]={"left","right"}}},["fingerprint"]="799a88db795140966b6d170a474b316e8fd67f475b848acb82d6795c692cb317"}

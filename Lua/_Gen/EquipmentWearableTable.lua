-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentWearableTableRow
---@field id number 物品 ID
---@field slot "head"|"body"|"ring"|"legs"|"feet"|"offhand" 兼容装备槽类型
---@field attributeNames string[] 属性 code
---@field attributeValues number[] 对应属性加成
---@field mount "head"|"chest"|"ring"|"legs"|"feet"|"offhand" 模型挂点；ring 随左右戒指槽选择手
---@field position number[] 相对挂点的位置 XYZ
---@field rotation number[] 相对挂点旋转 XYZ
return {["name"]="EquipmentWearableTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\137\169\229\147\129 ID",["ref"]="EquipmentItemTable"},{["name"]="slot",["type"]="enum",["description"]="\229\133\188\229\174\185\232\163\133\229\164\135\230\167\189\231\177\187\229\158\139",["values"]={"head","body","ring","legs","feet","offhand"}},{["name"]="attributeNames",["type"]="string[]",["description"]="\229\177\158\230\128\167 code"},{["name"]="attributeValues",["type"]="int[]",["description"]="\229\175\185\229\186\148\229\177\158\230\128\167\229\138\160\230\136\144"},{["name"]="mount",["type"]="enum",["description"]="\230\168\161\229\158\139\230\140\130\231\130\185\239\188\155ring \233\154\143\229\183\166\229\143\179\230\136\146\230\140\135\230\167\189\233\128\137\230\139\169\230\137\139",["values"]={"head","chest","ring","legs","feet","offhand"}},{["name"]="position",["type"]="float[]",["description"]="\231\155\184\229\175\185\230\140\130\231\130\185\231\154\132\228\189\141\231\189\174 XYZ"},{["name"]="rotation",["type"]="float[]",["description"]="\231\155\184\229\175\185\230\140\130\231\130\185\230\151\139\232\189\172 XYZ"}},["fingerprint"]="9a13acc96c7c2d8d512495d820a77b48e6c6ff7983e9908e9743e05bac9006bb"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentMagazineTableRow
---@field id number 弹匣物品 ID
---@field ammoItemId number 初始默认弹种；其EquipmentAmmoTable.caliberId决定弹匣兼容口径，不限制为单一弹种
---@field capacity number 弹容量
---@field spawnRounds number 搜刮或初始生成时的装弹数
return {["name"]="EquipmentMagazineTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\229\188\185\229\140\163\231\137\169\229\147\129 ID",["ref"]="EquipmentItemTable"},{["name"]="ammoItemId",["type"]="int",["description"]="\229\136\157\229\167\139\233\187\152\232\174\164\229\188\185\231\167\141\239\188\155\229\133\182EquipmentAmmoTable.caliberId\229\134\179\229\174\154\229\188\185\229\140\163\229\133\188\229\174\185\229\143\163\229\190\132\239\188\140\228\184\141\233\153\144\229\136\182\228\184\186\229\141\149\228\184\128\229\188\185\231\167\141",["ref"]="EquipmentItemTable"},{["name"]="capacity",["type"]="int",["description"]="\229\188\185\229\174\185\233\135\143",["min"]=1,["max"]=100},{["name"]="spawnRounds",["type"]="int",["description"]="\230\144\156\229\136\174\230\136\150\229\136\157\229\167\139\231\148\159\230\136\144\230\151\182\231\154\132\232\163\133\229\188\185\230\149\176",["min"]=0,["max"]=100}},["fingerprint"]="9a19b24cc8c0c0cb0cc147d3965825912c10835b1f31284b5fdf59c36fe6b2ea"}

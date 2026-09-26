-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentRequirementTableRow
---@field id number 需求规则 ID
---@field attributeIds number[] 需要的属性
---@field values number[] 对应最低属性值
---@field damageLossPerPoint number 每个不足点的伤害倍率扣减
---@field minimumDamageScale number 最低伤害比例
---@field hitLossPerPoint number 每个不足点扣减命中百分点
---@field maximumHitLoss number 最高命中惩罚
return {["name"]="EquipmentRequirementTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\233\156\128\230\177\130\232\167\132\229\136\153 ID",["min"]=1},{["name"]="attributeIds",["type"]="int[]",["description"]="\233\156\128\232\166\129\231\154\132\229\177\158\230\128\167",["ref"]="EquipmentAttributeTable"},{["name"]="values",["type"]="int[]",["description"]="\229\175\185\229\186\148\230\156\128\228\189\142\229\177\158\230\128\167\229\128\188"},{["name"]="damageLossPerPoint",["type"]="float",["description"]="\230\175\143\228\184\170\228\184\141\232\182\179\231\130\185\231\154\132\228\188\164\229\174\179\229\128\141\231\142\135\230\137\163\229\135\143",["min"]=0,["max"]=1},{["name"]="minimumDamageScale",["type"]="float",["description"]="\230\156\128\228\189\142\228\188\164\229\174\179\230\175\148\228\190\139",["min"]=0.01,["max"]=1},{["name"]="hitLossPerPoint",["type"]="int",["description"]="\230\175\143\228\184\170\228\184\141\232\182\179\231\130\185\230\137\163\229\135\143\229\145\189\228\184\173\231\153\190\229\136\134\231\130\185",["min"]=0},{["name"]="maximumHitLoss",["type"]="int",["description"]="\230\156\128\233\171\152\229\145\189\228\184\173\230\131\169\231\189\154",["min"]=0,["max"]=100}},["fingerprint"]="12b718d362f17237b2e58110b9a0c4171b03b8ea737734bbadde2059a3d4ffef"}

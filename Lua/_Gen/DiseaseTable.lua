-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class DiseaseTableRow
---@field id number 疾病规则编号
---@field buffId number 持久疾病状态
---@field effectId number 成功感染时施加的效果
---@field chance number 新创伤后感染概率，百分比
---@field itemId number 治疗药品
---@field count number 治疗消耗
return {["name"]="DiseaseTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\150\190\231\151\133\232\167\132\229\136\153\231\188\150\229\143\183",["min"]=1},{["name"]="buffId",["type"]="int",["description"]="\230\140\129\228\185\133\231\150\190\231\151\133\231\138\182\230\128\129",["ref"]="BuffTable"},{["name"]="effectId",["type"]="int",["description"]="\230\136\144\229\138\159\230\132\159\230\159\147\230\151\182\230\150\189\229\138\160\231\154\132\230\149\136\230\158\156",["ref"]="CombatEffectTable"},{["name"]="chance",["type"]="int",["description"]="\230\150\176\229\136\155\228\188\164\229\144\142\230\132\159\230\159\147\230\166\130\231\142\135\239\188\140\231\153\190\229\136\134\230\175\148",["min"]=0,["max"]=100},{["name"]="itemId",["type"]="int",["description"]="\230\178\187\231\150\151\232\141\175\229\147\129",["ref"]="EquipmentItemTable"},{["name"]="count",["type"]="int",["description"]="\230\178\187\231\150\151\230\182\136\232\128\151",["min"]=1}},["fingerprint"]="91f336b6662801b5f6b87a3df80c4b77d9fc0224ce82acc705599e7cdb528c9d"}

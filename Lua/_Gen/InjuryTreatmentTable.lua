-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class InjuryTreatmentTableRow
---@field id number 稳定编号
---@field itemId number 背包医疗物资
---@field count number 每次消耗
---@field recovery number 单次减少的部位损伤
return {["name"]="InjuryTreatmentTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\231\188\150\229\143\183",["min"]=1},{["name"]="itemId",["type"]="int",["description"]="\232\131\140\229\140\133\229\140\187\231\150\151\231\137\169\232\181\132",["ref"]="EquipmentItemTable",["min"]=1},{["name"]="count",["type"]="int",["description"]="\230\175\143\230\172\161\230\182\136\232\128\151",["min"]=1,["max"]=99},{["name"]="recovery",["type"]="int",["description"]="\229\141\149\230\172\161\229\135\143\229\176\145\231\154\132\233\131\168\228\189\141\230\141\159\228\188\164",["min"]=1,["max"]=100}},["fingerprint"]="eb81178d90c0fea1a850b09301a3aaff54270e4090078c703b9cba992c2863b5"}

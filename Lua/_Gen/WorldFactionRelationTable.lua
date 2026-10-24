-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class WorldFactionRelationTableRow
---@field id number 关系 ID
---@field first number 第一组织
---@field second number 第二组织
---@field value number 关系分值
return {["name"]="WorldFactionRelationTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\229\133\179\231\179\187 ID",["min"]=1},{["name"]="first",["type"]="int",["description"]="\231\172\172\228\184\128\231\187\132\231\187\135",["ref"]="FactionTable"},{["name"]="second",["type"]="int",["description"]="\231\172\172\228\186\140\231\187\132\231\187\135",["ref"]="FactionTable"},{["name"]="value",["type"]="int",["description"]="\229\133\179\231\179\187\229\136\134\229\128\188",["min"]=-100,["max"]=100}},["fingerprint"]="da2932a0a32b3ac1830fdf7521f6821026f989742ee6760d85e4bc3a0a82d3d2"}

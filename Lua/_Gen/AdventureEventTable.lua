-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class AdventureEventTableRow
---@field id number 稳定配置 ID
---@field name string 事件标题
---@field description string 事件正文
---@field repeatable boolean 返回后能否再次触发
---@field choiceIds number[] 选项顺序
return {["name"]="AdventureEventTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\228\186\139\228\187\182\230\160\135\233\162\152"},{["name"]="description",["type"]="text",["description"]="\228\186\139\228\187\182\230\173\163\230\150\135"},{["name"]="repeatable",["type"]="bool",["description"]="\232\191\148\229\155\158\229\144\142\232\131\189\229\144\166\229\134\141\230\172\161\232\167\166\229\143\145"},{["name"]="choiceIds",["type"]="int[]",["description"]="\233\128\137\233\161\185\233\161\186\229\186\143",["ref"]="AdventureChoiceTable"}},["fingerprint"]="e4f899a11c19e486bc2fe9f388b5369cac3ba9e5f4c0a6fd38e152dc8494f29b"}

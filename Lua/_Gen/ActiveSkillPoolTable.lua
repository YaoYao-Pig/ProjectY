-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class ActiveSkillPoolTableRow
---@field id number 稳定配置 ID
---@field attributeId number 属性方向
---@field skillId number 主动技能
---@field tier number 技能池层级
---@field minValue number 属性下限（含）
---@field maxValue number 属性上限（含）
---@field weight number 层内基础权重
return {["name"]="ActiveSkillPoolTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="attributeId",["type"]="int",["description"]="\229\177\158\230\128\167\230\150\185\229\144\145",["ref"]="GrowthAttributeTable"},{["name"]="skillId",["type"]="int",["description"]="\228\184\187\229\138\168\230\138\128\232\131\189",["ref"]="CombatSkillTable"},{["name"]="tier",["type"]="int",["description"]="\230\138\128\232\131\189\230\177\160\229\177\130\231\186\167",["min"]=1},{["name"]="minValue",["type"]="int",["description"]="\229\177\158\230\128\167\228\184\139\233\153\144\239\188\136\229\144\171\239\188\137",["min"]=0},{["name"]="maxValue",["type"]="int",["description"]="\229\177\158\230\128\167\228\184\138\233\153\144\239\188\136\229\144\171\239\188\137",["min"]=0},{["name"]="weight",["type"]="float",["description"]="\229\177\130\229\134\133\229\159\186\231\161\128\230\157\131\233\135\141",["min"]=0.001}},["fingerprint"]="1635274cfc01dd9e2d6e0bba94d565fdd9ddb493c92a2043f8aeb4ece8909877"}

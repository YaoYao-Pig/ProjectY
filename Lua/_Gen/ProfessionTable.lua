-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class ProfessionTableRow
---@field id number 职业 ID
---@field name string 职业名称
---@field description string 职业说明
---@field treeIds number[] 加入职业后永久开放的被动树
---@field initialSkillIds number[] 仅初始职业免费授予的技能；转职不授予
return {["name"]="ProfessionTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\232\129\140\228\184\154 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\232\129\140\228\184\154\229\144\141\231\167\176"},{["name"]="description",["type"]="text",["description"]="\232\129\140\228\184\154\232\175\180\230\152\142"},{["name"]="treeIds",["type"]="int[]",["description"]="\229\138\160\229\133\165\232\129\140\228\184\154\229\144\142\230\176\184\228\185\133\229\188\128\230\148\190\231\154\132\232\162\171\229\138\168\230\160\145",["ref"]="TalentTreeTable"},{["name"]="initialSkillIds",["type"]="int[]",["description"]="\228\187\133\229\136\157\229\167\139\232\129\140\228\184\154\229\133\141\232\180\185\230\142\136\228\186\136\231\154\132\230\138\128\232\131\189\239\188\155\232\189\172\232\129\140\228\184\141\230\142\136\228\186\136",["ref"]="CombatSkillTable"}},["fingerprint"]="18c1c3482f39944948e6376c418f3fc449ab39354e4b1ecaf6e730f411d1c11a"}

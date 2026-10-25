-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class ProfessionTableRow
---@field id number 职业 ID
---@field name string 职业名称
---@field description string 职业说明
---@field iconPath string 职业徽记 Sprite 资源路径
---@field treeIds number[] 加入职业后永久开放的被动树
---@field initialSkillIds number[] 仅初始职业免费授予的技能；转职不授予
---@field baseProfession boolean 创建时确定的基础职业，不可通过添加兼职获得
return {["name"]="ProfessionTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\232\129\140\228\184\154 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\232\129\140\228\184\154\229\144\141\231\167\176"},{["name"]="description",["type"]="text",["description"]="\232\129\140\228\184\154\232\175\180\230\152\142"},{["name"]="iconPath",["type"]="string",["description"]="\232\129\140\228\184\154\229\190\189\232\174\176 Sprite \232\181\132\230\186\144\232\183\175\229\190\132"},{["name"]="treeIds",["type"]="int[]",["description"]="\229\138\160\229\133\165\232\129\140\228\184\154\229\144\142\230\176\184\228\185\133\229\188\128\230\148\190\231\154\132\232\162\171\229\138\168\230\160\145",["ref"]="TalentTreeTable"},{["name"]="initialSkillIds",["type"]="int[]",["description"]="\228\187\133\229\136\157\229\167\139\232\129\140\228\184\154\229\133\141\232\180\185\230\142\136\228\186\136\231\154\132\230\138\128\232\131\189\239\188\155\232\189\172\232\129\140\228\184\141\230\142\136\228\186\136",["ref"]="CombatSkillTable"},{["name"]="baseProfession",["type"]="bool",["default"]=false,["description"]="\229\136\155\229\187\186\230\151\182\231\161\174\229\174\154\231\154\132\229\159\186\231\161\128\232\129\140\228\184\154\239\188\140\228\184\141\229\143\175\233\128\154\232\191\135\230\183\187\229\138\160\229\133\188\232\129\140\232\142\183\229\190\151"}},["fingerprint"]="75afd0e4d7ade1809c19d1192e76f16a40d143196bf3ebccb05493d83ea7a894"}

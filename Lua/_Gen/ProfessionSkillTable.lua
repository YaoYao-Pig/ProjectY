-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class ProfessionSkillTableRow
---@field id number 课程 ID
---@field professionId number 所属职业
---@field skillId number 主动或准备技能
---@field minLevel number 角色等级门槛
---@field attributeNames string[] 全部需要达到的属性代码
---@field attributeValues number[] 对应属性最小值
return {["name"]="ProfessionSkillTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\232\175\190\231\168\139 ID",["min"]=1},{["name"]="professionId",["type"]="int",["description"]="\230\137\128\229\177\158\232\129\140\228\184\154",["ref"]="ProfessionTable"},{["name"]="skillId",["type"]="int",["description"]="\228\184\187\229\138\168\230\136\150\229\135\134\229\164\135\230\138\128\232\131\189",["ref"]="CombatSkillTable"},{["name"]="minLevel",["type"]="int",["description"]="\232\167\146\232\137\178\231\173\137\231\186\167\233\151\168\230\167\155",["min"]=1},{["name"]="attributeNames",["type"]="string[]",["description"]="\229\133\168\233\131\168\233\156\128\232\166\129\232\190\190\229\136\176\231\154\132\229\177\158\230\128\167\228\187\163\231\160\129"},{["name"]="attributeValues",["type"]="int[]",["description"]="\229\175\185\229\186\148\229\177\158\230\128\167\230\156\128\229\176\143\229\128\188"}},["fingerprint"]="40789eb1b29709d592f1cfd251755a89ac3abc9fe33929069b7f5da07089901a"}

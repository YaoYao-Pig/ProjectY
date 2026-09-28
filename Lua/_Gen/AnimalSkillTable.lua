-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class AnimalSkillTableRow
---@field id number 稳定配置 ID
---@field speciesId number 动物物种
---@field skillId number 授予技能
---@field minimumBond number 所需亲密度
---@field movement "charge"|"pounce"|"leap" 冲击直线移动、飞扑与跳跃
---@field minimumDistance number 目标最小格距
---@field maximumDistance number 目标最大格距
return {["name"]="AnimalSkillTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="speciesId",["type"]="int",["description"]="\229\138\168\231\137\169\231\137\169\231\167\141",["ref"]="AnimalSpeciesTable"},{["name"]="skillId",["type"]="int",["description"]="\230\142\136\228\186\136\230\138\128\232\131\189",["ref"]="CombatSkillTable"},{["name"]="minimumBond",["type"]="int",["description"]="\230\137\128\233\156\128\228\186\178\229\175\134\229\186\166",["min"]=0},{["name"]="movement",["type"]="enum",["description"]="\229\134\178\229\135\187\231\155\180\231\186\191\231\167\187\229\138\168\227\128\129\233\163\158\230\137\145\228\184\142\232\183\179\232\183\131",["values"]={"charge","pounce","leap"}},{["name"]="minimumDistance",["type"]="int",["description"]="\231\155\174\230\160\135\230\156\128\229\176\143\230\160\188\232\183\157",["min"]=1},{["name"]="maximumDistance",["type"]="int",["description"]="\231\155\174\230\160\135\230\156\128\229\164\167\230\160\188\232\183\157",["min"]=1}},["fingerprint"]="2c09330f9ffbacb160e1c5db1b9409712cf2ce7c8ebf6ee6c0ce4099e26dfb5f"}

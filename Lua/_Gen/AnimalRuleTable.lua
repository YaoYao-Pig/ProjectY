-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class AnimalRuleTableRow
---@field id number 稳定配置 ID
---@field tameSkillId number 驯服技能
---@field chance ConfigFormula 驯服概率；affinity/charisma/missingHealth/hostile/difficulty
---@field minimumChance number 最小概率
---@field maximumChance number 最大概率
return {["name"]="AnimalRuleTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="tameSkillId",["type"]="int",["description"]="\233\169\175\230\156\141\230\138\128\232\131\189",["ref"]="CombatSkillTable"},{["name"]="chance",["type"]="formula",["variables"]={"affinity","charisma","missingHealth","hostile","difficulty"},["description"]="\233\169\175\230\156\141\230\166\130\231\142\135\239\188\155affinity/charisma/missingHealth/hostile/difficulty"},{["name"]="minimumChance",["type"]="float",["description"]="\230\156\128\229\176\143\230\166\130\231\142\135",["min"]=0,["max"]=100},{["name"]="maximumChance",["type"]="float",["description"]="\230\156\128\229\164\167\230\166\130\231\142\135",["min"]=0,["max"]=100}},["fingerprint"]="0bd6ad5302bee3bddae9eb396c92605bbbb34f5675405eeda46ab66079c978da"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class ConsumableTableRow
---@field id number 消耗品ID
---@field skillId number 仅通过物品使用的技能
---@field count number 每次使用消耗的堆叠数量
return {["name"]="ConsumableTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\230\182\136\232\128\151\229\147\129ID",["ref"]="EquipmentItemTable",["min"]=1},{["name"]="skillId",["type"]="int",["description"]="\228\187\133\233\128\154\232\191\135\231\137\169\229\147\129\228\189\191\231\148\168\231\154\132\230\138\128\232\131\189",["ref"]="CombatSkillTable",["min"]=1},{["name"]="count",["type"]="int",["description"]="\230\175\143\230\172\161\228\189\191\231\148\168\230\182\136\232\128\151\231\154\132\229\160\134\229\143\160\230\149\176\233\135\143",["min"]=1,["max"]=100}},["fingerprint"]="573968916c87974f31af020989dea7be2f8f51bc7e75f01f08e6f6681eaa59db"}

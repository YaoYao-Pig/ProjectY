-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentDescriptionTableRow
---@field id number 装备物品ID
---@field passiveName string 固有特性标题
---@field trigger string 触发条件；支持term链接及数值富文本
---@field effect string 获得的效果或资源
---@field limit string 上限、消费和失效条件
---@field usage string 持握、射程及其他使用限制
---@field skillIds number[] 优先展示的装备技能；正文复用SkillDescriptionTable
return {["name"]="EquipmentDescriptionTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["ref"]="EquipmentItemTable",["description"]="\232\163\133\229\164\135\231\137\169\229\147\129ID"},{["name"]="passiveName",["type"]="text",["description"]="\229\155\186\230\156\137\231\137\185\230\128\167\230\160\135\233\162\152"},{["name"]="trigger",["type"]="text",["default"]="",["description"]="\232\167\166\229\143\145\230\157\161\228\187\182\239\188\155\230\148\175\230\140\129term\233\147\190\230\142\165\229\143\138\230\149\176\229\128\188\229\175\140\230\150\135\230\156\172"},{["name"]="effect",["type"]="text",["default"]="",["description"]="\232\142\183\229\190\151\231\154\132\230\149\136\230\158\156\230\136\150\232\181\132\230\186\144"},{["name"]="limit",["type"]="text",["default"]="",["description"]="\228\184\138\233\153\144\227\128\129\230\182\136\232\180\185\229\146\140\229\164\177\230\149\136\230\157\161\228\187\182"},{["name"]="usage",["type"]="text",["default"]="",["description"]="\230\140\129\230\143\161\227\128\129\229\176\132\231\168\139\229\143\138\229\133\182\228\187\150\228\189\191\231\148\168\233\153\144\229\136\182"},{["name"]="skillIds",["type"]="int[]",["ref"]="CombatSkillTable",["default"]={},["description"]="\228\188\152\229\133\136\229\177\149\231\164\186\231\154\132\232\163\133\229\164\135\230\138\128\232\131\189\239\188\155\230\173\163\230\150\135\229\164\141\231\148\168SkillDescriptionTable"}},["fingerprint"]="9bace3b27595b9084f95cb9c2975b03b4a512943bfd26c14d155d94f1d3f88af"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class SkillDescriptionTableRow
---@field id number 技能 ID
---@field tagIds string[] 按显示顺序排列的类别标签
---@field body string 效果正文，支持原生TMP term链接；属性数值优先由独立属性栏显示
---@field fragmentIds string[] 按顺序追加的复用段落
return {["name"]="SkillDescriptionTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\230\138\128\232\131\189 ID",["ref"]="CombatSkillTable"},{["name"]="tagIds",["type"]="string[]",["description"]="\230\140\137\230\152\190\231\164\186\233\161\186\229\186\143\230\142\146\229\136\151\231\154\132\231\177\187\229\136\171\230\160\135\231\173\190",["ref"]="SkillTagTable"},{["name"]="body",["type"]="text",["description"]="\230\149\136\230\158\156\230\173\163\230\150\135\239\188\140\230\148\175\230\140\129\229\142\159\231\148\159TMP term\233\147\190\230\142\165\239\188\155\229\177\158\230\128\167\230\149\176\229\128\188\228\188\152\229\133\136\231\148\177\231\139\172\231\171\139\229\177\158\230\128\167\230\160\143\230\152\190\231\164\186"},{["name"]="fragmentIds",["type"]="string[]",["description"]="\230\140\137\233\161\186\229\186\143\232\191\189\229\138\160\231\154\132\229\164\141\231\148\168\230\174\181\232\144\189",["ref"]="SkillTipTextTable"}},["fingerprint"]="9835059de06f8914cb1818ea64cf571183f58ebc335e45f6cf0506f9bb6b918b"}

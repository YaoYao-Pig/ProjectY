-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class MoraleEventTableRow
---@field id number 事件 ID
---@field kind "wound"|"ally_defeated"|"ally_fleeing"|"enemy_defeated"|"kill"|"outnumbered"|"rally" 事件类型，每种恰好一行
---@field name string 战斗日志中的事件名称
---@field difficulty number 从勇气检定成功率扣除的难度，可为负数
---@field change number 检定生效后改变的士气点数
return {["name"]="MoraleEventTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["min"]=1,["description"]="\228\186\139\228\187\182 ID"},{["name"]="kind",["type"]="enum",["values"]={"wound","ally_defeated","ally_fleeing","enemy_defeated","kill","outnumbered","rally"},["description"]="\228\186\139\228\187\182\231\177\187\229\158\139\239\188\140\230\175\143\231\167\141\230\129\176\229\165\189\228\184\128\232\161\140"},{["name"]="name",["type"]="text",["description"]="\230\136\152\230\150\151\230\151\165\229\191\151\228\184\173\231\154\132\228\186\139\228\187\182\229\144\141\231\167\176"},{["name"]="difficulty",["type"]="int",["description"]="\228\187\142\229\139\135\230\176\148\230\163\128\229\174\154\230\136\144\229\138\159\231\142\135\230\137\163\233\153\164\231\154\132\233\154\190\229\186\166\239\188\140\229\143\175\228\184\186\232\180\159\230\149\176"},{["name"]="change",["type"]="int",["min"]=-1000000,["max"]=1000000,["description"]="\230\163\128\229\174\154\231\148\159\230\149\136\229\144\142\230\148\185\229\143\152\231\154\132\229\163\171\230\176\148\231\130\185\230\149\176"}},["fingerprint"]="c7cb50cd242e3d56cdec9c6844d044781904398c744c9643d51e984c51b4675d"}

-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class TitleRequirementTableRow
---@field id number 条件 ID
---@field kind "kill"|"legend"|"mission"|"quest"|"town"|"rescue" 统计类型
---@field targetId number 指定类型的配置 ID，0 表示任意；rescue 只能为 0。mission:0 包含城镇委托，不包含阶段。
---@field required number 需要的累计次数
---@field description string 玩家可见的达成条件说明
return {["name"]="TitleRequirementTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["min"]=1,["description"]="\230\157\161\228\187\182 ID"},{["name"]="kind",["type"]="enum",["values"]={"kill","legend","mission","quest","town","rescue"},["description"]="\231\187\159\232\174\161\231\177\187\229\158\139"},{["name"]="targetId",["type"]="int",["min"]=0,["description"]="\230\140\135\229\174\154\231\177\187\229\158\139\231\154\132\233\133\141\231\189\174 ID\239\188\1400 \232\161\168\231\164\186\228\187\187\230\132\143\239\188\155rescue \229\143\170\232\131\189\228\184\186 0\227\128\130mission:0 \229\140\133\229\144\171\229\159\142\233\149\135\229\167\148\230\137\152\239\188\140\228\184\141\229\140\133\229\144\171\233\152\182\230\174\181\227\128\130"},{["name"]="required",["type"]="int",["min"]=1,["description"]="\233\156\128\232\166\129\231\154\132\231\180\175\232\174\161\230\172\161\230\149\176"},{["name"]="description",["type"]="text",["description"]="\231\142\169\229\174\182\229\143\175\232\167\129\231\154\132\232\190\190\230\136\144\230\157\161\228\187\182\232\175\180\230\152\142"}},["fingerprint"]="505881b9260465679fed6ecd0c7d4c298c0a97c1a78036598f38ce07b8c76355"}

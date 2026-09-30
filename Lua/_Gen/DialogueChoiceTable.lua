-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class DialogueChoiceTableRow
---@field id number 稳定配置 ID
---@field text string 选项文本
---@field conditionId number 可选条件
---@field hideWhenLocked boolean 不可选时隐藏
---@field nextNodeId number 下一节点；0 表示结束，由叙事校验检查引用
---@field actionIds number[] 选择时执行的动作
return {["name"]="DialogueChoiceTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="text",["type"]="text",["description"]="\233\128\137\233\161\185\230\150\135\230\156\172"},{["name"]="conditionId",["type"]="int",["description"]="\229\143\175\233\128\137\230\157\161\228\187\182",["ref"]="ConditionTable"},{["name"]="hideWhenLocked",["type"]="bool",["description"]="\228\184\141\229\143\175\233\128\137\230\151\182\233\154\144\232\151\143",["default"]=false},{["name"]="nextNodeId",["type"]="int",["description"]="\228\184\139\228\184\128\232\138\130\231\130\185\239\188\1550 \232\161\168\231\164\186\231\187\147\230\157\159\239\188\140\231\148\177\229\143\153\228\186\139\230\160\161\233\170\140\230\163\128\230\159\165\229\188\149\231\148\168",["min"]=0},{["name"]="actionIds",["type"]="int[]",["description"]="\233\128\137\230\139\169\230\151\182\230\137\167\232\161\140\231\154\132\229\138\168\228\189\156",["ref"]="NarrativeActionTable",["default"]={}}},["fingerprint"]="6c29633f54ee549f552de99e360690d7d6a5ec65d34481b290a3ad383ec6e832"}

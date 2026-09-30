-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class DialogueNodeTableRow
---@field id number 稳定配置 ID
---@field dialogueId number 所属对话
---@field speaker "npc"|"player"|"narrator" 说话者
---@field text string 显示正文
---@field choiceIds number[] 顺序展示的选项；空列表显示结束
---@field shot "pair"|"npc"|"player" 镜头构图
return {["name"]="DialogueNodeTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="dialogueId",["type"]="int",["description"]="\230\137\128\229\177\158\229\175\185\232\175\157",["ref"]="DialogueTable"},{["name"]="speaker",["type"]="enum",["description"]="\232\175\180\232\175\157\232\128\133",["values"]={"npc","player","narrator"}},{["name"]="text",["type"]="text",["description"]="\230\152\190\231\164\186\230\173\163\230\150\135"},{["name"]="choiceIds",["type"]="int[]",["description"]="\233\161\186\229\186\143\229\177\149\231\164\186\231\154\132\233\128\137\233\161\185\239\188\155\231\169\186\229\136\151\232\161\168\230\152\190\231\164\186\231\187\147\230\157\159",["ref"]="DialogueChoiceTable",["default"]={}},{["name"]="shot",["type"]="enum",["description"]="\233\149\156\229\164\180\230\158\132\229\155\190",["values"]={"pair","npc","player"},["default"]="pair"}},["fingerprint"]="7b43fa8c646ab50a6eb9c68473ee11a319e39697533d2b7bdf4f26798086e7b8"}

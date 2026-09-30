-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class DialogueTableRow
---@field id number 稳定配置 ID
---@field name string 对话名称
---@field npcId number 对话对象
---@field conditionId number 开启条件
---@field entryNodeId number 起始节点
---@field cameraId number 镜头配方
return {["name"]="DialogueTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\229\175\185\232\175\157\229\144\141\231\167\176"},{["name"]="npcId",["type"]="int",["description"]="\229\175\185\232\175\157\229\175\185\232\177\161",["ref"]="NpcTable"},{["name"]="conditionId",["type"]="int",["description"]="\229\188\128\229\144\175\230\157\161\228\187\182",["ref"]="ConditionTable"},{["name"]="entryNodeId",["type"]="int",["description"]="\232\181\183\229\167\139\232\138\130\231\130\185",["ref"]="DialogueNodeTable"},{["name"]="cameraId",["type"]="int",["description"]="\233\149\156\229\164\180\233\133\141\230\150\185",["ref"]="DialogueCameraTable"}},["fingerprint"]="af2450b2765e3d6d3b07d75f3b00f25a278fef9646a30889458f4cb85f8bd858"}

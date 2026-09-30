-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class NarrativeActionTableRow
---@field id number 稳定配置 ID
---@field kind "set_flag"|"add_coins"|"grant_item"|"accept_mission"|"claim_mission"|"recruit_npc"|"add_relation"|"add_reputation" 动作类型
---@field targetId number 目标配置 ID，由动作类型检查
---@field key string 事实键，仅 set_flag 使用
---@field value number 数量或增量；set_flag 为目标值
return {["name"]="NarrativeActionTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="kind",["type"]="enum",["description"]="\229\138\168\228\189\156\231\177\187\229\158\139",["values"]={"set_flag","add_coins","grant_item","accept_mission","claim_mission","recruit_npc","add_relation","add_reputation"}},{["name"]="targetId",["type"]="int",["description"]="\231\155\174\230\160\135\233\133\141\231\189\174 ID\239\188\140\231\148\177\229\138\168\228\189\156\231\177\187\229\158\139\230\163\128\230\159\165",["default"]=0},{["name"]="key",["type"]="string",["description"]="\228\186\139\229\174\158\233\148\174\239\188\140\228\187\133 set_flag \228\189\191\231\148\168",["default"]=""},{["name"]="value",["type"]="int",["description"]="\230\149\176\233\135\143\230\136\150\229\162\158\233\135\143\239\188\155set_flag \228\184\186\231\155\174\230\160\135\229\128\188",["default"]=0}},["fingerprint"]="4ff1665c62a1dbd9b19ba5c9c483165bc2138f96c15c6f72016bfcfc099404b3"}

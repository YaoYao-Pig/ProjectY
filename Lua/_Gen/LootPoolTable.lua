-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class LootPoolTableRow
---@field id number 稳定配置 ID
---@field name string 掉落池名
---@field seedSalt number 独立随机通道
---@field mode "independent"|"weighted" 逐项独立概率，或按权重抽取固定次数
---@field drawCount number weighted 模式抽取次数；允许重复，同物品合并
return {["name"]="LootPoolTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="text",["description"]="\230\142\137\232\144\189\230\177\160\229\144\141"},{["name"]="seedSalt",["type"]="int",["description"]="\231\139\172\231\171\139\233\154\143\230\156\186\233\128\154\233\129\147",["min"]=0},{["name"]="mode",["type"]="enum",["description"]="\233\128\144\233\161\185\231\139\172\231\171\139\230\166\130\231\142\135\239\188\140\230\136\150\230\140\137\230\157\131\233\135\141\230\138\189\229\143\150\229\155\186\229\174\154\230\172\161\230\149\176",["default"]="independent",["values"]={"independent","weighted"}},{["name"]="drawCount",["type"]="int",["description"]="weighted \230\168\161\229\188\143\230\138\189\229\143\150\230\172\161\230\149\176\239\188\155\229\133\129\232\174\184\233\135\141\229\164\141\239\188\140\229\144\140\231\137\169\229\147\129\229\144\136\229\185\182",["default"]=1,["min"]=1}},["fingerprint"]="f8e965edba1be2df0f1357d1bd3d6e3b0cd0a2e89121f9e9856c3e8620e6834d"}

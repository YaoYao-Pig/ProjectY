-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class ProfessionAttributeTableRow
---@field id number 配置ID
---@field professionId number 适用职业
---@field attributeId number 加成属性
---@field fixedBonus number 固定加成
---@field randomMin number 随机加成下限（含）
---@field randomMax number 随机加成上限（含），为0则不额外随机
return {["name"]="ProfessionAttributeTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\233\133\141\231\189\174ID",["min"]=1},{["name"]="professionId",["type"]="int",["ref"]="ProfessionTable",["description"]="\233\128\130\231\148\168\232\129\140\228\184\154",["min"]=1},{["name"]="attributeId",["type"]="int",["ref"]="GrowthAttributeTable",["description"]="\229\138\160\230\136\144\229\177\158\230\128\167",["min"]=1},{["name"]="fixedBonus",["type"]="int",["description"]="\229\155\186\229\174\154\229\138\160\230\136\144",["min"]=0},{["name"]="randomMin",["type"]="int",["description"]="\233\154\143\230\156\186\229\138\160\230\136\144\228\184\139\233\153\144\239\188\136\229\144\171\239\188\137",["min"]=0},{["name"]="randomMax",["type"]="int",["description"]="\233\154\143\230\156\186\229\138\160\230\136\144\228\184\138\233\153\144\239\188\136\229\144\171\239\188\137\239\188\140\228\184\1860\229\136\153\228\184\141\233\162\157\229\164\150\233\154\143\230\156\186",["min"]=0}},["fingerprint"]="6e0a1cca0e09693ad4859296f3d2d82cc34d9e502ef63fd4c8240658d5d27f0b"}

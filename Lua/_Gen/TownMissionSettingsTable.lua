-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class TownMissionSettingsTableRow
---@field id number 规则 ID
---@field minOffers number 每镇每天委托数量下限
---@field maxOffers number 每镇每天委托数量上限
---@field escortPartyDefinitionId number 护送商队模板
---@field escortArrivalRadius number 抵达时玩家距商队的最大格数
return {["name"]="TownMissionSettingsTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\232\167\132\229\136\153 ID",["min"]=1},{["name"]="minOffers",["type"]="int",["description"]="\230\175\143\233\149\135\230\175\143\229\164\169\229\167\148\230\137\152\230\149\176\233\135\143\228\184\139\233\153\144",["min"]=1},{["name"]="maxOffers",["type"]="int",["description"]="\230\175\143\233\149\135\230\175\143\229\164\169\229\167\148\230\137\152\230\149\176\233\135\143\228\184\138\233\153\144",["min"]=1},{["name"]="escortPartyDefinitionId",["type"]="int",["description"]="\230\138\164\233\128\129\229\149\134\233\152\159\230\168\161\230\157\191",["ref"]="WorldPartyTable"},{["name"]="escortArrivalRadius",["type"]="int",["description"]="\230\138\181\232\190\190\230\151\182\231\142\169\229\174\182\232\183\157\229\149\134\233\152\159\231\154\132\230\156\128\229\164\167\230\160\188\230\149\176",["min"]=0}},["fingerprint"]="53be6e2733b4ba5b2359df2673df05157a3cdff4b9facf3628c430e22b4a7f42"}

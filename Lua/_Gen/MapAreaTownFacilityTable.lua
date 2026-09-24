-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class MapAreaTownFacilityTableRow
---@field id number 稳定配置 ID
---@field name string 显示名称
---@field kind "tavern"|"smithy"|"shop"|"guild"|"square"|"palace"|"bakery"|"herbalist"|"chapel"|"warehouse"|"stable"|"watchtower" 功能标识
---@field description string 靠近交互时的说明
---@field lotIds number[] 可选外观预设
---@field npcTemplateId number 门前服务 NPC
---@field interactionRadius number 门前交互半径，单位为格
return {["name"]="MapAreaTownFacilityTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\231\168\179\229\174\154\233\133\141\231\189\174 ID",["min"]=1},{["name"]="name",["type"]="string",["description"]="\230\152\190\231\164\186\229\144\141\231\167\176"},{["name"]="kind",["type"]="enum",["description"]="\229\138\159\232\131\189\230\160\135\232\175\134",["values"]={"tavern","smithy","shop","guild","square","palace","bakery","herbalist","chapel","warehouse","stable","watchtower"}},{["name"]="description",["type"]="text",["description"]="\233\157\160\232\191\145\228\186\164\228\186\146\230\151\182\231\154\132\232\175\180\230\152\142"},{["name"]="lotIds",["type"]="int[]",["description"]="\229\143\175\233\128\137\229\164\150\232\167\130\233\162\132\232\174\190",["ref"]="MapAreaTownLotTable"},{["name"]="npcTemplateId",["type"]="int",["description"]="\233\151\168\229\137\141\230\156\141\229\138\161 NPC",["ref"]="MapAreaTownNpcTable"},{["name"]="interactionRadius",["type"]="int",["description"]="\233\151\168\229\137\141\228\186\164\228\186\146\229\141\138\229\190\132\239\188\140\229\141\149\228\189\141\228\184\186\230\160\188",["min"]=1,["max"]=3}},["fingerprint"]="b66d87d3acffe5f5fb7e7b6346aa0908751b8b2c66eea5d28afb8db551732fbe"}

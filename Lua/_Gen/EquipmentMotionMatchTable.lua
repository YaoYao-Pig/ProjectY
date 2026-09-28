-- 由 Tools/ConfigEditor/exporter.mjs 自动生成，请勿手动修改。
---@class EquipmentMotionMatchTableRow
---@field id number 匹配规则 ID
---@field mainKind "none"|"melee"|"staff"|"bow"|"gun" 主手武器种类；空手为 none
---@field mainHands number 主武器需要的手数；空手为 0
---@field offKind "none"|"weapon"|"shield" 副手实际状态
---@field gunClass string 枪型；非枪械为空，新增枪型添加相应规则
---@field moduleId number 匹配后的动作模组
return {["name"]="EquipmentMotionMatchTable",["key"]="id",["fields"]={{["name"]="id",["type"]="int",["description"]="\229\140\185\233\133\141\232\167\132\229\136\153 ID",["min"]=1},{["name"]="mainKind",["type"]="enum",["description"]="\228\184\187\230\137\139\230\173\166\229\153\168\231\167\141\231\177\187\239\188\155\231\169\186\230\137\139\228\184\186 none",["values"]={"none","melee","staff","bow","gun"}},{["name"]="mainHands",["type"]="int",["description"]="\228\184\187\230\173\166\229\153\168\233\156\128\232\166\129\231\154\132\230\137\139\230\149\176\239\188\155\231\169\186\230\137\139\228\184\186 0",["min"]=0,["max"]=2},{["name"]="offKind",["type"]="enum",["description"]="\229\137\175\230\137\139\229\174\158\233\153\133\231\138\182\230\128\129",["values"]={"none","weapon","shield"}},{["name"]="gunClass",["type"]="string",["description"]="\230\158\170\229\158\139\239\188\155\233\157\158\230\158\170\230\162\176\228\184\186\231\169\186\239\188\140\230\150\176\229\162\158\230\158\170\229\158\139\230\183\187\229\138\160\231\155\184\229\186\148\232\167\132\229\136\153"},{["name"]="moduleId",["type"]="int",["description"]="\229\140\185\233\133\141\229\144\142\231\154\132\229\138\168\228\189\156\230\168\161\231\187\132",["ref"]="EquipmentMotionModuleTable"}},["fingerprint"]="76288dc723a54d15fc150b79fb80796dc3c3029fabb621deb6aa65cbde42b5f3"}

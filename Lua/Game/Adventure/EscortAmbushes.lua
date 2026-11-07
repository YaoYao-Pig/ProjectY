local Random=require('Game.Map.SeededRandom')
local Ambushes={}
local function routeKey(id) return 'escort_route:'..id end
local function checksKey(id) return 'escort_checks:'..id end

-- NarrativeData owns these expedition facts, including across save/load and runtime reconstruction.
function Ambushes.Start(escort,record,party)
    assert(party.Travel.StepCount>0,'Escort ambush route must contain land steps')
    escort.story.data:SetValue(routeKey(record.Id),party.Travel.StepCount)
end

function Ambushes.Check(escort,record,party,minute)
    local travel=party.Travel;local data=escort.story.data;local rule=escort.rule
    if party.BattleSiteId>0 or not travel.Active or travel.Progress~=0 then return false end
    local total=data:GetValue(routeKey(record.Id));local checked=data:GetValue(checksKey(record.Id))
    local due=math.min(rule.escortAmbushChecks,math.floor((total-travel.StepCount)*(rule.escortAmbushChecks+1)/total))
    if checked>=due then return false end
    local adventure=escort.adventure;local parties=adventure.parties;local factions=adventure.factions
    local cell=adventure.map:GetCell(travel.Q,travel.R)
    -- Defer a checkpoint until the convoy leaves a settlement; never stage a town ambush.
    if cell.waterLevel or cell.buildingId or cell.townId then return false end
    while checked<due do
        checked=checked+1;data:SetValue(checksKey(record.Id),checked)
        local random=Random((adventure.data.Seed ~ (record.Id*104729) ~ (checked*7919)) & 0xffffffff)
        if random:Integer(1,100)<=rule.escortAmbushChance and parties.data.Count<4096 then
            local candidates={};local region=adventure.map:GetRegion(cell.regionId).regionType
            for _,id in ipairs(rule.escortAmbushPartyIds) do local definition=parties.definitions:Get(id)
                if factions:Relation(party.FactionId,definition.factionId)=='hostile' and factions.rules:Suitable(definition.factionId,region) then
                    candidates[#candidates+1]=definition
                end
            end
            if #candidates>0 then
                local definition=candidates[random:Integer(1,#candidates)]
                local enemy=parties:CreateRoaming(definition,cell,nil,random:Integer(0,0xffffffff))
                factions.conflicts:Begin(party,enemy,minute)
                return true
            end
        end
    end
    return false
end

function Ambushes.Advance(escort,record,party,minute,minutes)
    local travel=party.Travel
    -- Older accepted contracts begin their three checkpoints along the remaining route.
    if escort.story.data:GetValue(routeKey(record.Id))==0 then Ambushes.Start(escort,record,party) end
    local remaining=minutes
    while remaining>0 and travel.Active and party.BattleSiteId==0 do
        if Ambushes.Check(escort,record,party,minute-remaining) then break end
        local spent=travel:Step(remaining)
        assert(spent>0,'Escort failed to advance along its route')
        remaining=math.max(0,remaining-spent)
        if Ambushes.Check(escort,record,party,minute-remaining) then break end
    end
end
return Ambushes

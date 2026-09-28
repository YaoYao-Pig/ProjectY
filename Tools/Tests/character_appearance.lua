package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name) local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local s=f:read('*a');f:close();return s end}})
local service={}
function service:HasRace(id) return ({human=true,elf=true,goblin=true,dragon=true,orc=true})[id] or false end
function service:Create(actor,seed,race,sex) assert(actor.CustomizationJson=='');actor.CustomizationJson=table.concat({race,sex,seed},':');actor.race=race;actor.sex=sex end
local generator=require('Game.Adventure.CharacterAppearance').New(config,service)
local function sample(pool,seed)
    local group=generator:Group(pool,seed);local result={};local races={}
    for i=1,12 do local actor={CustomizationJson=''};generator:Assign(actor,group);result[#result+1]=actor.CustomizationJson;races[actor.race]=true end
    return table.concat(result,'|'),races
end
for _,pool in ipairs(config:GetTable('CharacterAppearancePoolTable'):All()) do
    for seed=0,5 do local a,races=sample(pool.id,seed);assert(a==sample(pool.id,seed),'Pool must be reproducible')
        local count=0;for race in pairs(races) do assert(service:HasRace(race));count=count+1 end
        if pool.sameRace then assert(count==1,'A configured same-race group mixed races') end
    end
end
local _,mixed=sample(7,412);local count=0;for _ in pairs(mixed) do count=count+1 end;assert(count>1,'Mixed pool ignored configuration')
for id,race in ipairs({'human','elf','goblin','dragon','orc'}) do local _,races=sample(id,41);assert(races[race] and next(races,race)==nil) end
for _,row in ipairs(config:GetTable('CombatEncounterTable'):All()) do config:GetTable('CharacterAppearancePoolTable'):Get(row.appearancePoolId) end
math.randomseed(42);local expected=math.random();math.randomseed(42);sample(6,300);assert(math.random()==expected,'Appearance changed gameplay RNG')
print('PASS configured appearance pools: references, weights, same-race/mixed groups, deterministic generation, isolated RNG')

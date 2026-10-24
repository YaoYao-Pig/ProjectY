-- Diplomacy and strategic scoring are pure queries. Mutable facts belong to WorldFactionsData.
local Rules={};Rules.__index=Rules
local function clamp(value,lo,hi) return math.max(lo,math.min(hi,value)) end
local function key(a,b) return math.min(a,b)..':'..math.max(a,b) end
function Rules.New(config)
    local self=setmetatable({policies=config:GetTable('WorldFactionTable'),relations={},
        settings=config:GetTable('WorldFactionRuleTable'):Get(1)},Rules)
    for _,row in ipairs(self.policies:All()) do
        config:GetTable('FactionTable'):Get(row.id)
        assert(row.role=='civilized' or row.role=='raider' or row.role=='guardian' or row.role=='wildlife' or row.role=='organization','Unknown faction role')
        if row.encounterId>0 then config:GetTable('CombatEncounterTable'):Get(row.encounterId) end
    end
    for _,row in ipairs(config:GetTable('WorldFactionRelationTable'):All()) do
        assert(row.first~=row.second,'Faction cannot override its own relationship')
        self.policies:Get(row.first);self.policies:Get(row.second)
        local pair=key(row.first,row.second);assert(not self.relations[pair],'Duplicate faction relationship')
        self.relations[pair]=row.value
    end
    return self
end
function Rules:Value(a,b,state,reputation)
    if a==b then return 100 end
    if a==0 or b==0 then
        local id=a==0 and b or a
        local policy=self.policies:Get(id)
        return clamp(policy.playerRelation+(reputation or 0),-100,100)
    end
    self.policies:Get(a);self.policies:Get(b)
    if state then local changed=state:FindRelation(a,b);if changed then return changed.Value end end
    local value=self.relations[key(a,b)]
    return value==nil and 0 or value
end
function Rules:Relation(a,b,state,reputation)
    local value=self:Value(a,b,state,reputation)
    if value<=self.settings.hostileThreshold then return 'hostile' end
    if value>=self.settings.alliedThreshold then return 'allied' end
    return 'neutral'
end
function Rules:Suitable(id,regionType)
    for _,kind in ipairs(self.policies:Get(id).regionTypes) do if kind==regionType then return true end end
    return false
end
function Rules:FullPower(actor,stats)
    local template=stats:Template(actor)
    local attack=math.max(stats:Get(actor,'strength'),stats:Get(actor,'intellect'));local defense=stats:Get(actor,'defense')
    return actor.MaxHP*.25+attack*2+defense+template.actionPoints*3
end
function Rules:Power(actor,stats)
    if actor.HP==0 then return 0 end
    return self:FullPower(actor,stats)*actor.HP/actor.MaxHP
end
-- A hard gate cannot be outweighed by loot. Comparable curves avoid counting an army twice.
function Rules:Score(input)
    assert(input.attack>=0 and input.defense>=0 and input.minutes>=0 and input.threat>=0,'Invalid strategy inputs')
    if not input.hostile or not input.reachable or input.cooldown or input.attack<=0 or input.reserve<input.minimumReserve then return 0,'行动条件不足' end
    local required=input.siege and self.settings.siegeAdvantage or self.settings.raidAdvantage
    local ratio=input.attack/math.max(1,input.defense)
    if ratio<required then return 0,'局部兵力不足' end
    if input.minutes>self.settings.maximumExpeditionMinutes then return 0,'超出行动范围' end
    local advantage=clamp((ratio-required+.5)/2,0,1)
    local reward=clamp(input.value/self.settings.rewardScale,.1,1)
    local distance=1/(1+input.minutes/self.settings.distanceScale)
    local safety=1/(1+input.threat/math.max(1,input.attack))
    return advantage*reward*distance*safety*(input.preference or 1),'优势 '..string.format('%.1f',ratio)..' 倍'
end
function Rules:Recovery(site,minute)
    if site.OccupierId>0 then return 0 end
    if site.LiberatedAt<0 then return 1 end
    return clamp(self.settings.recoveryInitial+(1-self.settings.recoveryInitial)*(minute-site.LiberatedAt)/self.settings.recoveryMinutes,self.settings.recoveryInitial,1)
end
return Rules

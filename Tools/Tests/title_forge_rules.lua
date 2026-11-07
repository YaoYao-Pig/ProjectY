-- Real exported tables; isolated state adapters. No Editor or live saves.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local ts,rep={},{}
CS={ProjectY={Data={TitleState=ts,ReputationState=rep}}}
function ts.ValidName(name)return type(name)=='string' and name:find('%S')~=nil and utf8.len(name)~=nil and utf8.len(name)<=16 and not name:find('[<>%c]')end
function ts.NormalizeName(name)return name:match('^%s*(.-)%s*$')end
function ts.Equipped(a)return a.equipped end
function ts.Count(a)return #a.owned end
function ts.At(a,i)return a.owned[i+1]end
function ts.CustomCount(a)return #a.custom end
function ts.CustomAt(a,i)return -(i+1)end
function ts.CustomName(a,id)return a.custom[-id].name end
function ts.CustomCost(a,id)return a.custom[-id].cost end
function ts.EffectCount(a,id)return #a.custom[-id].effects end
function ts.EffectIdAt(a,id,i)return a.custom[-id].effects[i+1].id end
function ts.EffectRankAt(a,id,i)return a.custom[-id].effects[i+1].rank end
function ts.Owns(a,id)if id<0 then return a.custom[-id]~=nil end;for _,v in ipairs(a.owned)do if v==id then return true end end;return false end
function ts.Equip(a,id)assert(id==0 or ts.Owns(a,id));a.equipped=id end
function ts.Counter(a,key)return a.counters[key] or 0 end
function ts.Increment(a,key)a.counters[key]=ts.Counter(a,key)+1 end
function ts.Award(a,id)a.owned[#a.owned+1]=id end
function ts.RecordSettlement(a,kind,id)local key=kind..':'..id;if a.receipts[key]then return false end;a.receipts[key]=true;return true end
function rep.Balance(data)return data.balance end
function rep.BeginBattle(data)data.kills={}end
function rep.AwardKill(data,id,amount)if data.kills[id]then return false end;data.kills[id]=true;data.balance=data.balance+amount;return true end
function rep.AwardSettlement(data,kind,id)local key=kind..':'..id;if data.receipts[key]then return false end;data.receipts[key]=true;data.balance=data.balance+(kind=='mission' and 60 or 30);return true end
function ts.Craft(data,a,name,effects,cost)
    if cost>data.balance then return 0 end
    local entry={name=name,cost=cost,effects={}}
    for id,rank in effects:gmatch('(%d+):(%d+)')do entry.effects[#entry.effects+1]={id=tonumber(id),rank=tonumber(rank)}end
    data.balance=data.balance-cost;a.custom[#a.custom+1]=entry;return -#a.custom
end
local rules=require('Game.Progression.TitleRules').New(config)
local function actor(id)return {Id=id,Team=1,equipped=0,owned={},custom={},counters={},receipts={},SetMaxHP=function()end}end
local first,second=actor(1),actor(2)
local data={Phase='map',PartyCount=2,balance=300,kills={},receipts={},GetPartyAt=function(_,i)return i==0 and first or second end,PartyBonds={RescueCount=function()return 0 end}}
local adventure={data=data,battle={IsHostile=function(_,_,target)return target.Team~=1 end,stats={titles=rules,MaximumHP=function()return 100 end,spellcasting={Sync=function()end}}},sites={},
    parties={legends={byUnit={[100]={id=1}}}},growth={chronicle={Record=function()end}}}
local model=require('Game.Progression.Titles').New(adventure)
local quote=model:Quote('饮血的孤狼',{[4]=3,[101]=3,[102]=1,[103]=1})
assert(quote.valid and quote.cost==235 and quote.positive==235)
assert(model:Quote('test',{[101]=1,[201]=3,[202]=3}).cost==15,'Negative rebate must stop at 50 percent')
assert(not model:Quote('test',{[201]=1}).valid,'Negative-only title must not mint reputation')
for _,draft in ipairs({{[4]=6},{[4]=-1},{[4]=.5},{[9999]=1},{[4]=math.huge},{['4']=1}})do assert(not model:Quote('test',draft).valid)end
assert(not model:Quote('<b>x</b>',{[4]=1}).valid)
assert(not model:Quote('',{[4]=1}).valid)
local balance=data.balance
assert(not model:Craft(999,'test',{[4]=1}) and data.balance==balance)
data.Phase='battle';assert(not model:Craft(1,'test',{[4]=1}) and data.balance==balance);data.Phase='map'
local ok,_,id=model:Craft(1,'饮血的孤狼',{[4]=3,[101]=3,[102]=1,[103]=1})
assert(ok and id<0 and data.balance==65 and ts.Equipped(first)==0 and not ts.Owns(second,id))
assert(model:Equip(1,id) and rules:Bonus(first,'strength')==3 and rules:Effect(first,'kill_heal_percent')==3)
assert(rules:Equipped(first).damagePercent==15 and rules:Effect(first,'kill_morale')==5)
assert(not model:Equip(2,id));assert(model:Equip(1,0) and data.balance==65 and rules:Bonus(first,'strength')==0)
assert(not model:Craft(2,'too expensive',{[105]=3}) and data.balance==65 and #second.custom==0)
-- Every registered attribute can be purchased and reaches the normal bonus path.
data.balance=10000;local all={}
for _,row in ipairs(config:GetTable('TitleForgeEffectTable'):All())do if row.kind=='attribute' and not row.negative then all[row.id]=1 end end
ok,_,id=model:Craft(2,'全属性',all);assert(ok);assert(model:Equip(2,id))
local count=0;for _,row in ipairs(config:GetTable('GrowthAttributeTable'):All())do count=count+1;assert(rules:Bonus(second,row.code)==1,row.code)end
assert(count==20 and #rules:Rows(second,data.PartyBonds)==11)
-- Team rewards do not scale with party size; stages do not double-pay missions.
balance=data.balance
assert(model:Complete('mission',1)==60 and data.balance==balance+60)
assert(model:Complete('mission',1)==0 and data.balance==balance+60)
assert(model:Complete('quest',1)==0 and data.balance==balance+60)
assert(model:Complete('town',101,1)==30 and model:Complete('town',101,1)==0)
assert(model:Complete('town',102,1)==30 and data.balance==balance+120)
model:RewardKill(first,{Id=10,TemplateId=10});model:RewardKill(second,{Id=10,TemplateId=10})
assert(data.balance==balance+122)
model:RewardKill(second,{Id=11,TemplateId=100});assert(data.balance==balance+172)
model:RewardKill(first,{Id=12,TemplateId=10,Team=1});first.Team=2
model:RewardKill(first,{Id=13,TemplateId=10,Team=2});assert(data.balance==balance+172,'Allied targets and non-player allegiance must not award team reputation')
print('PASS title forge: real prices, all 20 attributes, invalid drafts, 50% cap, shared spend, ownership, equip, no refund and team reward deduplication')

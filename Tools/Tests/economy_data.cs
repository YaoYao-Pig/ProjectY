// Execute in an existing idle Editor; isolated Data only, no gameplay/save files.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.InvalidOperationException("Idle Edit Mode required");
System.Action<bool,string> Check=(value,message)=>{if(!value)throw new System.Exception(message);};
System.Func<ProjectY.Data.EconomyRules> Rules=()=>new ProjectY.Data.EconomyRules{foodBase=2,foodLevelStep=5,wageBase=2,wagePerLevel=2,animalFoodBase=3,
    termDays=7,investmentLimit=1000,maximumLossPercent=30,maximumGainPercent=15,historyDays=60,marketTarget=80,marketCapacity=320,
    sellMultiplier=.8,hungerPenalty=.05,debtPenalty=.03,maximumPenalty=.4,foodItems=new[]{9100,9101}};
System.Func<ProjectY.Data.TownEconomyData> Economy=()=>
{
    var e=new ProjectY.Data.TownEconomyData();e.Configure(Rules());e.Initialize(0);e.AddTown(1,.5,new[]{9100,81},new[]{4,3},new[]{1.0,.1});
    e.AddTown(2,.5,new[]{9100,81},new[]{4,3},new[]{.1,1.0});return e;
};
System.Func<ProjectY.Data.EquipmentData> Bag=()=>
{var e=new ProjectY.Data.EquipmentData();e.Grid.Define(9100,1,1);e.Grid.Define(9101,1,1);e.Grid.Define(81,1,1);e.Grid.Configure(4,4);return e;};
var data=Economy();var bag=Bag();var player=new ProjectY.Data.PlayerData();player.AddCoins(2000);
Check(data.UnitPrice(1,9100,true)<data.UnitPrice(2,9100,true),"Regional food prices do not differ");
int before=player.Coins,revision=data.Revision;int quote=data.Quote(1,9100,20,true);
Check(data.Trade(1,9100,20,true,revision,bag,player)=="" && player.Coins==before-quote && bag.CountItem(9100)==20,"Quoted batch purchase failed");
Check(data.Trade(1,9100,20,true,revision,bag,player)=="EconomyStale","Stale trade was replayed");
Check(data.Quote(1,9100,20,false)<quote,"Same-market round trip generated coins");
int coins=player.Coins,stock=data.FindTown(1).FindGood(9100).Stock;
Check(data.Trade(1,9100,1000,true,data.Revision,bag,player)=="EconomyStockMissing" && player.Coins==coins && data.FindTown(1).FindGood(9100).Stock==stock,"Failed purchase mutated state");
data.OpenBank(1,1);revision=data.Revision;
Check(data.Invest(500,revision,0,player)=="","Investment failed");
Check(data.Invest(500,revision,0,player)=="EconomyStale","Stale investment was replayed");
Check(data.Claim(data.Revision,player)=="EconomyNotMature","Investment matured early");
data.CloseBank();
var ids=new[]{1,2,101};var food=new[]{2,2,3};var wages=new[]{0,4,0};var empty=System.Array.Empty<int>();
for(int tick=1;tick<=3;tick++)data.Step(tick,77,empty,ids,food,wages,bag,player);
Check(bag.CountItem(9100)==20,"Food charged before midnight");
coins=player.Coins;data.Step(4,77,empty,ids,food,wages,bag,player);
Check(bag.CountItem(9100)==13 && player.Coins==coins-4 && data.LastFoodUsed==7,"Human/animal midnight upkeep incorrect");
for(int tick=5;tick<=28;tick++)data.Step(tick,77,new[]{1},ids,food,wages,bag,player);
var town=data.FindTown(1);Check(town.Payout>=350 && town.Payout<=575,"Investment loss bounds failed");
Check(town.Payout<500,"Blocked town did not produce loss in deterministic fixture");
Check(data.FindAccount(101).HungryDays>0 && data.FindAccount(101).Arrears==0,"Animal upkeep did not accumulate hunger only");
Check(data.Penalty(101)>0 && data.Penalty(101)<=.4,"Upkeep penalty bounds failed");
for(int i=0;i<town.CandleCount;i++){var c=town.GetCandleAt(i);Check(c.Low<=System.Math.Min(c.Open,c.Close) && c.High>=System.Math.Max(c.Open,c.Close),"OHLC invariant failed");}
data.OpenBank(1,1);int payout=town.Payout;coins=player.Coins;revision=data.Revision;
Check(data.Claim(revision,player)=="" && player.Coins==coins+payout,"Mature claim failed");
Check(data.Claim(revision,player)=="EconomyStale","Duplicate claim paid twice");data.CloseBank();
var debt=Economy();var poor=new ProjectY.Data.PlayerData();var hungry=Bag();
for(int tick=1;tick<=8;tick++)debt.Step(tick,77,empty,ids,food,wages,hungry,poor);
Check(debt.TotalArrears==8 && debt.FindAccount(2).HungryDays==2,"Missed upkeep not accumulated");
poor.AddCoins(5);Check(debt.PayArrears(debt.Revision,poor)=="" && debt.TotalArrears==3 && poor.Coins==0,"Partial arrears payment failed");
// Round-trip the actual save DTO via the production capture/prepare methods, then advance both copies.
var flags=System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Static;
var capture=typeof(ProjectY.Data.TownEconomyData).GetMethod("Capture",flags);var prepare=typeof(ProjectY.Data.TownEconomyData).GetMethod("Prepare",flags);
object saved=capture.Invoke(data,null);string json=JsonUtility.ToJson(saved);object decoded=JsonUtility.FromJson(json,saved.GetType());
var restored=(ProjectY.Data.TownEconomyData)prepare.Invoke(null,new object[]{decoded,28*360.0});restored.Configure(Rules());
Check(restored.LastTick==data.LastTick && restored.FindTown(1).NetValue==data.FindTown(1).NetValue && restored.ActiveBankSite==0,"Saved economy did not restore");
var otherBag=Bag();var otherPlayer=new ProjectY.Data.PlayerData();otherPlayer.AddCoins(player.Coins);
data.Step(29,77,empty,empty,empty,empty,bag,player);restored.Step(29,77,empty,empty,empty,empty,otherBag,otherPlayer);
Check(data.FindTown(1).NetValue==restored.FindTown(1).NetValue && data.FindTown(1).CandleCount==restored.FindTown(1).CandleCount,"Load rerolled investment price");
return "PASS regional prices, batch quotes, failed/stale trades, human/animal daily upkeep, hunger/debt, risk/loss, maturity, duplicate claim, OHLC and save determinism";

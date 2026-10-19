// Bounded live-scene acceptance. Run via Unity MCP after the LuaConsole learning/catalyst step.
if(!UnityEditor.EditorApplication.isPlaying || ProjectY.GameBootstrap.Instance==null)throw new System.Exception("A ready controlled Play session is required");
var demo=UnityEngine.Object.FindObjectOfType<ProjectY.Samples.AdventureRuntimeDemo>();
var bootstrap=ProjectY.GameBootstrap.Instance;
if(demo==null || demo.Phase!="map")throw new System.Exception("Fresh map phase required");
demo.SetBattleAutoAI(false);
demo.SendCommand("visit",2);
if(demo.Phase!="event" || !string.IsNullOrEmpty(demo.LastError))throw new System.Exception("Visit failed: "+demo.LastError);
demo.SendCommand("choose",1);
if(demo.Phase!="battle" || !string.IsNullOrEmpty(demo.LastError))throw new System.Exception("Encounter failed: "+demo.LastError);
System.Func<ProjectY.Samples.AdventureViewData> snapshot=()=>{
    using(var value=(XLua.LuaTable)bootstrap.CallModule("Game.Adventure.DemoBridge","snapshot")[0])
        return ProjectY.Samples.AdventureViewData.Read(value);
};
var initial=snapshot();
if(initial.Round!=0 || initial.ActiveId!=2)throw new System.Exception("Deployment did not start with the ranger");
var path="Docs/Previews/GameplayFoundation/play-battle.txt";
System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path));
System.IO.File.WriteAllText(path,"RUNNING controlled real-scene deployment and combat");
var start=UnityEditor.EditorApplication.timeSinceStartup;
double next=start+.5;
int commands=0;
bool preparation=false,item=false,roundOne=false;
UnityEditor.EditorApplication.CallbackFunction tick=null;
System.Action<string> finish=message=>{
    UnityEditor.EditorApplication.update-=tick;
    System.IO.File.WriteAllText(path,message+"\ncommands="+commands+"\nseconds="+(UnityEditor.EditorApplication.timeSinceStartup-start).ToString("F2"));
};
tick=()=>{
    if(UnityEditor.EditorApplication.timeSinceStartup<next)return;
    next=UnityEditor.EditorApplication.timeSinceStartup+.45;
    try {
        if(!UnityEditor.EditorApplication.isPlaying || ProjectY.GameBootstrap.Instance!=bootstrap){finish("FAIL Play session changed");return;}
        if(UnityEditor.EditorApplication.timeSinceStartup-start>150 || commands>240){finish("FAIL bounded scene run timed out");return;}
        if(!string.IsNullOrEmpty(demo.LastError)){finish("FAIL scene command: "+demo.LastError);return;}
        var state=snapshot();
        if(state.Phase!="battle"){
            if(state.Phase=="area" && state.Area!=null && state.Area.ClearedEncounters>0 && preparation && item && roundOne)
                finish("PASS real scene: encounter -> AP deployment -> preparation -> consumable -> round 1 -> command combat -> victory/loot; coins="+state.Coins);
            else finish("FAIL unexpected final phase "+state.Phase+" preparations="+preparation+" item="+item+" roundOne="+roundOne);
            return;
        }
        var active=System.Array.Find(state.Units,u=>u.Id==state.ActiveId);
        if(active==null)throw new System.Exception("Missing active actor");
        if(state.Round==0){
            if(active.Id==2 && !preparation){
                int ap=active.AP;demo.SelectBattleSkill(402);demo.SendCommand("skill",402,active.Id);commands++;
                preparation=System.Array.Find(snapshot().Units,u=>u.Id==active.Id).AP==ap-2;
                return;
            }
            if(active.Id==2 && !item){
                int ap=active.AP;demo.SendCommand("use_item",92);commands++;
                item=System.Array.Find(snapshot().Units,u=>u.Id==active.Id).AP==ap-1;
                return;
            }
            if(!active.MainUsed){
                ProjectY.Samples.AdventureViewData.Skill ready=null;
                foreach(var skill in state.Skills)if(skill.Id>=401 && skill.Id<=404 && System.Array.IndexOf(skill.Targets,active.Id)>=0){ready=skill;break;}
                if(ready!=null){demo.SelectBattleSkill(ready.Id);demo.SendCommand("skill",ready.Id,active.Id);commands++;return;}
            }
            demo.SendCommand("end_turn");commands++;return;
        }
        if(!roundOne){
            if(state.Round!=1 || active.Id!=2 || active.AP!=4)throw new System.Exception("Round one did not refill the prepared ranger");
            roundOne=true;
        }
        if(active.Team==2){demo.SendCommand("ai");commands++;return;}
        if(!active.MainUsed){
            foreach(var skill in state.Skills)foreach(var targetId in skill.Targets){
                var target=System.Array.Find(state.Units,u=>u.Id==targetId);
                if(target!=null && target.Team==2 && target.HP>0){demo.SelectBattleSkill(skill.Id);demo.SendCommand("skill",skill.Id,targetId);commands++;return;}
            }
            if(!active.Moved){
                ProjectY.Samples.AdventureViewData.Cell best=null;int score=int.MaxValue;
                foreach(var cell in state.Reachable)foreach(var target in state.Units)if(target.Team==2 && target.HP>0){
                    int dq=cell.Q-target.Q,dr=cell.R-target.R;int distance=(System.Math.Abs(dq)+System.Math.Abs(dr)+System.Math.Abs(dq+dr))/2;
                    if(distance<score){best=cell;score=distance;}
                }
                if(best!=null){demo.SendCommand("move",best.Q,best.R);commands++;return;}
            }
        }
        demo.SendCommand("end_turn");commands++;
    }
    catch(System.Exception error){finish("FAIL "+error.ToString());}
};
UnityEditor.EditorApplication.update+=tick;
return "Started bounded real-scene acceptance; inspect "+path;

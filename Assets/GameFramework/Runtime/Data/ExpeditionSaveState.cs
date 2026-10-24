using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    [Serializable] internal sealed class ExpeditionSave
    {
        public int recipeId, targetCells, activeSite;
        public int[] visited; public string[] triggers;
        public AreaSave[] areas; public TravelSave travel; public WorldPartiesSave parties;
        public WorldFogSave worldFog;
        public ConstructionSave[] constructions; public ObstacleSiteSave[] obstacles;
    }
    [Serializable] internal sealed class AreaSave
    {
        public int site, definition, cells, anchor, worldRound;
        public double roundElapsed;
        public int[] known, visible, members, positions;
        public NpcSave[] npcs; public EncounterSave[] encounters; public ContainerSave[] loot;
        public bool encountersReady, lootReady;
    }
    [Serializable] internal sealed class NpcSave { public int id, cell, cursor; public float elapsed; public bool present; }
    [Serializable] internal sealed class EncounterSave { public int id, definition, partyId; public bool detached; public EnemySave[] actors; }
    [Serializable] internal sealed class EnemySave
    {
        public int id, template, hp, maxHP, team, q, r, species, owner, bond, retry;
        public uint random; public bool drop; public string appearance;
        public int[] traits; public GameEffectSave[] effects; public BodyInjurySave[] injuries;
    }
    [Serializable] internal sealed class ContainerSave
    {
        public int cell, table, durability, maximum, encounter, rotation, width, height;
        public string name; public bool ready, looted, opened, searched, configured, breaking, unlocked;
        public int[] cells, items, counts; public LootSave[] search; public PlacementSave[] placements;
    }
    [Serializable] internal sealed class LootSave
    {
        public int source, item, count; public string kind; public bool revealed; public float progress;
        public WeaponSave weapon; public WearableSave wearable; public MagazineSave magazine, loaded;
    }
    [Serializable] internal sealed class TravelSave
    {
        public int q, r, target, firstStop, speed; public uint random;
        public double elapsed, sinceCheck; public bool paused;
        public TravelStepSave[] route; public TravelStopSave[] stops;
    }
    [Serializable] internal sealed class TravelStepSave { public int q, r; public double minutes; }
    [Serializable] internal sealed class TravelStopSave { public int id, q, r, eventId, encounter; }
    [Serializable] internal sealed class ConstructionSave { public int site, cell, skill, hp, maximum, ownerTeam; public bool removed; public int[] paidMaterialIds,paidMaterialCounts; }
    [Serializable] internal sealed class ObstacleSiteSave { public int site; public ObstacleSave[] rows; }
    [Serializable] internal sealed class ObstacleSave { public int rule, attempts; public bool blocks, cleared; public int[] cells, items, counts; }

    /// <summary>Reflection bridge for the complete, validated exploration save; no generated wrappers are edited.</summary>
    public static class ExpeditionPersistence
    {
        public static uint RandomSeed() { var bytes=Guid.NewGuid().ToByteArray();return BitConverter.ToUInt32(bytes,0); }
        public static void Configure(AdventureData adventure, ConstructionData construction, MapObstacleData obstacles, int recipe, int target)
        {
            if(recipe<1 || target<0 || target>100000)throw new ArgumentOutOfRangeException(nameof(target));
            adventure.ExpeditionRecipe=recipe;adventure.ExpeditionTarget=target;
            adventure.ExpeditionConstruction=construction;adventure.ExpeditionObstacles=obstacles;
        }
        public static void Definition(MapAreaStateData area,int definition) { if(definition<1)throw new ArgumentOutOfRangeException(nameof(definition));area.SavedDefinition=definition; }
        public static int Recipe(PreparedCharacterSave save) => save.Expedition?.recipeId ?? 1;
        public static int Target(PreparedCharacterSave save) => save.Expedition?.targetCells ?? 0;
        public static int AreaCount(PreparedCharacterSave save) => save.Expedition?.areas.Length ?? 0;
        public static int AreaSite(PreparedCharacterSave save,int index) => save.Expedition.areas[index].site;
        public static int AreaDefinition(PreparedCharacterSave save,int index) => save.Expedition.areas[index].definition;
        public static int AreaCells(PreparedCharacterSave save,int index) => save.Expedition.areas[index].cells;
        public static int AreaEncounter(PreparedCharacterSave save,int index) => save.Expedition.areas[index].encounters.First().definition;
        public static MapAreaStateData Area(PreparedCharacterSave save,int index) => save.PreparedAreas[index];
        public static WorldTravelData Travel(PreparedCharacterSave save) => save.PreparedTravel;
        public static bool HasWorld(PreparedCharacterSave save) => save.Expedition!=null;
        public static int GroundCount(MapAreaLootData container)=>container.SearchItems?.Length ?? 0;
        public static EquipmentWeaponData GroundWeapon(MapAreaLootData container,int index)=>container.SearchItems[index].StoredWeapon;
        public static EquipmentWearableData GroundWearable(MapAreaLootData container,int index)=>container.SearchItems[index].StoredWearable;
        public static EquipmentMagazineData GroundMagazine(MapAreaLootData container,int index,bool loaded)=>loaded?container.SearchItems[index].LoadedMagazine:container.SearchItems[index].StoredMagazine;
        public static void ValidateSites(PreparedCharacterSave save,int baseCount,int totalCount)
        {
            if(save.Expedition==null)return;
            SaveCheck.Require(save.Expedition.travel.firstStop==baseCount+1 && save.Expedition.visited.All(id=>id<=totalCount),"访问地点与地图不一致");
        }
        public static int CurrentTarget(AdventureData adventure) => adventure.ExpeditionTarget;
        public static void ResetProfile(PlayerData player,int coins) => player.RestoreProfile(coins,1);
        internal static ExpeditionSave Capture(AdventureData adventure)
        {
            if(adventure.ExpeditionConstruction==null || adventure.ExpeditionObstacles==null)return null;
            return new ExpeditionSave { recipeId=adventure.ExpeditionRecipe,targetCells=adventure.ExpeditionTarget,
                activeSite=adventure.Areas.ActiveSiteId,visited=adventure.CaptureVisited(),triggers=adventure.CaptureTriggers(),
                areas=adventure.Areas.Capture(),travel=adventure.Travel.Capture(),parties=adventure.WorldParties.Capture(),worldFog=adventure.WorldExploration.Capture(),
                constructions=adventure.ExpeditionConstruction.Capture(),obstacles=adventure.ExpeditionObstacles.Capture() };
        }
        internal static void Prepare(PreparedCharacterSave prepared, ExpeditionSave saved, EquipmentData definitions, CharacterAppearanceService appearances, HashSet<int> owners)
        {
            SaveCheck.Require(saved!=null && saved.recipeId>0 && saved.targetCells>=0 && saved.targetCells<=100000,"远征参数");
            SaveCheck.PositiveIds(saved.visited,"访问地点");SaveCheck.Rows(saved.triggers,100000,"故事触发");
            SaveCheck.Require(saved.triggers.All(s=>!string.IsNullOrEmpty(s)) && saved.triggers.Distinct().Count()==saved.triggers.Length,"重复故事触发");
            var rows=SaveCheck.Rows(saved.areas,10000,"探索地点");
            var sites=new HashSet<int>(); var itemIds=new HashSet<int>();
            prepared.PreparedWorldParties=WorldPartiesData.Prepare(saved.parties,definitions,itemIds,appearances,owners);
            var attachedParties=new HashSet<int>();
            prepared.PreparedAreas=rows.Select(row=>MapAreaStateData.Prepare(row,definitions,appearances,owners,itemIds,prepared.PreparedWorldParties,attachedParties)).ToArray();
            foreach(var area in prepared.PreparedAreas)for(int i=0;i<area.EncounterCount;i++)for(int j=0;j<area.GetEncounterAt(i).EnemyCount;j++)
            {
                var animal=area.GetEncounterAt(i).GetEnemyAt(j);if(animal.AnimalOwnerId==0)continue;
                var rider=prepared.Actors?.FirstOrDefault(a=>a.Id==animal.AnimalOwnerId);
                SaveCheck.Require(rider!=null,"驯服动物的主人不在队伍");
                if(rider.BoundAnimal?.Id==animal.Id)rider.ReconnectMount(animal);
            }
            foreach(var row in rows)SaveCheck.Require(sites.Add(row.site),"重复探索地点");
            SaveCheck.Require(saved.activeSite==0 || sites.Contains(saved.activeSite),"活动地点");
            prepared.PreparedTravel=WorldTravelData.Prepare(saved.travel);
            prepared.PreparedWorldFog=WorldMapExplorationData.Prepare(saved.worldFog);
            prepared.PreparedWorldParties.ValidateWorldReferences(saved.travel.firstStop,checked(saved.travel.firstStop+saved.travel.stops.Length-1),sites);
            prepared.PreparedConstruction=ConstructionData.Prepare(saved.constructions,prepared.PreparedAreas);
            prepared.PreparedObstacles=MapObstacleData.Prepare(saved.obstacles,prepared.PreparedAreas);
            prepared.Expedition=saved;
        }
        internal static void Apply(PreparedCharacterSave prepared,AdventureData adventure)
        {
            if(prepared.Expedition==null)return;
            var saved=prepared.Expedition;
            adventure.Areas.TakePrepared(prepared.PreparedAreas,saved.activeSite);
            adventure.Travel.TakePrepared(prepared.PreparedTravel);
            adventure.WorldExploration.TakePrepared(prepared.PreparedWorldFog);
            adventure.WorldParties.TakePrepared(prepared.PreparedWorldParties);
            adventure.ExpeditionConstruction.TakePrepared(prepared.PreparedConstruction);
            adventure.ExpeditionObstacles.TakePrepared(prepared.PreparedObstacles);
            adventure.RestoreExploration(saved);
            // Encounter-owned equipment survives loading even when an actor has been disarmed.
            adventure.Equipment.RestoreCombatOwners(prepared.PreparedAreas);
            adventure.Equipment.RestorePartyCombatOwners(adventure.WorldParties);
        }
        internal static void ValidateEquipmentIds(PreparedCharacterSave prepared,EquipmentSave equipment)
        {
            var ids=new HashSet<int>(equipment.weapons.Select(i=>i.id).Concat(equipment.wearables.Select(i=>i.id)).Concat(equipment.magazines.Select(i=>i.id)));
            for(int i=0;i<prepared.PreparedWorldParties.Count;i++)
            {
                var party=prepared.PreparedWorldParties.GetAt(i);
                for(int j=0;j<party.CargoCount;j++)
                {
                    var item=party.GetCargoAt(j);
                    foreach(int id in new[]{item.StoredWeapon?.Id??0,item.StoredWearable?.Id??0,item.StoredMagazine?.Id??0,item.LoadedMagazine?.Id??0})
                        if(id!=0)SaveCheck.Require(id<equipment.nextId && ids.Add(id),"商队装备实例重复或序号越界");
                }
            }
            var factions=prepared.PreparedWorldParties.Factions;
            for(int i=0;i<factions.ConflictCount;i++)
            {
                var conflict=factions.GetConflictAt(i);
                for(int j=0;j<conflict.PendingCargoCount;j++)
                    foreach(var item in conflict.GetPendingCargoAt(j).SearchItems)
                        foreach(int id in new[]{item.StoredWeapon?.Id??0,item.StoredWearable?.Id??0,item.StoredMagazine?.Id??0,item.LoadedMagazine?.Id??0})
                            if(id!=0)SaveCheck.Require(id<equipment.nextId && ids.Add(id),"抽象战场装备实例重复或序号越界");
            }
            foreach(var area in prepared.PreparedAreas)for(int i=0;i<area.LootCount;i++)
            {
                var container=area.GetLootAt(i);if(container.SearchItems==null)continue;
                foreach(var item in container.SearchItems)foreach(int id in new[]{item.StoredWeapon?.Id??0,item.StoredWearable?.Id??0,item.StoredMagazine?.Id??0,item.LoadedMagazine?.Id??0})
                    if(id!=0)SaveCheck.Require(id<equipment.nextId && ids.Add(id),"地面装备实例重复或序号越界");
            }
        }
    }
    public sealed partial class AdventureData
    {
        internal int ExpeditionRecipe=1, ExpeditionTarget;
        internal ConstructionData ExpeditionConstruction; internal MapObstacleData ExpeditionObstacles;
        internal int[] CaptureVisited()=>visited.OrderBy(x=>x).ToArray();
        internal string[] CaptureTriggers()=>storyTriggers.OrderBy(x=>x,StringComparer.Ordinal).ToArray();
        internal void RestoreExploration(ExpeditionSave saved)
        {
            visited.Clear();visited.UnionWith(saved.visited);storyTriggers.Clear();storyTriggers.UnionWith(saved.triggers);
            SiteId=saved.activeSite;Phase=SiteId==0?"map":"area";ResultText="已继续远征 · 探索与战利品状态已恢复";
        }
    }
    public sealed partial class MapAreaData
    {
        internal AreaSave[] Capture()=>areas.Values.OrderBy(a=>a.SiteId).Select(a=>a.Capture()).ToArray();
        internal void TakePrepared(MapAreaStateData[] saved,int active)
        { areas.Clear();foreach(var row in saved)areas.Add(row.SiteId,row);ActiveSiteId=active; }
    }
    public sealed partial class MapAreaStateData
    {
        internal int SavedDefinition;
        internal AreaSave Capture()=>new AreaSave {site=SiteId,definition=SavedDefinition,cells=CellCount,anchor=CellIndex,
            worldRound=WorldRound,roundElapsed=explorationRoundElapsed,known=discovered.ToArray(),visible=visible,
            members=memberIds,positions=memberCells,npcs=npcs.Select(n=>n.Capture()).ToArray(),
            encounters=encounters.Select(g=>g.Capture()).ToArray(),loot=loot.Select(l=>l.Capture()).ToArray(),
            encountersReady=EncountersInitialized,lootReady=LootInitialized};
        internal static MapAreaStateData Prepare(AreaSave row,EquipmentData definitions,CharacterAppearanceService appearances,HashSet<int> owners,HashSet<int> itemIds,WorldPartiesData parties,HashSet<int> attachedParties)
        {
            SaveCheck.Require(row!=null && row.site>0 && row.definition>0 && row.cells>0 && row.cells<=1000000 && row.anchor>0 && row.anchor<=row.cells && row.worldRound>=0 &&
                !double.IsNaN(row.roundElapsed) && !double.IsInfinity(row.roundElapsed) && row.roundElapsed>=0,"探索区域");
            var state=new MapAreaStateData(row.site,row.cells,row.anchor){SavedDefinition=row.definition,WorldRound=row.worldRound,explorationRoundElapsed=row.roundElapsed};
            SaveCheck.Rows(row.known,row.cells,"已探索格");SaveCheck.Rows(row.visible,row.cells,"可见格");
            SaveCheck.Require(row.known.Distinct().Count()==row.known.Length && row.visible.All(row.known.Contains),"可见区域必须已探索");
            state.Reveal(row.known);state.Reveal(row.visible);
            foreach(var npc in SaveCheck.Rows(row.npcs,10000,"居民"))
            { SaveCheck.Require(npc!=null && npc.id==state.npcs.Count+1 && npc.cell>0 && npc.cell<=row.cells && npc.cursor>=0 && !float.IsNaN(npc.elapsed) && !float.IsInfinity(npc.elapsed),"居民位置");state.npcs.Add(MapAreaNpcData.Prepare(npc)); }
            SaveCheck.Rows(row.members,4,"队员位置");SaveCheck.Rows(row.positions,4,"队员位置");
            SaveCheck.Require(row.members.Length==row.positions.Length,"队员位置数量");
            // An inactive location may still remember a former squad, including a recruited actor.
            if(row.members.Length>0)state.DeployMembers(row.members,row.positions);
            SaveCheck.Require(state.CellIndex==row.anchor,"队伍锚点");
            foreach(var group in SaveCheck.Rows(row.encounters,10000,"敌群"))
            {
                SaveCheck.Require(group!=null && group.id==state.encounters.Count+1 && group.definition>0,"敌群编号");
                var next=state.AddEncounter(group.id,group.definition);
                var enemies=SaveCheck.Rows(group.actors,4,"敌群角色");
                SaveCheck.Require(group.partyId>=0 && (group.partyId>0 || !group.detached),"敌群队伍身份");
                if(group.partyId>0)
                {
                    var party=parties.Find(group.partyId);
                    SaveCheck.Require(party!=null && enemies.Length==0 && !parties.LegacyFactions,"敌群队伍引用");
                    if(group.detached)next.PrepareDetachedParty(party.Id);
                    else
                    {
                        SaveCheck.Require(party.BattleSiteId==row.site && attachedParties.Add(party.Id),"敌群队伍战场归属");
                        next.AttachParty(party);
                    }
                }
                else
                {
                    foreach(var enemy in enemies)next.AddPreparedEnemy(CombatActorData.PrepareEnemy(enemy,appearances,owners));
                    SaveCheck.Require(next.EnemyCount>0,"空敌群");
                }
            }
            SaveCheck.Require(row.encountersReady && row.lootReady,"尚未初始化的探索记录");
            state.EncountersInitialized=true;state.LootInitialized=true;
            foreach(var saved in SaveCheck.Rows(row.loot,10000,"容器"))state.loot.Add(MapAreaLootData.Prepare(saved,state.loot.Count+1,row.cells,definitions,itemIds));
            foreach(var container in state.loot)SaveCheck.Require(container.Physical.UnlockEncounterId<=state.EncounterCount,"容器守卫");
            return state;
        }
    }
    public sealed partial class MapAreaNpcData
    {
        internal NpcSave Capture()=>new NpcSave{id=Id,cell=CellIndex,cursor=PatrolCursor,elapsed=elapsed,present=Present};
        internal static MapAreaNpcData Prepare(NpcSave row)=>new MapAreaNpcData(row.id,row.cell){PatrolCursor=row.cursor,elapsed=row.elapsed,Present=row.present};
    }
    public sealed partial class MapAreaEncounterData
    {
        internal void AddPreparedEnemy(CombatActorData actor)=>enemies.Add(actor);
        internal EncounterSave Capture()=>new EncounterSave{id=Id,definition=EncounterId,partyId=PartyId,detached=Detached,
            actors=PartyId==0?enemies.Select(a=>a.CaptureEnemy()).ToArray():Array.Empty<EnemySave>()};
    }
    public sealed partial class CombatActorData
    {
        internal void ReconnectMount(CombatActorData animal)
        {SaveCheck.Require(BoundAnimal!=null && BoundAnimal.TemplateId==animal.TemplateId && BoundAnimal.HP==animal.HP && BoundAnimal.MaxHP==animal.MaxHP,"坐骑与探索动物不一致");boundAnimal=animal;animal.IndependentAnimal=animalCompanion;}
        internal EnemySave CaptureEnemy()=>new EnemySave{id=Id,template=TemplateId,hp=HP,maxHP=MaxHP,team=Team,q=Q,r=R,
            species=AnimalSpeciesId,owner=AnimalOwnerId,bond=AnimalBond,retry=TameRetryTurns,random=animalRandom,drop=DropResolved,
            appearance=CustomizationJson,traits=traits.ToArray(),effects=Effects.Capture(),injuries=CaptureBody()};
        internal static CombatActorData PrepareEnemy(EnemySave row,CharacterAppearanceService appearances,HashSet<int> owners)
        {
            SaveCheck.Require(row!=null && row.id>0 && owners.Add(row.id) && row.template>0 && row.maxHP>0 && row.maxHP<=1000000 && row.hp>=0 && row.hp<=row.maxHP &&
                row.team>=0 && row.team<=64 && row.species>=0 && row.owner>=0 && row.bond>=0 && row.retry>=0 && (row.species==0?row.random==0:row.random!=0) && (!row.drop || row.hp==0),"探索敌人");
            SaveCheck.PositiveIds(row.traits,"敌人特质");
            var actor=new CombatActorData(row.id,row.template){MaxHP=row.maxHP,HP=row.hp,Team=row.team,Q=row.q,R=row.r,
                AnimalSpeciesId=row.species,AnimalOwnerId=row.owner,AnimalBond=row.bond,TameRetryTurns=row.retry,animalRandom=row.random,DropResolved=row.drop};
            actor.traits.AddRange(row.traits);actor.Effects.Restore(row.effects);actor.RestoreBody(row.injuries);
            if(row.species==0 && !string.IsNullOrEmpty(row.appearance))appearances.Apply(actor,row.appearance);
            return actor;
        }
    }
    public sealed partial class EquipmentData
    {
        internal void RestoreCombatOwners(MapAreaStateData[] areas)
        {foreach(var area in areas)for(int i=0;i<area.EncounterCount;i++){var group=area.GetEncounterAt(i);for(int j=0;j<group.EnemyCount;j++)combatOwners.Add(group.GetEnemyAt(j).Id);}}
        internal void RestorePartyCombatOwners(WorldPartiesData parties)
        {for(int i=0;i<parties.Count;i++){var party=parties.GetAt(i);for(int j=0;j<party.MemberCount;j++)combatOwners.Add(party.GetMemberAt(j).Id);}}
        internal static MagazineSave CaptureMagazine(EquipmentMagazineData value)=>value==null?null:new MagazineSave{id=value.Id,itemId=value.ItemId,ammo=value.AmmoItemId,capacity=value.Capacity,rounds=value.Rounds};
        internal static WearableSave CaptureWearable(EquipmentWearableData value)=>value==null?null:new WearableSave{id=value.Id,itemId=value.ItemId,owner=value.OwnerActorId,slot=value.Slot,affixId=value.AffixId,condition=EquipmentConditionSave.Capture(value.Condition)};
        internal EquipmentWeaponData PrepareGroundWeapon(WeaponSave row,HashSet<int> ids)
        {
            if(row==null || row.id==0)return null;
            SaveCheck.Require(row.id>0 && ids.Add(row.id) && row.owner==0 && row.hand=="" && row.condition!=null && affixPools.TryGetValue(row.itemId,out var pool) && pool.Ids.Contains(row.affixId),"容器武器");
            var weapon=new EquipmentWeaponData(row.id,row.itemId){AffixId=row.affixId,MagazineId=row.magazine,Condition=row.condition.Restore()};
            var sockets=new HashSet<int>();foreach(var rune in SaveCheck.Rows(row.runes,128,"容器配件")){SaveCheck.Require(rune!=null && rune.id>0 && rune.value>0 && sockets.Add(rune.id),"容器配件");weapon.SetRune(rune.id,rune.value);}return weapon;
        }
        internal EquipmentWearableData PrepareGroundWearable(WearableSave row,HashSet<int> ids)
        {
            if(row==null || row.id==0)return null;
            SaveCheck.Require(row.id>0 && ids.Add(row.id) && row.owner==0 && row.slot=="" && row.condition!=null && affixPools.TryGetValue(row.itemId,out var pool) && pool.Ids.Contains(row.affixId),"容器防具");
            return new EquipmentWearableData(row.id,row.itemId){AffixId=row.affixId,Condition=row.condition.Restore()};
        }
        internal static EquipmentMagazineData PrepareGroundMagazine(MagazineSave row,HashSet<int> ids)
        {
            if(row==null || row.id==0)return null;
            SaveCheck.Require(row.id>0 && ids.Add(row.id) && row.itemId>0 && row.ammo>0 && row.capacity>0 && row.rounds>=0 && row.rounds<=row.capacity,"容器弹匣");
            return new EquipmentMagazineData(row.id,row.itemId,row.ammo,row.capacity,row.rounds);
        }
    }
    public sealed partial class MapAreaLootData
    {
        internal ContainerSave Capture()
        {
            var row=Physical.Capture();row.cell=CellIndex;row.table=TableId;row.name=Name;row.ready=ContentsReady;row.looted=Looted;row.opened=Opened;
            row.items=itemIds;row.counts=counts;row.searched=SearchItems!=null;
            if(SearchItems!=null){row.width=SearchGrid.Width;row.height=SearchGrid.Height;
                row.search=SearchItems.Select(i=>new LootSave{source=i.SourceIndex,item=i.ItemId,count=i.Count,kind=i.Kind,revealed=i.Revealed,progress=i.Progress,
                    weapon=i.StoredWeapon?.CaptureSave(),wearable=EquipmentData.CaptureWearable(i.StoredWearable),magazine=EquipmentData.CaptureMagazine(i.StoredMagazine),loaded=EquipmentData.CaptureMagazine(i.LoadedMagazine)}).ToArray();
                row.placements=Enumerable.Range(0,SearchGrid.Count).Select(i=>SearchGrid.GetAt(i)).Select(p=>new PlacementSave{key=p.Key,itemId=p.ItemId,x=p.X,y=p.Y,rotated=p.Rotated}).ToArray();}
            return row;
        }
        internal static MapAreaLootData Prepare(ContainerSave row,int id,int cellCount,EquipmentData definitions,HashSet<int> ids)
        {
            SaveCheck.Require(row!=null && row.cell>0 && row.cell<=cellCount && row.table>0 && row.ready && !string.IsNullOrEmpty(row.name),"容器身份");
            SaveCheck.PositiveIds(row.items,"容器物品");
            var result=new MapAreaLootData(id,row.cell,row.table){Name=row.name,itemIds=row.items,Looted=row.looted,Opened=row.opened};
            result.Physical.Restore(row,cellCount);
            if(!row.searched){SaveCheck.Rows(row.counts,10000,"容器数量");SaveCheck.Require(row.items.Length==row.counts.Length && row.counts.All(n=>n>0),"容器数量");result.counts=row.counts;return result;}
            SaveCheck.Require(row.width==6 && row.height>=1 && row.height<=100000,"容器网格");
            definitions.Grid.CopyDefinitionsTo(result.SearchGrid);result.SearchGrid.Configure(row.width,row.height);
            result.SearchItems=SaveCheck.Rows(row.search,10000,"搜索物品").Select((item,index)=>{
                SaveCheck.Require(item!=null && item.source>=0 && item.source<row.items.Length && row.items[item.source]==item.item && item.count>=0 &&
                    !float.IsNaN(item.progress) && item.progress>=0 && item.progress<=1 && Array.IndexOf(new[]{"weapon","wearable","magazine","rune","module","ammo","material","consumable","stack"},item.kind)>=0,"搜索物品");
                var next=new LootItemData(result,index,item.source,item.item,item.count,item.kind){Revealed=item.revealed,Progress=item.progress,
                    StoredWeapon=definitions.PrepareGroundWeapon(item.weapon,ids),StoredWearable=definitions.PrepareGroundWearable(item.wearable,ids),
                    StoredMagazine=EquipmentData.PrepareGroundMagazine(item.magazine,ids),LoadedMagazine=EquipmentData.PrepareGroundMagazine(item.loaded,ids)};
                SaveCheck.Require(next.StoredWeapon==null || next.Kind=="weapon" && next.StoredWeapon.ItemId==item.item && next.Count==1 && next.StoredWeapon.MagazineId==(next.LoadedMagazine?.Id ?? 0),"容器武器与弹匣归属");
                SaveCheck.Require(next.StoredWearable==null || next.Kind=="wearable" && next.StoredWearable.ItemId==item.item && next.Count==1,"容器防具归属");
                SaveCheck.Require(next.StoredMagazine==null || next.Kind=="magazine" && next.StoredMagazine.ItemId==item.item && next.Count==1,"容器弹匣归属");
                SaveCheck.Require(next.LoadedMagazine==null || next.StoredWeapon!=null,"无主容器弹匣");return next;
            }).ToArray();
            var remaining=result.SearchItems.Where(i=>i.Count>0).ToDictionary(i=>i.Key);
            foreach(var place in SaveCheck.Rows(row.placements,10000,"容器布局"))
            {SaveCheck.Require(place!=null && place.key!=null && remaining.TryGetValue(place.key,out var item) && item.ItemId==place.itemId,"容器布局归属");SaveCheck.Require(result.SearchGrid.Insert(place.key,place.itemId,place.x,place.y,place.rotated),"容器布局重叠");remaining.Remove(place.key);}
            SaveCheck.Require(remaining.Count==0 && (!row.looted || result.SearchItems.All(i=>i.Count==0)),"容器遗失物品");return result;
        }
    }
    public sealed partial class ContainerState
    {
        internal ContainerSave Capture()=>new ContainerSave{configured=Configured,cells=cells,durability=Durability,maximum=MaxDurability,
            breaking=RequiresBreaking,unlocked=Unlocked,encounter=UnlockEncounterId,rotation=Rotation};
        internal void Restore(ContainerSave row,int cellCount)
        {
            if(!row.configured){SaveCheck.Require(row.maximum==0 && row.durability==0 && row.encounter==0,"未配置容器");return;}
            SaveCheck.Require(row.maximum>=0 && row.durability>=0 && row.durability<=row.maximum && row.cells!=null && row.cells.All(c=>c<=cellCount),"容器耐久或位置");
            Configure(row.maximum,row.breaking,row.encounter,row.rotation,row.cells);Durability=row.durability;Unlocked=row.unlocked;
        }
    }
    public sealed partial class WorldTravelData
    {
        internal TravelSave Capture()=>new TravelSave{q=Q,r=R,target=TargetSiteId,firstStop=firstStopId,speed=Speed,random=random,elapsed=elapsed,sinceCheck=sinceCheck,paused=Paused,
            route=route.Skip(index).Select(s=>new TravelStepSave{q=s.Q,r=s.R,minutes=s.Minutes}).ToArray(),
            stops=stops.Select(s=>new TravelStopSave{id=s.Id,q=s.Q,r=s.R,eventId=s.EventId,encounter=s.EncounterId}).ToArray()};
        internal static WorldTravelData Prepare(TravelSave row)
        {
            SaveCheck.Require(row!=null && row.firstStop>0 && row.target>=0 && row.random!=0 && (row.speed==1 || row.speed==2 || row.speed==4) &&
                !double.IsNaN(row.elapsed) && !double.IsInfinity(row.elapsed) && row.elapsed>=0 && !double.IsNaN(row.sinceCheck) && !double.IsInfinity(row.sinceCheck) && row.sinceCheck>=0,"旅行记录");
            var next=new WorldTravelData{Q=row.q,R=row.r,TargetSiteId=row.target,firstStopId=row.firstStop,Speed=row.speed,random=row.random,elapsed=row.elapsed,sinceCheck=row.sinceCheck,Paused=true};
            int q=row.q,r=row.r;
            foreach(var step in SaveCheck.Rows(row.route,100000,"旅行路线"))
            {SaveCheck.Require(step!=null && !double.IsNaN(step.minutes) && !double.IsInfinity(step.minutes) && step.minutes>0 && Math.Max(Math.Abs(step.q-q),Math.Max(Math.Abs(step.r-r),Math.Abs(step.q-q+step.r-r)))==1,"旅行步长");next.route.Add(new WorldTravelStep(step.q,step.r,step.minutes));q=step.q;r=step.r;}
            SaveCheck.Require(next.route.Count==0?row.elapsed==0:row.elapsed<next.route[0].Minutes,"旅行进度");
            foreach(var stop in SaveCheck.Rows(row.stops,10000,"旅行遭遇"))
            {SaveCheck.Require(stop!=null && stop.id==row.firstStop+next.stops.Count && stop.eventId>=0 && stop.encounter>=0 && (stop.eventId==0)!=(stop.encounter==0),"旅行遭遇身份");next.stops.Add(new WorldTravelStop(stop.id,stop.q,stop.r,stop.eventId,stop.encounter));}
            SaveCheck.Require(row.target<row.firstStop+next.stops.Count,"旅行目的地");return next;
        }
        internal void TakePrepared(WorldTravelData next)
        {route.Clear();route.AddRange(next.route);stops.Clear();stops.AddRange(next.stops);index=0;firstStopId=next.firstStopId;elapsed=next.elapsed;sinceCheck=next.sinceCheck;random=next.random;Q=next.Q;R=next.R;TargetSiteId=next.TargetSiteId;Speed=next.Speed;Paused=true;Message="已恢复当前位置 · 旅行已暂停";Revision++;}
    }
    public sealed partial class ConstructionData
    {
        internal ConstructionSave[] Capture()=>records.Select(r=>new ConstructionSave{site=r.SiteId,cell=r.CellIndex,skill=r.SkillId,hp=r.HP,maximum=r.MaxHP,removed=r.Removed,ownerTeam=r.OwnerTeam,paidMaterialIds=(int[])r.PaidMaterialIds.Clone(),paidMaterialCounts=(int[])r.PaidMaterialCounts.Clone()}).ToArray();
        internal static ConstructionData Prepare(ConstructionSave[] saved,MapAreaStateData[] areas)
        {
            var next=new ConstructionData();foreach(var row in SaveCheck.Rows(saved,100000,"工事"))
            {SaveCheck.Require(row!=null && row.skill>0 && row.cell>0 && areas.Any(a=>a.SiteId==row.site && row.cell<=a.CellCount) && row.maximum>=0 && row.hp>=0 && row.hp<=row.maximum,"工事状态");
                var record=new ConstructionRecord(next.records.Count+1,row.site,row.cell,row.skill,row.maximum){HP=row.hp,Removed=row.removed};next.records.Add(record);
                // Old saves did not record investment. They cannot manufacture a refund from today's configuration.
                SaveCheck.Require(row.ownerTeam>=0&&row.ownerTeam<=64,"工事所有者");
                var paidIds=row.paidMaterialIds??Array.Empty<int>();var paidCounts=row.paidMaterialCounts??Array.Empty<int>();
                SaveCheck.Require(paidIds.Length==paidCounts.Length&&paidIds.Length<=64&&paidIds.Distinct().Count()==paidIds.Length&&paidIds.All(x=>x>0)&&paidCounts.All(x=>x>0),"工事实际投入");
                record.OwnerTeam=row.ownerTeam;record.PaidMaterialIds=(int[])paidIds.Clone();record.PaidMaterialCounts=(int[])paidCounts.Clone();
                if(!row.removed){SaveCheck.Require(!next.active.ContainsKey(Key(row.site,row.cell)),"重叠工事");next.active.Add(Key(row.site,row.cell),record);}}
            return next;
        }
        internal void TakePrepared(ConstructionData next){Clear();records.AddRange(next.records);foreach(var pair in next.active)active.Add(pair.Key,pair.Value);}
    }
    public sealed partial class MapObstacleData
    {
        internal ObstacleSiteSave[] Capture()=>initialized.OrderBy(s=>s).Select(site=>new ObstacleSiteSave{site=site,rows=(sites.TryGetValue(site,out var records)?records:new List<MapObstacleRecord>()).Select(r=>new ObstacleSave{rule=r.RuleId,attempts=r.Attempts,blocks=r.BlocksMovement,cleared=r.Cleared,
            cells=Enumerable.Range(0,r.CellCount).Select(r.GetCellAt).ToArray(),items=Enumerable.Range(0,r.ItemCount).Select(r.GetItemAt).ToArray(),counts=Enumerable.Range(0,r.ItemCount).Select(r.GetCountAt).ToArray()}).ToArray()}).ToArray();
        internal static MapObstacleData Prepare(ObstacleSiteSave[] saved,MapAreaStateData[] areas)
        {
            var next=new MapObstacleData();foreach(var site in SaveCheck.Rows(saved,10000,"障碍地点"))
            {SaveCheck.Require(site!=null && !next.IsInitialized(site.site) && areas.Any(a=>a.SiteId==site.site),"障碍地点");var area=areas.First(a=>a.SiteId==site.site);
                foreach(var row in SaveCheck.Rows(site.rows,10000,"障碍"))
                {SaveCheck.Require(row!=null && row.attempts>=0 && row.cells!=null && row.cells.All(c=>c<=area.CellCount),"障碍状态");next.Add(site.site,row.rule,row.blocks,row.cells,row.items,row.counts);var value=next.Get(site.site,next.Count(site.site));value.Cleared=row.cleared;value.Attempts=row.attempts;}
                next.CompleteInitialization(site.site);}return next;
        }
        internal void TakePrepared(MapObstacleData next){Clear();foreach(var pair in next.sites)sites.Add(pair.Key,pair.Value);initialized.UnionWith(next.initialized);}
    }
}

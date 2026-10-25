using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace ProjectY.Data
{
    [Serializable] internal sealed class IntEntry { public int id, value; }
    [Serializable] internal sealed class AttributeEntry { public string name; public int value; }
    [Serializable] internal sealed class GrowthSave
    {
        public bool initialized; public int level, experience, attributePoints, talentPoints, potential; public uint randomState;
        public int currentProfessionId; public int[] professions;
        public AttributeEntry[] attributes; public IntEntry[] talents; public int[] trees, skills, pending, offers;
    }
    [Serializable] internal sealed class ActorSave
    { public int id, templateId, hp, maxHP; public string appearance; public int[] traits; public GrowthSave growth; public InitialAttributesSave initialAttributes; public ProfessionAttributesSave[] professionAttributes; public bool hasMount; public AnimalMountSave mount; public GameEffectSave[] effects; public BodyInjurySave[] injuries; }
    [Serializable] internal sealed class WeaponSave
    { public int id, itemId, owner, magazine, affixId; public string hand; public IntEntry[] runes; public EquipmentConditionSave condition; }
    [Serializable] internal sealed class MagazineSave { public int id, itemId, ammo, capacity, rounds; }
    [Serializable] internal sealed class WearableSave { public int id, itemId, owner, affixId; public string slot; public EquipmentConditionSave condition; }
    [Serializable] internal sealed class EquipmentConditionSave
    {
        public int current, maximum, baseMaximum; public bool thresholdArmed;
        internal static EquipmentConditionSave Capture(EquipmentConditionData value) => new EquipmentConditionSave { current=value.Current, maximum=value.Maximum, baseMaximum=value.BaseMaximum, thresholdArmed=value.ThresholdArmed };
        internal EquipmentConditionData Restore() => EquipmentConditionData.Restore(current,maximum,baseMaximum,thresholdArmed);
        internal static EquipmentConditionSave Fresh() => Capture(new EquipmentConditionData());
    }
    [Serializable] internal sealed class PlacementSave { public string key; public int itemId, x, y; public bool rotated; }
    [Serializable] internal sealed class InventoryPileSave
    { public int id, itemId, count; }
    [Serializable] internal sealed class EquipmentSave
    { public int width, height, nextId, nextPileId=1; public IntEntry[] stacks; public InventoryPileSave[] piles=Array.Empty<InventoryPileSave>(); public WeaponSave[] weapons; public MagazineSave[] magazines; public WearableSave[] wearables; public PlacementSave[] placements; }
    [Serializable] internal sealed class CharacterSaveDocument
    { public int version, coins, playerLevel; public uint seed; public string savedAt, worldName; public ActorSave[] actors; public EquipmentSave equipment; public NarrativeSave narrative; public ShopStockSave[] shops; public CampSave camp; public PartyStorySave partyStory; public ChronicleSave[] journal; public ExpeditionSave expedition; public SkillSynergyDiscoverySave skillSynergies; }

    internal static class SaveCheck
    {
        internal static void Require(bool condition, string reason) { if (!condition) throw new InvalidDataException("角色存档无效：" + reason); }
        internal static T[] Rows<T>(T[] rows, int max, string name)
        { Require(rows != null && rows.Length <= max, name); return rows; }
        internal static void PositiveIds(int[] values, string name)
        { Rows(values, 10000, name); Require(values.All(v => v > 0) && values.Distinct().Count() == values.Length, name); }
    }
    public sealed partial class CharacterGrowthData
    {
        internal GrowthSave CaptureSave() => new GrowthSave { initialized = Initialized, level = Level, experience = Experience, attributePoints = AttributePoints,
            talentPoints = TalentPoints, potential = LockedPotential, randomState = randomState, currentProfessionId = CurrentProfessionId, professions = professions.ToArray(),
            attributes = attributes.Select(p => new AttributeEntry { name = p.Key, value = p.Value }).ToArray(),
            talents = talentIds.Select(id => new IntEntry { id = id, value = talents[id] }).ToArray(), trees = trees.ToArray(), skills = skills.ToArray(), pending = pendingLevels.ToArray(), offers = offers.ToArray() };
        internal void RestoreSave(GrowthSave row)
        {
            SaveCheck.Require(row != null && row.initialized && row.level >= 1 && row.experience >= 0 && row.attributePoints >= 0 && row.talentPoints >= 0 && row.potential >= 0 && row.randomState != 0, "养成数值");
            SaveCheck.PositiveIds(row.trees, "天赋树"); SaveCheck.PositiveIds(row.skills, "技能"); SaveCheck.PositiveIds(row.offers, "待选技能");
            SaveCheck.Rows(row.pending, 10000, "学习机会"); SaveCheck.Require(row.pending.All(v => v >= 1 && v <= row.level) && (row.offers.Length == 0 || row.pending.Length > 0) && !row.offers.Intersect(row.skills).Any(), "技能待选队列");
            SaveCheck.PositiveIds(row.professions, "职业");
            SaveCheck.Require((row.currentProfessionId == 0 && row.professions.Length == 0) || row.professions.Contains(row.currentProfessionId), "当前职业");
            foreach (var a in SaveCheck.Rows(row.attributes, 128, "投入属性")) { SaveCheck.Require(a != null && !string.IsNullOrEmpty(a.name) && a.value > 0 && !attributes.ContainsKey(a.name), "重复或无效属性"); attributes.Add(a.name, a.value); }
            foreach (var t in SaveCheck.Rows(row.talents, 10000, "天赋投入")) { SaveCheck.Require(t != null && t.id > 0 && t.value > 0 && !talents.ContainsKey(t.id), "重复或无效天赋"); talents.Add(t.id, t.value); talentIds.Add(t.id); }
            Initialized = true; Level = row.level; Experience = row.experience; AttributePoints = row.attributePoints; TalentPoints = row.talentPoints; LockedPotential = row.potential; randomState = row.randomState;
            CurrentProfessionId = row.currentProfessionId; professions.AddRange(row.professions);
            trees.AddRange(row.trees); skills.AddRange(row.skills); offers.AddRange(row.offers); foreach (int level in row.pending) pendingLevels.Enqueue(level); Revision++;
        }
        public int AttributeCount => attributes.Count;
        public string GetAttributeNameAt(int index) => attributes.Keys.ElementAt(index);
    }
    public sealed partial class CombatActorData
    {
        public string CustomizationJson { get; private set; } = "";
        internal void SetCustomization(string json) { if (string.IsNullOrEmpty(json)) throw new ArgumentException("Missing actor appearance."); CustomizationJson = json; }
        internal ActorSave CaptureSave() => new ActorSave { id = Id, templateId = TemplateId, hp = HP, maxHP = MaxHP, appearance = CustomizationJson, traits = traits.ToArray(), growth = Growth.CaptureSave(),initialAttributes=CaptureInitialAttributes(),professionAttributes=CaptureProfessionAttributes(),hasMount=BoundAnimal!=null,mount=CaptureMount(),effects=Effects.Capture(),injuries=CaptureBody() };
        internal static CombatActorData FromSave(ActorSave row, CharacterAppearanceService appearances)
        {
            SaveCheck.Require(row != null && row.id > 0 && row.templateId > 0 && row.maxHP >= 1 && row.maxHP <= 1000000 && row.hp >= 0 && row.hp <= row.maxHP, "角色身份或生命");
            SaveCheck.PositiveIds(row.traits, "特质"); var actor = new CombatActorData(row.id, row.templateId);
            actor.RestoreInitialAttributes(row.initialAttributes);
            actor.RestoreProfessionAttributes(row.professionAttributes);
            actor.MaxHP = row.maxHP; actor.HP = row.hp; actor.traits.AddRange(row.traits); actor.Growth.RestoreSave(row.growth);
            actor.Effects.Restore(row.effects);
            actor.RestoreBody(row.injuries);
            if(row.hasMount){SaveCheck.Require(row.mount!=null,"缺少坐骑记录");actor.RestoreMount(row.mount);}
            else SaveCheck.Require(row.mount==null || (row.mount.id==0 && row.mount.templateId==0 && row.mount.speciesId==0 && row.mount.hp==0 && row.mount.maxHP==0 && row.mount.bond==0 && row.mount.random==0),"未骑乘角色包含坐骑数据");
            appearances.Apply(actor, row.appearance); return actor;
        }
    }
    public sealed partial class EquipmentWeaponData
    {
        internal WeaponSave CaptureSave() => new WeaponSave { id = Id, itemId = ItemId, owner = OwnerActorId, hand = Hand, magazine = MagazineId, affixId = AffixId,
            runes = runes.Select(p => new IntEntry { id = p.Key, value = p.Value }).ToArray(), condition=EquipmentConditionSave.Capture(Condition) };
        public int RuneCount => runes.Count;
        public int GetRuneSocketAt(int index) => runes.Keys.ElementAt(index);
    }
    public sealed partial class InventoryGridData
    {
        internal void CopyDefinitionsTo(InventoryGridData target) { foreach (var pair in shapes) target.Define(pair.Key, pair.Value[0], pair.Value[1]); }
        internal void TakePlacements(InventoryGridData source) { Width = source.Width; Height = source.Height; placements = new List<InventoryPlacementData>(source.placements); }
    }
    public sealed partial class EquipmentData
    {
        internal EquipmentSave CaptureSave(HashSet<int> actors)
        {
            var keptWeapons=weapons.Where(w=>w.OwnerActorId==0 || actors.Contains(w.OwnerActorId)).ToArray();
            var enemyMagazines=new HashSet<int>(weapons.Where(w=>w.OwnerActorId!=0 && !actors.Contains(w.OwnerActorId)).Select(w=>w.MagazineId));
            return new EquipmentSave { width=Grid.Width,height=Grid.Height,nextId=nextId,nextPileId=nextPileId,
                stacks=stacks.Where(s=>s.Count>0 && s.PileId==0).Select(s=>new IntEntry{id=s.ItemId,value=s.Count}).ToArray(),
                piles=stacks.Where(s=>s.Count>0 && s.PileId>0).Select(s=>new InventoryPileSave{id=s.PileId,itemId=s.ItemId,count=s.Count}).ToArray(),
                weapons=keptWeapons.Select(w=>w.CaptureSave()).ToArray(),
                magazines=magazines.Where(m=>!enemyMagazines.Contains(m.Id)).Select(m=>new MagazineSave{id=m.Id,itemId=m.ItemId,ammo=m.AmmoItemId,capacity=m.Capacity,rounds=m.Rounds}).ToArray(),
                wearables=wearables.Where(w=>w.OwnerActorId==0 || actors.Contains(w.OwnerActorId)).Select(w=>new WearableSave{id=w.Id,itemId=w.ItemId,owner=w.OwnerActorId,slot=w.Slot,affixId=w.AffixId,condition=EquipmentConditionSave.Capture(w.Condition)}).ToArray(),
                placements=Enumerable.Range(0,Grid.Count).Select(i=>Grid.GetAt(i)).Select(p=>new PlacementSave{key=p.Key,itemId=p.ItemId,x=p.X,y=p.Y,rotated=p.Rotated}).ToArray() };
        }
        internal EquipmentData PrepareSave(EquipmentSave row, HashSet<int> actors)
        {
            SaveCheck.Require(row != null && row.width == Grid.Width && row.height == Grid.Height && row.nextId > 0 && row.nextPileId>0, "背包尺寸或实例编号");
            var next = new EquipmentData(); Grid.CopyDefinitionsTo(next.Grid); next.Grid.Configure(row.width, row.height);
            foreach (var pair in affixPools) next.affixPools.Add(pair.Key, pair.Value);
            foreach (var pair in ammoCalibers) next.ammoCalibers.Add(pair.Key, pair.Value);
            var ids = new HashSet<int>(); var slots = new HashSet<string>(); var bag = new Dictionary<string, int>();
            Action<int, int> instance = (id, item) => SaveCheck.Require(id > 0 && id < row.nextId && item > 0 && ids.Add(id), "物品实例重复");
            Action<int, string> owner = (id, slot) => SaveCheck.Require(id == 0 ? slot == "" : actors.Contains(id) && slots.Add(id + ":" + slot), "角色所有权或重复装备槽");
            var totals=new Dictionary<int,long>();
            Action<int,int> stackTotal=(itemId,count)=>
            {
                long total=(totals.TryGetValue(itemId,out var previous)?previous:0)+count;
                SaveCheck.Require(total<=int.MaxValue,"同类物品总数溢出");totals[itemId]=total;
            };
            foreach (var item in SaveCheck.Rows(row.stacks, 10000, "堆叠"))
            {
                SaveCheck.Require(item != null && item.id > 0 && item.value > 0 && !bag.ContainsKey("s" + item.id), "堆叠物品");
                stackTotal(item.id,item.value);next.stacks.Add(new InventoryStackData(item.id) { Count = item.value });bag.Add("s" + item.id, item.id);
            }
            foreach(var item in SaveCheck.Rows(row.piles,10000,"独立物品堆"))
            {
                SaveCheck.Require(item!=null && item.id>0 && item.id<row.nextPileId && item.itemId>0 && item.count>0 && !bag.ContainsKey("p"+item.id),"独立堆编号或数量");
                stackTotal(item.itemId,item.count);next.stacks.Add(new InventoryStackData(item.itemId){PileId=item.id,Count=item.count});bag.Add("p"+item.id,item.itemId);
            }
            foreach (var item in SaveCheck.Rows(row.weapons, 10000, "武器"))
            {
                SaveCheck.Require(item != null && (item.owner == 0 ? item.hand == "" : item.hand == "weapon" || item.hand == "offhand"), "武器持握槽");
                instance(item.id, item.itemId); owner(item.owner, item.hand);
                SaveCheck.Require(affixPools.TryGetValue(item.itemId,out var weaponPool) && Array.IndexOf(weaponPool.Ids,item.affixId)>=0,"武器词缀无效或不适用");
                var weapon = new EquipmentWeaponData(item.id, item.itemId) { OwnerActorId = item.owner, Hand = item.hand, MagazineId = item.magazine, AffixId = item.affixId };
                SaveCheck.Require(item.condition!=null,"缺少武器耐久");weapon.Condition=item.condition.Restore();
                var sockets = new HashSet<int>(); foreach (var rune in SaveCheck.Rows(item.runes, 128, "配件")) { SaveCheck.Require(rune != null && rune.id > 0 && rune.value > 0 && sockets.Add(rune.id), "配件槽"); weapon.SetRune(rune.id, rune.value); }
                next.weapons.Add(weapon); if (item.owner == 0) bag.Add("w" + item.id, item.itemId);
            }
            foreach (var item in SaveCheck.Rows(row.magazines, 10000, "弹匣"))
            {
                SaveCheck.Require(item != null && item.ammo > 0 && item.capacity > 0 && item.rounds >= 0 && item.rounds <= item.capacity, "弹匣容量"); instance(item.id, item.itemId);
                next.magazines.Add(new EquipmentMagazineData(item.id, item.itemId, item.ammo, item.capacity, item.rounds));
                int owners = next.weapons.Count(w => w.MagazineId == item.id); SaveCheck.Require(owners <= 1, "弹匣重复安装"); if (owners == 0) bag.Add("m" + item.id, item.itemId);
            }
            foreach (var weapon in next.weapons) SaveCheck.Require(weapon.MagazineId == 0 || next.magazines.Any(m => m.Id == weapon.MagazineId), "武器引用不存在的弹匣");
            foreach (var item in SaveCheck.Rows(row.wearables, 10000, "防具"))
            {
                SaveCheck.Require(item != null && (item.owner == 0 || Array.IndexOf(new[] { "head", "body", "legs", "feet", "leftRing", "rightRing", "offhand" }, item.slot) >= 0), "防具槽");
                SaveCheck.Require(item.condition!=null,"缺少防具耐久");
                SaveCheck.Require(affixPools.TryGetValue(item.itemId,out var wearablePool) && Array.IndexOf(wearablePool.Ids,item.affixId)>=0,"防具词缀无效或不适用");
                instance(item.id, item.itemId); owner(item.owner, item.slot); next.wearables.Add(new EquipmentWearableData(item.id, item.itemId) { OwnerActorId = item.owner, Slot = item.slot, AffixId=item.affixId, Condition=item.condition.Restore() }); if (item.owner == 0) bag.Add("g" + item.id, item.itemId);
            }
            foreach (var place in SaveCheck.Rows(row.placements, 10000, "背包布局"))
            {
                SaveCheck.Require(place != null && place.key != null && bag.TryGetValue(place.key, out int item) && item == place.itemId, "背包归属");
                SaveCheck.Require(next.Grid.Insert(place.key, place.itemId, place.x, place.y, place.rotated), "背包越界或重叠"); bag.Remove(place.key);
            }
            SaveCheck.Require(bag.Count == 0, "背包漏项"); next.nextId = row.nextId;next.nextPileId=row.nextPileId;return next;
        }
        internal void TakePrepared(EquipmentData source)
        {
            combatOwners.Clear();
            stacks.Clear(); stacks.AddRange(source.stacks); weapons.Clear(); weapons.AddRange(source.weapons); magazines.Clear(); magazines.AddRange(source.magazines);
            wearables.Clear(); wearables.AddRange(source.wearables); Grid.TakePlacements(source.Grid); nextId = source.nextId;nextPileId=source.nextPileId;Revision++;
        }
    }
    public sealed partial class AdventureData
    { internal void TakePreparedParty(CombatActorData[] actors, EquipmentData equipment) { RequirePhase("map"); party.Clear(); party.AddRange(actors); Equipment.TakePrepared(equipment); } }
    public sealed partial class PlayerData
    { internal void RestoreProfile(int coins, int level) { Coins = coins; Level = level; Changed?.Invoke(); } }
}

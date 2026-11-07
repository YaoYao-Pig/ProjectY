using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    [XLua.LuaCallCSharp]
    public static class CampWarehouseBridge
    {
        public static InventoryGridData Grid(CampData camp) => camp.Warehouse;
        public static string Key(CampStackData row) => row.Key;
        public static CampStackData Find(CampData camp,string key) => camp.FindStored(key);
        public static void Prepare(CampData camp,EquipmentData equipment) => camp.EnsureWarehouse(equipment.Grid);
        public static string Deposit(CampData camp,string key,int x,int y,bool rotated,int capacity,int revision,int equipmentRevision,string kind,EquipmentData equipment)
            => camp.DepositAt(key,x,y,rotated,capacity,revision,equipmentRevision,kind,equipment);
        public static string Withdraw(CampData camp,string key,int x,int y,bool rotated,int revision,int equipmentRevision,string kind,EquipmentData equipment)
            => camp.WithdrawAt(key,x,y,rotated,revision,equipmentRevision,kind,equipment);
        public static string Move(CampData camp,string key,int x,int y,bool rotated,int revision) => camp.MoveStored(key,x,y,rotated,revision);
    }
    public sealed partial class CampData
    {
        internal Dictionary<string,int> StoredEquipmentItems => storage.Where(row=>row.EquipmentKey.Length>0).ToDictionary(row=>row.EquipmentKey,row=>row.ItemId);
        internal static string EquipmentKind(string key)
        {
            if(string.IsNullOrEmpty(key)||key.Length<2||!int.TryParse(key.Substring(1),out int id)||id<1||key!=key[0].ToString()+id)return null;
            return key[0]=='w'?"weapon":key[0]=='g'?"wearable":key[0]=='m'?"magazine":null;
        }
        internal void ValidateEquipment(EquipmentData equipment)
        {
            var items=StoredEquipmentItems;
            SaveCheck.Require(equipment.CampEquipmentKeys.SetEquals(items.Keys),"camp.equipment.ownership");
            foreach(var pair in items)SaveCheck.Require(equipment.CampEquipmentItem(pair.Key)==pair.Value && equipment.Grid.Find(pair.Key)==null,"camp.equipment.reference");
        }
        public InventoryGridData Warehouse { get; } = new InventoryGridData();
        private int nextWarehouseId=1;
        private CampStackSave[] pendingWarehouse;
        private bool legacyWarehouse;
        public CampData() { Warehouse.Configure(12,10); }
        public CampStackData FindStored(string key) => storage.Find(row=>row.Key==key);
        private int NextWarehouseId()
        {
            if(nextWarehouseId<1 || nextWarehouseId==int.MaxValue || storage.Any(row=>row.Id==nextWarehouseId))
                throw new InvalidOperationException("Invalid warehouse pile sequence.");
            return nextWarehouseId;
        }
        private void ClearWarehouse() { Warehouse.Clear();nextWarehouseId=1;pendingWarehouse=null;legacyWarehouse=false; }
        private void PrepareWarehouse(CampSave save)
        {
            legacyWarehouse=save.gridVersion==0;pendingWarehouse=save.storage;
            int max=storage.Count==0?0:storage.Max(row=>row.Id);
            if(legacyWarehouse)nextWarehouseId=checked(max+1);
            else {SaveCheck.Require(save.nextPileId>max,"营地独立堆序号");nextWarehouseId=save.nextPileId;}
        }
        public void EnsureWarehouse(InventoryGridData source)
        {
            if(pendingWarehouse==null)return;
            var planned=new InventoryGridData();planned.Configure(Warehouse.Width,Warehouse.Height);
            foreach(var row in storage.OrderBy(value=>value.Id))
            {
                planned.CopyShape(source,row.ItemId);
                bool placed;
                if(legacyWarehouse)placed=planned.Exchange(Array.Empty<string>(),new[]{row.Key},new[]{row.ItemId},true);
                else
                {
                    var saved=pendingWarehouse.First(value=>value.id==row.Id);
                    placed=planned.Insert(row.Key,row.ItemId,saved.x,saved.y,saved.rotated);
                }
                SaveCheck.Require(placed,"营地仓库网格越界、重叠或迁移空间不足");
            }
            for(int i=0;i<planned.Count;i++)
            {
                var place=planned.GetAt(i);Warehouse.CopyShape(source,place.ItemId);
                if(!Warehouse.Insert(place.Key,place.ItemId,place.X,place.Y,place.Rotated))throw new InvalidOperationException("Validated warehouse restoration failed.");
            }
            pendingWarehouse=null;legacyWarehouse=false;
        }
        private CampStackSave CaptureWarehouseStack(CampStackData row)
        {
            var place=Warehouse.Find(row.Key)??throw new InvalidOperationException("Warehouse has no placement: "+row.Key);
            return new CampStackSave {id=row.Id,item=row.ItemId,count=row.Count,x=place.X,y=place.Y,rotated=place.Rotated,equipmentKey=row.EquipmentKey};
        }
        private void CopyWarehouse(CampData source)
        {
            if(source.pendingWarehouse!=null)throw new InvalidOperationException("Prepared warehouse is not validated.");
            nextWarehouseId=source.nextWarehouseId;
            for(int i=0;i<source.Warehouse.Count;i++)
            {
                var p=source.Warehouse.GetAt(i);Warehouse.CopyShape(source.Warehouse,p.ItemId);
                if(!Warehouse.Insert(p.Key,p.ItemId,p.X,p.Y,p.Rotated))throw new InvalidOperationException("Prepared warehouse placement failed.");
            }
        }
        private CampStackData StoredAt(int item,int x,int y,string ignored=null)
        {
            for(int i=0;i<Warehouse.Count;i++)
            {
                var p=Warehouse.GetAt(i);
                if(p.Key!=ignored&&p.ItemId==item&&x>=p.X&&y>=p.Y&&x<p.X+p.Width&&y<p.Y+p.Height)
                {var row=FindStored(p.Key);return row.EquipmentKey.Length==0?row:null;}
            }
            return null;
        }
        public string DepositAt(string key,int x,int y,bool rotated,int capacity,int revision,int equipmentRevision,string kind,EquipmentData equipment)
        {
            string reason=Session(revision);if(reason!="")return reason;
            if(equipment.Revision!=equipmentRevision)return "UICampText5";
            if(kind=="weapon"||kind=="wearable"||kind=="magazine")return DepositEquipment(key,x,y,rotated,capacity,kind,equipment);
            if(!StackKind(kind))return "CampUnsupportedItem";
            var stack=equipment.CampStack(key);if(stack==null)return "CampBackpackInsufficient";
            if((long)StoredTotal+stack.Count>capacity)return "CampWarehouseFull";
            EnsureWarehouse(equipment.Grid);Warehouse.CopyShape(equipment.Grid,stack.ItemId);
            var merge=StoredAt(stack.ItemId,x,y);
            if(merge!=null)
            {
                int amount=checked(merge.Count+stack.Count);
                equipment.TakeCampStack(key);merge.Count=amount;
            }
            else
            {
                var row=new CampStackData{Id=NextWarehouseId(),ItemId=stack.ItemId,Count=stack.Count};
                if(!Warehouse.Insert(row.Key,row.ItemId,x,y,rotated))return "CampWarehousePlacementInvalid";
                equipment.TakeCampStack(key);storage.Add(row);nextWarehouseId++;
            }
            Revision++;return "";
        }
        public string WithdrawAt(string key,int x,int y,bool rotated,int revision,int equipmentRevision,string kind,EquipmentData equipment)
        {
            string reason=Session(revision);if(reason!="")return reason;
            if(equipment.Revision!=equipmentRevision)return "UICampText5";
            var row=FindStored(key);if(row==null)return "CampWarehouseInsufficient";
            if(row.EquipmentKey.Length>0)
            {
                if(EquipmentKind(key)!=kind)return "CampUnsupportedItem";
                if(!equipment.ReturnCampEquipment(key,row.ItemId,x,y,rotated))return "CampWithdrawBackpackFull";
                Warehouse.Remove(key);storage.Remove(row);Revision++;return "";
            }
            if(!StackKind(kind))return "CampUnsupportedItem";
            if((long)equipment.CountItem(row.ItemId)+row.Count>int.MaxValue)return "CampItemCountLimit";
            if(!equipment.GrantAt(row.ItemId,kind,row.Count,x,y,rotated,0,0,0))return "CampWithdrawBackpackFull";
            Warehouse.Remove(key);storage.Remove(row);Revision++;return "";
        }
        public string MoveStored(string key,int x,int y,bool rotated,int revision)
        {
            string reason=Session(revision);if(reason!="")return reason;
            var row=FindStored(key);if(row==null)return "CampWarehouseInsufficient";
            var merge=row.EquipmentKey.Length==0?StoredAt(row.ItemId,x,y,key):null;
            if(merge!=null){merge.Count=checked(merge.Count+row.Count);Warehouse.Remove(key);storage.Remove(row);}
            else if(!Warehouse.Move(key,x,y,rotated))return "CampWarehousePlacementInvalid";
            Revision++;return "";
        }
        private string DepositEquipment(string key,int x,int y,bool rotated,int capacity,string kind,EquipmentData equipment)
        {
            if(EquipmentKind(key)!=kind)return "CampUnsupportedItem";
            int item=equipment.CampEquipmentItem(key);var source=equipment.Grid.Find(key);
            if(item==0||source==null||source.ItemId!=item||equipment.CampEquipmentKeys.Contains(key))return "CampEquipmentUnavailable";
            if((long)StoredTotal+1>capacity)return "CampWarehouseFull";
            if(FindStored(key)!=null)throw new InvalidOperationException("Duplicate warehouse equipment ownership.");
            EnsureWarehouse(equipment.Grid);Warehouse.CopyShape(equipment.Grid,item);
            var row=new CampStackData{Id=NextWarehouseId(),ItemId=item,Count=1,EquipmentKey=key};
            if(!Warehouse.Insert(key,item,x,y,rotated))return "CampWarehousePlacementInvalid";
            equipment.StoreCampEquipment(key);storage.Add(row);nextWarehouseId++;Revision++;return "";
        }
    }
    public sealed partial class EquipmentData
    {
        internal readonly HashSet<string> CampEquipmentKeys=new HashSet<string>();
        internal int CampEquipmentItem(string key)
        {
            string kind=CampData.EquipmentKind(key);if(kind==null)return 0;
            int id=int.Parse(key.Substring(1));
            if(kind=="weapon"){var row=weapons.Find(value=>value.Id==id);return row!=null&&row.OwnerActorId==0&&row.Hand==""?row.ItemId:0;}
            if(kind=="wearable"){var row=wearables.Find(value=>value.Id==id);return row!=null&&row.OwnerActorId==0&&row.Slot==""?row.ItemId:0;}
            var magazine=magazines.Find(value=>value.Id==id);return magazine!=null&&MagazineWeapon(id)==0?magazine.ItemId:0;
        }
        internal void StoreCampEquipment(string key)
        {
            if(CampEquipmentItem(key)==0||Grid.Find(key)==null||!CampEquipmentKeys.Add(key))throw new InvalidOperationException("Invalid warehouse equipment deposit.");
            Grid.Remove(key);Revision++;
        }
        internal bool ReturnCampEquipment(string key,int item,int x,int y,bool rotated)
        {
            if(!CampEquipmentKeys.Contains(key)||CampEquipmentItem(key)!=item||Grid.Find(key)!=null)throw new InvalidOperationException("Invalid warehouse equipment withdrawal.");
            if(!Grid.Insert(key,item,x,y,rotated))return false;
            CampEquipmentKeys.Remove(key);Revision++;return true;
        }
        internal InventoryStackData CampStack(string key)
        {
            var row=StackByKey(key);if(row==null||row.Count==0)return null;
            ValidateStackPlacement(row);return row;
        }
        internal void TakeCampStack(string key)
        {
            var row=CampStack(key)??throw new InvalidOperationException("Warehouse source pile vanished.");
            Grid.Remove(key);row.Count=0;RemoveEmptyPile(row);Revision++;
        }
    }
}

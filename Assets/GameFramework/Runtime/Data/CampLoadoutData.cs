using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    /// <summary>Party animal references and one physical torch; animal state remains with its owner.</summary>
    public sealed class CampLoadoutData
    {
        public int MountOwnerId { get; internal set; }
        public int MountAnimalId { get; internal set; }
        public int PetOwnerId { get; internal set; }
        public int PetAnimalId { get; internal set; }
        public int TorchItemId { get; internal set; }
        public static CampLoadoutData For(CampData camp) => camp.Loadout;
        public static string EquipAnimal(CampData camp, AdventureData adventure, int slot, int ownerId, int animalId, int revision)
            => camp.EquipLoadoutAnimal(adventure,slot,ownerId,animalId,revision);
        public static string EquipTorch(CampData camp, EquipmentData equipment, int itemId, bool equip, int revision)
            => camp.EquipLoadoutTorch(equipment,itemId,equip,revision);
        public static void Reconcile(AdventureData adventure) => adventure.Camp.ReconcileLoadout(
            Enumerable.Range(0,adventure.PartyCount).Select(adventure.GetPartyAt));
        internal static CombatActorData Resolve(IEnumerable<CombatActorData> actors,int ownerId,int animalId)
        {
            foreach(var owner in actors)
                if(owner.Id==ownerId && owner.BoundAnimal!=null && owner.BoundAnimal.Id==animalId &&
                    owner.BoundAnimal.AnimalOwnerId==owner.Id && owner.BoundAnimal.HP>0) return owner.BoundAnimal;
            return null;
        }
        internal CampLoadoutSave Capture() => new CampLoadoutSave { mountOwner=MountOwnerId,mountAnimal=MountAnimalId,
            petOwner=PetOwnerId,petAnimal=PetAnimalId,torchItem=TorchItemId };
        internal void Restore(CampLoadoutSave saved)
        {
            SaveCheck.Require(saved!=null && saved.mountOwner>=0 && saved.mountAnimal>=0 && saved.petOwner>=0 && saved.petAnimal>=0 &&
                saved.torchItem>=0 && (saved.mountOwner==0)==(saved.mountAnimal==0) && (saved.petOwner==0)==(saved.petAnimal==0) &&
                (saved.mountAnimal==0 || saved.mountAnimal!=saved.petAnimal),"camp.loadout");
            MountOwnerId=saved.mountOwner;MountAnimalId=saved.mountAnimal;PetOwnerId=saved.petOwner;PetAnimalId=saved.petAnimal;TorchItemId=saved.torchItem;
        }
        internal void ValidateAnimals(IEnumerable<CombatActorData> actors)
        {
            SaveCheck.Require(MountAnimalId==0 || Resolve(actors,MountOwnerId,MountAnimalId)!=null,"camp.loadout.mount");
            SaveCheck.Require(PetAnimalId==0 || Resolve(actors,PetOwnerId,PetAnimalId)!=null,"camp.loadout.pet");
        }
    }
    [Serializable] internal sealed class CampLoadoutSave { public int mountOwner,mountAnimal,petOwner,petAnimal,torchItem; }
    public sealed partial class CampData
    {
        internal CampLoadoutData Loadout { get; } = new CampLoadoutData();
        internal void ReconcileLoadout(IEnumerable<CombatActorData> actors)
        {
            if(Loadout.MountAnimalId!=0 && CampLoadoutData.Resolve(actors,Loadout.MountOwnerId,Loadout.MountAnimalId)==null)
            {Loadout.MountOwnerId=Loadout.MountAnimalId=0;Revision++;}
            if(Loadout.PetAnimalId!=0 && CampLoadoutData.Resolve(actors,Loadout.PetOwnerId,Loadout.PetAnimalId)==null)
            {Loadout.PetOwnerId=Loadout.PetAnimalId=0;Revision++;}
        }
        internal string EquipLoadoutAnimal(AdventureData adventure,int slot,int ownerId,int animalId,int revision)
        {
            string reason=Session(revision);if(reason!="")return reason;
            if(slot!=1 && slot!=2 || ownerId<0 || animalId<0 || (ownerId==0)!=(animalId==0))return "CampLoadoutInvalid";
            if(animalId!=0)
            {
                if(CampLoadoutData.Resolve(Enumerable.Range(0,adventure.PartyCount).Select(adventure.GetPartyAt),ownerId,animalId)==null)return "CampLoadoutAnimalMissing";
                if(animalId==(slot==1?Loadout.PetAnimalId:Loadout.MountAnimalId))return "CampLoadoutAnimalBusy";
            }
            if(slot==1){Loadout.MountOwnerId=ownerId;Loadout.MountAnimalId=animalId;}
            else{Loadout.PetOwnerId=ownerId;Loadout.PetAnimalId=animalId;}
            Revision++;return "";
        }
        internal string EquipLoadoutTorch(EquipmentData equipment,int itemId,bool equip,int revision)
        {
            string reason=Session(revision);if(reason!="")return reason;
            if(itemId<=0 || equip && Loadout.TorchItemId!=0 || !equip && Loadout.TorchItemId!=itemId)return "CampLoadoutInvalid";
            if(equip)
            {
                if(Stored(itemId)>0)RemoveStored(itemId,1);
                else
                {
                    if(equipment.CountItem(itemId)==0)return "CampLoadoutTorchMissing";
                    equipment.ValidateStackConsumption(itemId,1);equipment.ConsumeStack(itemId,1);
                }
                Loadout.TorchItemId=itemId;
            }
            else
            {
                if(equipment.CountItem(itemId)==int.MaxValue)return "CampItemCountLimit";
                if(!equipment.CanGrant(new[]{itemId},new[]{1},new[]{"material"}))return "UICampText31";
                equipment.AddStack(itemId,1);Loadout.TorchItemId=0;
            }
            Revision++;return "";
        }
    }
    // New API uses the existing reflection bridge convention without editing generated xLua wrappers.
    public static class WorldTravelProgress
    {
        public static double Step(WorldTravelData data,double budget,double multiplier) => data.StepAtRate(budget,multiplier);
    }
}

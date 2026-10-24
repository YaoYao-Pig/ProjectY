using System;
using XLua;

namespace ProjectY.Data
{
    [Serializable] internal sealed class AnimalMountSave
    { public int id,templateId,speciesId,hp,maxHP,bond,layer;public uint random;public GameEffectSave[] effects;public bool companion;public BodyInjurySave[] injuries; }
    public sealed partial class CombatActorData
    {
        public int AnimalSpeciesId { get; private set; }
        public int AnimalOwnerId { get; private set; }
        public int AnimalBond { get; private set; }
        public int TameRetryTurns { get; private set; }
        private CombatActorData boundAnimal;
        private bool animalCompanion;
        internal bool IndependentAnimal { get; private set; }
        internal int CompanionLayer { get; private set; }
        internal CombatActorData BoundAnimal => boundAnimal;
        internal CombatActorData CompanionAnimal => animalCompanion ? boundAnimal : null;
        public CombatActorData MountedAnimal
        {
            get => animalCompanion ? null : boundAnimal;
            private set { boundAnimal=value;animalCompanion=false; }
        }
        private uint animalRandom;
        public int MovementSequence { get; private set; }
        public string MovementStyle { get; private set; } = "walk";

        public void InitializeAnimal(int speciesId, uint seed)
        {
            if (speciesId < 1 || AnimalSpeciesId != 0) throw new InvalidOperationException("Animal already initialized or invalid species.");
            AnimalSpeciesId = speciesId; animalRandom = seed == 0 ? 1u : seed;
        }
        public int RollAnimalPercent()
        {
            if (AnimalSpeciesId == 0) throw new InvalidOperationException("Not an animal.");
            animalRandom ^= animalRandom << 13; animalRandom ^= animalRandom >> 17; animalRandom ^= animalRandom << 5;
            return (int)(animalRandom % 10000);
        }
        public void DelayTaming(int turns)
        {
            if(AnimalSpeciesId==0 || AnimalOwnerId!=0 || turns<1) throw new InvalidOperationException("Invalid taming retry delay.");
            TameRetryTurns=turns;
        }
        public bool AdvanceTamingRound()
        {
            if(TameRetryTurns==0)return false;
            TameRetryTurns--;return true;
        }
        public void TameAndRide(CombatActorData animal, int initialBond)
        {
            if (animal == null || animal == this || animal.AnimalSpeciesId == 0 || animal.AnimalOwnerId != 0 ||
                animal.HP == 0 || HP == 0 || Team != 1 || boundAnimal != null || initialBond < 0)
                throw new InvalidOperationException("Invalid taming transition.");
            MountedAnimal = animal; animal.AnimalOwnerId = Id; animal.AnimalBond = initialBond;
            animal.TameRetryTurns=0;
            animal.Team = 1; Q = animal.Q; R = animal.R;
            MovementStyle="walk";MovementSequence++;
        }
        public void AddAnimalBond(int amount, int maximum)
        {
            if (AnimalSpeciesId == 0 || AnimalOwnerId == 0 || amount < 0 || maximum < AnimalBond)
                throw new InvalidOperationException("Invalid animal bond change.");
            AnimalBond = (int)Math.Min(maximum, (long)AnimalBond + amount);
        }
        public void RelocateWithSkill(int q, int r, string style)
        {
            if (HP == 0) throw new InvalidOperationException("A defeated actor cannot relocate.");
            if(style!="charge" && style!="pounce" && style!="leap") throw new ArgumentException("Unknown skill movement.",nameof(style));
            Q = q; R = r; Moved = true;
            MovementStyle=style;MovementSequence++;
        }
        public void DetachDefeatedMount() {if(MountedAnimal!=null&&MountedAnimal.HP==0)MountedAnimal=null;}
        internal void SetCompanionMode(bool independent,int q,int r,int layer)
        {
            if(layer<0)throw new ArgumentOutOfRangeException(nameof(layer));
            if(HP<=0 || boundAnimal==null || boundAnimal.HP<=0 || boundAnimal.AnimalOwnerId!=Id)
                throw new InvalidOperationException("A living owner and owned animal are required.");
            animalCompanion=independent;boundAnimal.IndependentAnimal=independent;
            boundAnimal.Q=q;boundAnimal.R=r;boundAnimal.Team=Team;boundAnimal.CompanionLayer=layer;
        }
        internal void FollowCompanion(int q,int r,int layer)
        {
            if(layer<0)throw new ArgumentOutOfRangeException(nameof(layer));
            if(!IndependentAnimal || HP<=0)throw new InvalidOperationException("Only a living independent companion can follow.");
            if(Q==q&&R==r&&CompanionLayer==layer)return;
            Q=q;R=r;CompanionLayer=layer;MovementStyle="walk";MovementSequence++;
        }
        internal void ReleaseDefeatedCompanion()
        {if(CompanionAnimal!=null&&CompanionAnimal.HP==0){boundAnimal=null;animalCompanion=false;}}
        internal AnimalMountSave CaptureMount()
        {
            var animal=boundAnimal;
            return animal==null?null:new AnimalMountSave {id=animal.Id,templateId=animal.TemplateId,speciesId=animal.AnimalSpeciesId,
                hp=animal.HP,maxHP=animal.MaxHP,bond=animal.AnimalBond,random=animal.animalRandom,effects=animal.Effects.Capture(),companion=animalCompanion,injuries=animal.CaptureBody(),layer=animal.CompanionLayer};
        }
        internal void RestoreMount(AnimalMountSave row)
        {
            if(row==null)return; // 旧存档及未骑乘角色没有坐骑记录。
            SaveCheck.Require(row.id>0 && row.templateId>0 && row.speciesId>0 && row.hp>0 && row.hp<=row.maxHP &&
                row.maxHP<=1000000 && row.bond>=0 && row.random!=0 && row.layer>=0,"坐骑状态");
            var animal=new CombatActorData(row.id,row.templateId);
            animal.InitializeAnimal(row.speciesId,row.random);animal.MaxHP=row.maxHP;animal.HP=row.hp;
            animal.Effects.Restore(row.effects);
            // Legacy mount records did not contain body data; their HP was restored above.
            if(row.injuries!=null)animal.RestoreBody(row.injuries);
            animal.AnimalBond=row.bond;animal.AnimalOwnerId=Id;MountedAnimal=animal;
            animalCompanion=row.companion;animal.IndependentAnimal=row.companion;animal.CompanionLayer=row.layer;
        }
    }
}

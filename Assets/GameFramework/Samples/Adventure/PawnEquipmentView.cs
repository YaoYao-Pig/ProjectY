using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Shared scene/portrait equipment renderer. State and compatibility remain in Lua/data.</summary>
    public sealed class PawnEquipmentView : MonoBehaviour
    {
        [SerializeField] private EquipmentAssetCatalog catalog;
        private EquipmentVisualData view;
        private WeaponModelView weapon, offhand;
        private Transform[] arms;
        private int weaponAsset, offhandAsset, poseId, sequence;
        private bool initialized;
        private PawnAnimationView animationView;
        private PawnCustomizationView customizationView;
        private int customizationRevision;
        private float started=-100;
        private sealed class Attachment { public int Id; public Transform Transform; }
        private readonly Dictionary<string,Attachment> wearables=new Dictionary<string,Attachment>();
        private readonly List<string> removed=new List<string>();
        public void SetCustomization(PawnCustomizationView value)
        {
            int revision = value == null ? 0 : value.Revision;
            if (value == customizationView && revision == customizationRevision) return;
            foreach (var item in wearables.Values) WeaponModelView.Remove(item.Transform.gameObject);
            wearables.Clear(); customizationView = value; customizationRevision = revision;
        }
        public void SetAnimation(PawnAnimationView value)
        {
            if (animationView == value) return;
            Apply(null); animationView = value;
        }
        public void Apply(EquipmentVisualData value)
        {
            if(value==null)
            {
                ClearWeapon(ref weapon,ref weaponAsset);ClearWeapon(ref offhand,ref offhandAsset);
                if(arms!=null) foreach(var arm in arms) WeaponModelView.Remove(arm.gameObject);
                foreach(var worn in wearables.Values) WeaponModelView.Remove(worn.Transform.gameObject);
                wearables.Clear();arms=null;view=null;poseId=0;initialized=false;return;
            }
            if(catalog==null) throw new InvalidOperationException("人物未绑定装备资源目录。");
            ApplyWeapon(value.WeaponView,ref weapon,ref weaponAsset);
            ApplyWeapon(value.OffhandView,ref offhand,ref offhandAsset);
            value.Hold.MainWeaponScale=weapon!=null?weapon.transform.localScale:Vector3.one;
            value.Hold.OffWeaponScale=offhand!=null?offhand.transform.localScale:Vector3.one;
            animationView?.SetHold(value.Hold);
            if(animationView==null && poseId!=value.Hold.Id)
            {
                if(arms!=null) foreach(var arm in arms) WeaponModelView.Remove(arm.gameObject);
                arms=new Transform[6];
                for(int side=0;side<2;side++)
                {
                    arms[side*3]=Instantiate(catalog.Resolve(value.Hold.Upper),transform,false).transform;
                    arms[side*3+1]=Instantiate(catalog.Resolve(value.Hold.Forearm),transform,false).transform;
                    arms[side*3+2]=Instantiate(catalog.Resolve(value.Hold.Hand),transform,false).transform;
                }
                poseId=value.Hold.Id;
            }
            removed.Clear();
            foreach(var key in wearables.Keys) if(!Array.Exists(value.Wearables,x=>x.Slot==key)) removed.Add(key);
            foreach(var key in removed) {WeaponModelView.Remove(wearables[key].Transform.gameObject);wearables.Remove(key);}
            foreach(var worn in value.Wearables)
            {
                if(wearables.TryGetValue(worn.Slot,out var existing)&&existing.Id==worn.Model.Id) continue;
                if(existing!=null) WeaponModelView.Remove(existing.Transform.gameObject);
                var fitted = customizationView != null && PawnCustomizationCatalog.NeedsFit(worn.Mount);
                if (fitted && (worn.Position != Vector3.zero || worn.Rotation != Vector3.zero)) throw new InvalidOperationException("Fitted wearable offsets must be authored in the shared rest pose.");
                var skin = fitted || (animationView != null && (worn.Mount == "legs" || worn.Mount == "feet"));
                var obj = fitted ? customizationView.CreateFit(worn.Model.Path) : skin ? animationView.CreateSkin(worn.Model.Id, transform) : Instantiate(catalog.Resolve(worn.Model),transform,false);
                wearables[worn.Slot]=new Attachment {Id=worn.Model.Id,Transform=obj.transform};
                if(animationView!=null && !skin)
                {
                    var anchor=animationView.Anchor(worn.Mount=="ring" ? (worn.Slot=="rightRing" ? "mainHand" : "offHand") : worn.Mount=="offhand" ? "offHand" : worn.Mount);
                    obj.transform.SetParent(anchor,false);
                    obj.transform.localPosition=worn.Position;obj.transform.localRotation=Quaternion.Euler(worn.Rotation);
                }
            }
            if(initialized && value.Motion.Sequence!=sequence && value.Motion.Kind!="none") started=Time.time;
            sequence=value.Motion.Sequence;initialized=true;view=value;RenderPose();
        }
        private static void ClearWeapon(ref WeaponModelView model,ref int asset)
        {if(model!=null) WeaponModelView.Remove(model.gameObject);model=null;asset=0;}
        private void ApplyWeapon(EquipmentVisualData.Weapon value,ref WeaponModelView model,ref int asset)
        {
            if(value==null) {ClearWeapon(ref model,ref asset);return;}
            if(asset!=value.Model.Id)
            {
                ClearWeapon(ref model,ref asset);
                model=Instantiate(catalog.Resolve(value.Model),transform,false).GetComponent<WeaponModelView>();
                if(model==null) throw new InvalidOperationException("武器 Prefab 缺少 WeaponModelView。");
                asset=value.Model.Id;
            }
            model.Apply(value,catalog);
        }
        private void Update() {if(view!=null) RenderPose();}
        private static void Segment(Transform part,Vector3 a,Vector3 b,float radius)
        {part.localPosition=a;part.localRotation=Quaternion.FromToRotation(Vector3.up,b-a);part.localScale=new Vector3(radius,(b-a).magnitude,radius);}
        private Vector3 SlotPosition(string slot)
        {
            switch(slot)
            {
                case "head":return new Vector3(0,1.59f,0);
                case "body":return new Vector3(0,1.05f,0);
                case "legs":return new Vector3(0,.65f,0);
                case "feet":return new Vector3(0,.235f,0);
                case "weapon":case "rightRing":return arms[2].localPosition;
                case "offhand":case "leftRing":return arms[5].localPosition;
                default:throw new InvalidOperationException("Unknown equipment slot: "+slot);
            }
        }
        public Vector3 SlotWorldPosition(string slot)
        {
            if(view==null) throw new InvalidOperationException("Equipment portrait has no appearance.");
            if(animationView!=null) return animationView.Anchor(slot=="weapon"||slot=="rightRing" ? "mainHand" : slot=="offhand"||slot=="leftRing" ? "offHand" : slot=="body" ? "chest" : slot).position;
            return transform.TransformPoint(SlotPosition(slot));
        }
        private Vector3 WearablePosition(EquipmentVisualData.Wearable worn)
        {
            switch(worn.Mount)
            {
                case "head":return SlotPosition("head");
                case "chest":return SlotPosition("body");
                case "legs":return SlotPosition("legs");
                case "feet":return SlotPosition("feet");
                case "ring":return SlotPosition(worn.Slot);
                case "offhand":return SlotPosition("offhand");
                default:throw new InvalidOperationException("Unknown wearable mount: "+worn.Mount);
            }
        }
        private void RenderPose()
        {
            if(animationView!=null)
            {
                if(weapon!=null && weapon.transform.parent!=animationView.MainGrip)
                {weapon.transform.SetParent(animationView.MainGrip,false);weapon.transform.localPosition=Vector3.zero;weapon.transform.localRotation=Quaternion.identity;}
                if(offhand!=null && offhand.transform.parent!=animationView.OffGrip)
                {offhand.transform.SetParent(animationView.OffGrip,false);offhand.transform.localPosition=Vector3.zero;offhand.transform.localRotation=Quaternion.identity;}
                if(weapon!=null) AlignGrip(weapon.transform,view.WeaponView.PrimaryGrip);
                if(offhand!=null) AlignGrip(offhand.transform,view.OffhandView.PrimaryGrip);
                if(weapon!=null)
                {
                    float progress=animationView.ReloadProgress;
                    float drop=progress>=0?Mathf.Sin(progress*Mathf.PI)*view.Motion.MagazineDrop:0;
                    foreach(var socket in view.WeaponView.Sockets) if(socket.Kind=="magazine") weapon.Socket(socket.Id).localPosition=socket.Position-Vector3.up*drop;
                }
                return; // Animator/IK owns arms. Never overwrite those bones with the rigid preview pose.
            }
            var pose=view.Hold;var action=view.Motion;var t=action.Duration>0?(Time.time-started)/action.Duration:2;
            var pulse=t>=0&&t<1?Mathf.Sin(t*Mathf.PI):0;
            var recoil=t>=0&&t<1?Mathf.Sin(Mathf.Repeat(t*Mathf.Max(1,action.Shots),1)*Mathf.PI):0;
            var shift=new Vector3(0,pulse*action.HandLift,-recoil*action.Recoil);
            bool offAttack=action.Kind=="offhand_slash";
            var rotation=Quaternion.Euler(new Vector3(action.Pitch,action.Yaw,action.Roll)*pulse);
            var main=pose.MainHand+(offAttack?Vector3.zero:shift);var off=pose.OffHand;
            if(pose.OffHandFollowsWeapon) off=main+rotation*(pose.OffHand-pose.MainHand);
            if(offAttack) off+=shift;
            if(action.Kind=="reload" && pulse>0) off=Vector3.Lerp(off,main+new Vector3(.05f,-.3f,.2f),pulse);
            if(weapon!=null)
            {
                weapon.transform.localPosition=main;
                weapon.transform.localRotation=(offAttack?Quaternion.identity:rotation)*Quaternion.Euler(pose.WeaponRotation)*Quaternion.Euler(pose.WeaponRotationOffset);
                weapon.transform.localRotation*=Quaternion.Inverse(Quaternion.Euler(view.WeaponView.PrimaryGrip.Rotation));
                weapon.transform.localPosition-=weapon.transform.localRotation*Vector3.Scale(weapon.transform.localScale,view.WeaponView.PrimaryGrip.Position);
                if(pose.OffHandFollowsWeapon) off=weapon.transform.localPosition+weapon.transform.localRotation*Vector3.Scale(weapon.transform.localScale,view.WeaponView.SecondaryGrip.Position);
                foreach(var socket in view.WeaponView.Sockets) if(socket.Kind=="magazine")
                    weapon.Socket(socket.Id).localPosition=socket.Position-Vector3.up*(pulse*action.MagazineDrop);
            }
            if(offhand!=null)
            {offhand.transform.localRotation=(offAttack?rotation:Quaternion.identity)*Quaternion.Euler(pose.OffWeaponRotation)*Quaternion.Euler(pose.OffWeaponRotationOffset)*Quaternion.Inverse(Quaternion.Euler(view.OffhandView.PrimaryGrip.Rotation));offhand.transform.localPosition=off-offhand.transform.localRotation*Vector3.Scale(offhand.transform.localScale,view.OffhandView.PrimaryGrip.Position);}
            Segment(arms[0],pose.MainShoulder,pose.MainElbow,.105f);Segment(arms[1],pose.MainElbow,main,.088f);arms[2].localPosition=main;
            Segment(arms[3],pose.OffShoulder,pose.OffElbow,.105f);Segment(arms[4],pose.OffElbow,off,.088f);arms[5].localPosition=off;
            foreach(var worn in view.Wearables)
            {
                var mount=wearables[worn.Slot].Transform;
                mount.localPosition=WearablePosition(worn)+worn.Position;
                mount.localRotation=Quaternion.Euler(worn.Rotation);
            }
        }
        private static void AlignGrip(Transform weapon,EquipmentVisualData.Grip grip)
        {
            var inverse=Quaternion.Inverse(Quaternion.Euler(grip.Rotation));
            weapon.localRotation=inverse;weapon.localPosition=-(inverse*Vector3.Scale(weapon.localScale,grip.Position));
        }
#if UNITY_EDITOR
        public void Bind(EquipmentAssetCatalog value) {catalog=value;}
#endif
    }
}

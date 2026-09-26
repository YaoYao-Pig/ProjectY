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
        private float started=-100;
        private sealed class Attachment { public int Id; public Transform Transform; }
        private readonly Dictionary<string,Attachment> wearables=new Dictionary<string,Attachment>();
        private readonly List<string> removed=new List<string>();
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
            if(poseId!=value.Hold.Id)
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
                wearables[worn.Slot]=new Attachment {Id=worn.Model.Id,Transform=Instantiate(catalog.Resolve(worn.Model),transform,false).transform};
            }
            if(initialized && value.Motion.Sequence!=sequence && value.Motion.Kind!="none") started=Time.unscaledTime;
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
            var pose=view.Hold;var action=view.Motion;var t=action.Duration>0?(Time.unscaledTime-started)/action.Duration:2;
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
                weapon.transform.localRotation=(offAttack?Quaternion.identity:rotation)*Quaternion.Euler(pose.WeaponRotation);
                foreach(var socket in view.WeaponView.Sockets) if(socket.Kind=="magazine")
                    weapon.Socket(socket.Id).localPosition=socket.Position-Vector3.up*(pulse*action.MagazineDrop);
            }
            if(offhand!=null)
            {offhand.transform.localPosition=off;offhand.transform.localRotation=(offAttack?rotation:Quaternion.identity)*Quaternion.Euler(pose.OffWeaponRotation);}
            Segment(arms[0],pose.MainShoulder,pose.MainElbow,.105f);Segment(arms[1],pose.MainElbow,main,.088f);arms[2].localPosition=main;
            Segment(arms[3],pose.OffShoulder,pose.OffElbow,.105f);Segment(arms[4],pose.OffElbow,off,.088f);arms[5].localPosition=off;
            foreach(var worn in view.Wearables)
            {
                var mount=wearables[worn.Slot].Transform;
                mount.localPosition=WearablePosition(worn)+worn.Position;
                mount.localRotation=Quaternion.Euler(worn.Rotation);
            }
        }
#if UNITY_EDITOR
        public void Bind(EquipmentAssetCatalog value) {catalog=value;}
#endif
    }
}

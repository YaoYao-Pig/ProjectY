using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Config-driven rigid arms and short motions. Never changes combat/inventory state.</summary>
    public sealed class PawnEquipmentView : MonoBehaviour
    {
        [SerializeField] private EquipmentAssetCatalog catalog;
        private EquipmentVisualData view;
        private WeaponModelView weapon;
        private Transform[] arms;
        private int weaponAsset, poseId, sequence;
        private bool initialized;
        private float started=-100;
        public void Apply(EquipmentVisualData value)
        {
            if(value==null)
            {
                if(weapon!=null) WeaponModelView.Remove(weapon.gameObject);
                if(arms!=null) foreach(var arm in arms) WeaponModelView.Remove(arm.gameObject);
                arms=null;weapon=null;view=null;weaponAsset=poseId=0;initialized=false;return;
            }
            if(catalog==null) throw new System.InvalidOperationException("人物未绑定装备资源目录。");
            if(weaponAsset!=value.WeaponView.Model.Id)
            {
                if(weapon!=null) WeaponModelView.Remove(weapon.gameObject);
                weapon=Instantiate(catalog.Resolve(value.WeaponView.Model),transform,false).GetComponent<WeaponModelView>();
                if(weapon==null) throw new System.InvalidOperationException("武器 Prefab 缺少 WeaponModelView。");
                weaponAsset=value.WeaponView.Model.Id;
            }
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
            if(initialized && value.Motion.Sequence!=sequence && value.Motion.Kind!="none") started=Time.unscaledTime;
            sequence=value.Motion.Sequence;initialized=true;view=value;
            weapon.Apply(value.WeaponView,catalog);RenderPose();
        }
        private void Update() { if(view!=null) RenderPose(); }
        private static void Segment(Transform part,Vector3 a,Vector3 b,float radius)
        { part.localPosition=a;part.localRotation=Quaternion.FromToRotation(Vector3.up,b-a);part.localScale=new Vector3(radius,(b-a).magnitude,radius); }
        private void RenderPose()
        {
            var pose=view.Hold;var action=view.Motion;var t=action.Duration>0?(Time.unscaledTime-started)/action.Duration:2;
            var pulse=t>=0&&t<1?Mathf.Sin(t*Mathf.PI):0;
            var recoil=t>=0&&t<1?Mathf.Sin(Mathf.Repeat(t*Mathf.Max(1,action.Shots),1)*Mathf.PI):0;
            var shift=new Vector3(0,pulse*action.HandLift,-recoil*action.Recoil);
            weapon.transform.localPosition=pose.MainHand+shift;
            weapon.transform.localRotation=Quaternion.Euler(pose.WeaponRotation+Vector3.right*(pulse*action.Pitch));
            var main=pose.MainHand+shift;
            var off=pose.OffHand+shift;
            if(action.Kind=="reload" && pulse>0) off=Vector3.Lerp(off,main+new Vector3(.05f,-.3f,.2f),pulse);
            Segment(arms[0],pose.MainShoulder,pose.MainElbow,.105f);Segment(arms[1],pose.MainElbow,main,.088f);arms[2].localPosition=main;
            Segment(arms[3],pose.OffShoulder,pose.OffElbow,.105f);Segment(arms[4],pose.OffElbow,off,.088f);arms[5].localPosition=off;
            foreach(var socket in view.WeaponView.Sockets) if(socket.Kind=="magazine")
                weapon.Socket(socket.Id).localPosition=socket.Position-Vector3.up*(pulse*action.MagazineDrop);
        }
#if UNITY_EDITOR
        public void Bind(EquipmentAssetCatalog value) { catalog=value; }
#endif
    }
}

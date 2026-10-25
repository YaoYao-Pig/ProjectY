using System;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed class WeaponModelView : MonoBehaviour
    {
        [Serializable] public sealed class Mount { public int Id; public Transform Anchor; }
        [SerializeField] private Mount[] mounts;
        [SerializeField] private EquipmentVisualProfileView visualProfile;
        private GameObject[] attachments;
        private int[] ids;
        private EquipmentEffectDisplay itemEffect;
        private EquipmentEffectDisplay[] attachmentEffects;
        public Transform Socket(int id)
        {
            foreach (var mount in mounts) if (mount.Id==id) return mount.Anchor;
            throw new InvalidOperationException("武器挂点未绑定："+id);
        }
        public void Apply(EquipmentVisualData.Weapon view, EquipmentAssetCatalog catalog)
        {
            if(visualProfile!=null) visualProfile.SetEffect(view.Effect);
            else
            {
                if(itemEffect==null) itemEffect=new EquipmentEffectDisplay(transform);
                itemEffect.Set(view.Effect);
            }
            if(attachmentEffects==null) attachmentEffects=new EquipmentEffectDisplay[mounts.Length];
            if (attachments==null) { attachments=new GameObject[mounts.Length]; ids=new int[mounts.Length]; }
            if (view.Sockets.Length!=mounts.Length) throw new InvalidOperationException("武器挂点数量与配置不一致。");
            foreach (var socket in view.Sockets)
            {
                var i=Array.FindIndex(mounts,m=>m.Id==socket.Id);
                if (i<0) throw new InvalidOperationException("未绑定武器挂点："+socket.Id);
                var anchor=mounts[i].Anchor; anchor.localPosition=socket.Position; anchor.localRotation=Quaternion.Euler(socket.Rotation);
                if(attachmentEffects[i]==null) attachmentEffects[i]=new EquipmentEffectDisplay(anchor);
                attachmentEffects[i].Set(socket.Effect);
                var id=socket.Attachment?.Id??0;
                if (id==ids[i]) continue;
                if (attachments[i]!=null) Remove(attachments[i]);
                attachments[i]=id==0?null:Instantiate(catalog.Resolve(socket.Attachment),anchor,false);ids[i]=id;
            }
        }
        public void TickEffects(float deltaTime)
        {
            itemEffect?.Tick(deltaTime,transform.position+transform.up*.25f);
            visualProfile?.TickEffects(deltaTime);
            if(attachmentEffects!=null) for(int i=0;i<attachmentEffects.Length;i++) attachmentEffects[i]?.Tick(deltaTime,mounts[i].Anchor.position);
        }
        private void OnDisable()
        {itemEffect?.Clear();if(attachmentEffects!=null)foreach(var effect in attachmentEffects)effect?.Clear();}
        private void OnDestroy()
        {itemEffect?.Dispose();if(attachmentEffects!=null)foreach(var effect in attachmentEffects)effect?.Dispose();}
        public static void Remove(GameObject value) { value.SetActive(false); if(Application.isPlaying) Destroy(value);else DestroyImmediate(value); }
#if UNITY_EDITOR
        public void SetMounts(Mount[] value) { mounts=value; }
        public void SetVisualProfile(EquipmentVisualProfileView value) { visualProfile=value; }
#endif
    }
}

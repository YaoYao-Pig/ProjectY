using System;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed class WeaponModelView : MonoBehaviour
    {
        [Serializable] public sealed class Mount { public int Id; public Transform Anchor; }
        [SerializeField] private Mount[] mounts;
        private GameObject[] attachments;
        private int[] ids;
        public Transform Socket(int id)
        {
            foreach (var mount in mounts) if (mount.Id==id) return mount.Anchor;
            throw new InvalidOperationException("武器挂点未绑定："+id);
        }
        public void Apply(EquipmentVisualData.Weapon view, EquipmentAssetCatalog catalog)
        {
            if (attachments==null) { attachments=new GameObject[mounts.Length]; ids=new int[mounts.Length]; }
            if (view.Sockets.Length!=mounts.Length) throw new InvalidOperationException("武器挂点数量与配置不一致。");
            foreach (var socket in view.Sockets)
            {
                var i=Array.FindIndex(mounts,m=>m.Id==socket.Id);
                if (i<0) throw new InvalidOperationException("未绑定武器挂点："+socket.Id);
                var anchor=mounts[i].Anchor; anchor.localPosition=socket.Position; anchor.localRotation=Quaternion.Euler(socket.Rotation);
                var id=socket.Attachment?.Id??0;
                if (id==ids[i]) continue;
                if (attachments[i]!=null) Remove(attachments[i]);
                attachments[i]=id==0?null:Instantiate(catalog.Resolve(socket.Attachment),anchor,false);ids[i]=id;
            }
        }
        public static void Remove(GameObject value) { value.SetActive(false); if(Application.isPlaying) Destroy(value);else DestroyImmediate(value); }
#if UNITY_EDITOR
        public void SetMounts(Mount[] value) { mounts=value; }
#endif
    }
}

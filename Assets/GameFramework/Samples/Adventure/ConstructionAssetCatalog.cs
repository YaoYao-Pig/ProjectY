using System;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed class ConstructionAssetCatalog:ScriptableObject
    {
        [Serializable]public struct Entry{public int SkillId;public GameObject Prefab;}
        [SerializeField]private Entry[] entries=Array.Empty<Entry>();
        public GameObject Resolve(int skill)
        {foreach(var entry in entries)if(entry.SkillId==skill)return entry.Prefab!=null?entry.Prefab:throw new InvalidOperationException("Construction model is missing: "+skill);throw new InvalidOperationException("Construction model is not registered: "+skill);}
#if UNITY_EDITOR
        public void Bind(Entry[] values){entries=values;}
#endif
    }
}

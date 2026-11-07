using System;
using UnityEngine;

namespace ProjectY.UI
{
    public sealed class CampStage : MonoBehaviour
    {
        [Serializable] public sealed class Facility
        {
            public int Id;
            public GameObject[] Levels;
            public Transform LabelAnchor;
            public Collider HitVolume;
            public GameObject Hover;
        }
        public Camera Camera;
        public Facility[] Facilities;
        public Transform[] PartyAnchors;
        public Light FireLight;
        public void SetLevels(int workbench,int medical,int warehouse)
        {
            foreach(var facility in Facilities)
            {
                int level=facility.Id==2?medical:facility.Id==3?warehouse:workbench;
                if(level<0||level>=facility.Levels.Length)throw new InvalidOperationException("Camp visual level is not authored.");
                for(int i=0;i<facility.Levels.Length;i++)facility.Levels[i].SetActive(i==level);
            }
        }
        public int Hit(Ray ray)
        {
            int id=0;float nearest=float.PositiveInfinity;
            foreach(var facility in Facilities)
                if(facility.HitVolume.Raycast(ray,out var hit,100)&&hit.distance<nearest){nearest=hit.distance;id=facility.Id;}
            return id;
        }
        public void Highlight(int id){foreach(var f in Facilities)f.Hover.SetActive(id==f.Id);}
    }
}

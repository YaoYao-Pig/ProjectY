using System;
using System.Collections.Generic;
using ProjectY.Data;
using UnityEngine;

namespace ProjectY.Samples
{
    public static class CampaignPreviewCapture
    {
        public static WorldMenuSnapshot Capture(MapPreviewData map)
        {
            if(map==null||map.Cells==null||map.Cells.Length==0)throw new ArgumentException("A committed map is required.");
            var result=new WorldMenuSnapshot{Seed=map.Seed};int n=result.Heights.Length;
            float minX=float.MaxValue,maxX=float.MinValue,minZ=float.MaxValue,maxZ=float.MinValue,maxY=.01f;
            foreach(var cell in map.Cells){minX=Mathf.Min(minX,cell.Position.x);maxX=Mathf.Max(maxX,cell.Position.x);minZ=Mathf.Min(minZ,cell.Position.z);maxZ=Mathf.Max(maxZ,cell.Position.z);maxY=Mathf.Max(maxY,cell.Position.y);}
            float dx=Mathf.Max(1,maxX-minX),dz=Mathf.Max(1,maxZ-minZ),scale=Mathf.Min(7.8f/dx,5.2f/dz),cx=(minX+maxX)*.5f,cz=(minZ+maxZ)*.5f;
            var counts=new int[n];var heights=new float[n];var reds=new float[n];var greens=new float[n];var blues=new float[n];
            Func<MapPreviewData.Cell,Vector3> point=c=>new Vector3((c.Position.x-cx)*scale,.08f+Mathf.Clamp01(c.Position.y/maxY)*1.45f,(c.Position.z-cz)*scale);
            foreach(var c in map.Cells)
            {
                var p=point(c);int x=Mathf.Clamp(Mathf.RoundToInt((p.x+4.07f)/8.14f*63),0,63),z=Mathf.Clamp(Mathf.RoundToInt((p.z+2.79f)/5.58f*47),0,47),i=z*64+x;
                Color color=c.HasWater?new Color(.30f,.59f,.64f):c.Color;
                counts[i]++;heights[i]+=c.HasWater?.035f:p.y;reds[i]+=color.r;greens[i]+=color.g;blues[i]+=color.b;
            }
            for(int i=0;i<n;i++)
            {
                if(counts[i]>0){result.Heights[i]=heights[i]/counts[i];result.Colors[i]=(Color32)new Color(reds[i]/counts[i],greens[i]/counts[i],blues[i]/counts[i]);}
                else {result.Heights[i]=.025f;result.Colors[i]=new Color32(76,147,157,255);}
            }
            // Fill only enclosed sample holes; keep coastlines and the exterior sea.
            for(int z=1;z<47;z++)for(int x=1;x<63;x++)
            {int i=z*64+x;if(counts[i]!=0)continue;int[] adjacent={i-1,i+1,i-64,i+64};int found=0;float h=0;Color color=Color.black;foreach(int a in adjacent)if(counts[a]>0){found++;h+=result.Heights[a];color+=(Color)result.Colors[a];}if(found>=3){result.Heights[i]=h/found;result.Colors[i]=(Color32)(color/found);}}
            var points=new List<Vector3>();var kinds=new List<byte>();
            if(map.Towns!=null)for(int i=0;i<map.Towns.Length&&points.Count<24;i++){int c=map.Towns[i].Center;if(c<0||c>=map.Cells.Length)throw new InvalidOperationException("Invalid preview town center.");points.Add(point(map.Cells[c]));kinds.Add((byte)(i%5==0?2:1));}
            int stride=Mathf.Max(1,map.Cells.Length/512);
            for(int i=0;i<map.Cells.Length&&points.Count<WorldMenuSnapshot.MaxLandmarks;i+=stride)
            {var c=map.Cells[i];if(c.HasWater||c.Color.g<c.Color.r*1.05f)continue;var p=point(c);if(points.Exists(v=>(new Vector2(v.x-p.x,v.z-p.z)).sqrMagnitude<.04f))continue;points.Add(p);kinds.Add(0);}
            result.Landmarks=points.ToArray();result.LandmarkKinds=kinds.ToArray();result.Validate();return result;
        }
        // Authored miniature, independent of the world generator and gameplay bootstrap.
        public static WorldMenuSnapshot Default()
        {
            var r=new WorldMenuSnapshot{Seed=274819};
            for(int z=0;z<48;z++)for(int x=0;x<64;x++)
            {
                float px=(x/63f-.5f)*8.14f,pz=(z/47f-.5f)*5.58f;
                float land=.68f-(px*px/15+pz*pz/6)*.5f+.08f*Mathf.Sin(px*2+pz)+.08f*Mathf.Cos(pz*3.1f-px);
                bool water=land<.1f||Mathf.Abs(pz+.35f*Mathf.Sin(px*1.4f))<.12f;
                float mountain=Mathf.Exp(-Mathf.Pow((pz+1.1f)*2.6f,2))*Mathf.Max(0,1-Mathf.Abs(px)/2.7f)*.9f;
                r.Heights[z*64+x]=water?.025f:.08f+land*.35f+mountain;
                r.Colors[z*64+x]=(Color32)(water?new Color(.3f,.59f,.64f):mountain>.35f?new Color(.6f,.61f,.52f):land<.22f?new Color(.68f,.67f,.45f):new Color(.46f,.59f,.33f));
            }
            var points=new List<Vector3>();var kinds=new List<byte>();
            var random=new System.Random(274819);
            for(int i=0;i<220&&points.Count<85;i++){int x=random.Next(3,61),z=random.Next(3,45),index=z*64+x;float h=r.Heights[index];if(h<.08f||h>.55f)continue;var p=new Vector3(x/63f*8.14f-4.07f,h,z/47f*5.58f-2.79f);if(points.Exists(v=>(v-p).sqrMagnitude<.035f))continue;points.Add(p);kinds.Add((byte)(points.Count==19?2:points.Count%17==0?1:0));}
            r.Landmarks=points.ToArray();r.LandmarkKinds=kinds.ToArray();return r;
        }
    }
}

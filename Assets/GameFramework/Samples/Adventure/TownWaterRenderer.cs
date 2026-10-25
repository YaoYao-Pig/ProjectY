using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Object=UnityEngine.Object;
namespace ProjectY.Samples
{
    internal sealed class TownWaterRenderer : IDisposable
    {
        private readonly Mesh mesh;
        private readonly Material material;
        public TownWaterRenderer(Shader shader,MapAreaViewData map)
        {
            var vertices=new List<Vector3>();var indices=new List<int>();var depths=new List<float>();
            var samples=new Dictionary<Vector2Int,Vector2>();
            foreach(var cell in map.Cells)if(cell.WaterDepth>0)
            {
                int offset=vertices.Count;vertices.Add(new Vector3(cell.Position.x,cell.WaterLevel,cell.Position.z));depths.Add(cell.WaterDepth);
                for(int i=0;i<6;i++)
                {
                    float angle=(30+i*60)*Mathf.Deg2Rad;var point=new Vector3(cell.Position.x+Mathf.Cos(angle)*map.Radius,cell.WaterLevel,cell.Position.z+Mathf.Sin(angle)*map.Radius);
                    vertices.Add(point);depths.Add(cell.WaterDepth);
                    var key=new Vector2Int(Mathf.RoundToInt(point.x*1000),Mathf.RoundToInt(point.z*1000));samples.TryGetValue(key,out var sum);samples[key]=sum+new Vector2(cell.WaterDepth,1);
                }
                for(int i=0;i<6;i++){indices.Add(offset);indices.Add(offset+1+(i+1)%6);indices.Add(offset+1+i);}
            }
            if(vertices.Count==0)return;
            var colors=new List<Color>(vertices.Count);
            for(int i=0;i<vertices.Count;i++)
            {
                var point=vertices[i];float depth=depths[i];
                if(i%7!=0){var sum=samples[new Vector2Int(Mathf.RoundToInt(point.x*1000),Mathf.RoundToInt(point.z*1000))];depth=sum.x/sum.y;}
                var shade=Color.Lerp(new Color(.31f,.64f,.65f,1),new Color(.13f,.38f,.47f,1),Mathf.SmoothStep(0,1,Mathf.InverseLerp(.35f,3.5f,depth)));
                colors.Add(QualitySettings.activeColorSpace==ColorSpace.Linear?shade.linear:shade);
            }
            mesh=new Mesh {name="TownWater",indexFormat=IndexFormat.UInt32};mesh.SetVertices(vertices);mesh.SetColors(colors);mesh.SetTriangles(indices,0);mesh.RecalculateNormals();mesh.RecalculateBounds();
            material=new Material(shader){name="TownWater",enableInstancing=true};
            material.SetFloat("_UseVertexColor",1);material.SetColor("_Color",Color.white);material.SetColor("_BaseColor",Color.white);material.SetFloat("_Smoothness",.15f);
        }
        public void Draw(Camera camera){if(mesh!=null)Graphics.DrawMesh(mesh,Matrix4x4.identity,material,0,camera,0,null,ShadowCastingMode.Off,true);}
        public void Dispose(){if(Application.isPlaying){Object.Destroy(mesh);Object.Destroy(material);}else{Object.DestroyImmediate(mesh);Object.DestroyImmediate(material);}}
    }
}

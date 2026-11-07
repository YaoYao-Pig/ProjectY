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
        public TownWaterRenderer(MapAreaViewData map, MapBoundaryRenderer boundary)
        {
            var vertices=new List<Vector3>();var indices=new List<int>();
            foreach(var cell in map.Cells)if(cell.WaterDepth>0 || cell.Kind=="water")
            {
                float level=cell.WaterDepth>0?cell.WaterLevel:cell.Position.y;
                int offset=vertices.Count;vertices.Add(new Vector3(cell.Position.x,level,cell.Position.z));
                for(int i=0;i<6;i++)
                {
                    float angle=(30+i*60)*Mathf.Deg2Rad;var point=new Vector3(cell.Position.x+Mathf.Cos(angle)*map.Radius,level,cell.Position.z+Mathf.Sin(angle)*map.Radius);
                    vertices.Add(point);
                }
                for(int i=0;i<6;i++){indices.Add(offset);indices.Add(offset+1+(i+1)%6);indices.Add(offset+1+i);}
            }
            if(vertices.Count==0)return;
            mesh=new Mesh {name="TownWater",indexFormat=IndexFormat.UInt32};mesh.SetVertices(vertices);mesh.SetTriangles(indices,0);mesh.RecalculateNormals();mesh.RecalculateBounds();
            var shader = Resources.Load<Shader>("MapWater");
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("Town water shader is missing or unsupported.");
            material = new Material(shader) { name = "Town ocean water", enableInstancing = true };
            material.SetFloat("_WaterScale", map.Radius);
            boundary.BindWater(material);
        }
        public void Draw(Camera camera){if(mesh!=null)Graphics.DrawMesh(mesh,Matrix4x4.identity,material,0,camera,0,null,ShadowCastingMode.Off,true);}
        public void Dispose(){if(Application.isPlaying){Object.Destroy(mesh);Object.Destroy(material);}else{Object.DestroyImmediate(mesh);Object.DestroyImmediate(material);}}
    }
}

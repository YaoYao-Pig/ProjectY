using System;
using System.Collections.Generic;
using ProjectY.Data;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    /// <summary>Soft moving cloud cover and a shared exploration mask; no gameplay state ownership.</summary>
    internal sealed class WorldFogRenderer : IDisposable
    {
        private readonly MapPreviewData map;
        private readonly Dictionary<long,int> cells = new Dictionary<long,int>();
        private readonly Texture2D mask;
        private readonly Color32[] pixels;
        private readonly int[] firstPixel, nextPixel;
        private readonly List<int> previousVisible = new List<int>();
        private readonly Vector4 bounds;
        private readonly GameObject root;
        private readonly Mesh mesh;
        private readonly Material material;
        private WorldMapExplorationData data;
        private int revision = -1, knownCount;
        internal Material Material => material;
        private static long Key(int q,int r) => ((long)q << 32) | (uint)r;
        internal WorldFogRenderer(MapPreviewData map,Transform parent)
        {
            this.map=map;
            var box=new Bounds(map.Cells[0].Position,Vector3.zero);
            for(int i=0;i<map.Cells.Length;i++){box.Encapsulate(map.Cells[i].Position);cells.Add(Key(map.Cells[i].Q,map.Cells[i].R),i);}
            box.Expand(map.Radius*4);
            bounds=new Vector4(box.min.x,box.min.z,1/box.size.x,1/box.size.z);
            int width=Mathf.Clamp(Mathf.CeilToInt(box.size.x/map.Radius*2),32,1024);
            int height=Mathf.Clamp(Mathf.CeilToInt(box.size.z/map.Radius*2),32,1024);
            mask=new Texture2D(width,height,TextureFormat.RGBA32,false,true){name="World exploration mask",wrapMode=TextureWrapMode.Clamp,filterMode=FilterMode.Bilinear};
            pixels=new Color32[width*height];nextPixel=new int[pixels.Length];firstPixel=new int[map.Cells.Length];
            for(int i=0;i<firstPixel.Length;i++)firstPixel[i]=-1;
            for(int y=0;y<height;y++)for(int x=0;x<width;x++)
            {
                int pixel=y*width+x;int cell=CellAt(new Vector3(box.min.x+(x+.5f)/width*box.size.x,0,box.min.z+(y+.5f)/height*box.size.z));
                nextPixel[pixel]=-1;
                if(cell<0)continue;
                pixels[pixel]=new Color32(0,0,255,255);nextPixel[pixel]=firstPixel[cell];firstPixel[cell]=pixel;
            }
            mask.SetPixels32(pixels);mask.Apply(false,false);
            var shader=Resources.Load<Shader>("WorldFog");
            if(shader==null || !shader.isSupported)throw new InvalidOperationException("World fog shader is missing or unsupported.");
            material=new Material(shader){name="World exploration clouds"};material.SetTexture("_WorldFogMask",mask);material.SetVector("_WorldFogBounds",bounds);
            int columns=Mathf.Clamp(Mathf.CeilToInt(box.size.x/map.Radius),8,192),rows=Mathf.Clamp(Mathf.CeilToInt(box.size.z/map.Radius),8,192);
            var vertices=new Vector3[(columns+1)*(rows+1)];var triangles=new int[columns*rows*6];
            for(int y=0;y<=rows;y++)for(int x=0;x<=columns;x++)
            {
                var point=new Vector3(box.min.x+(float)x/columns*box.size.x,0,box.min.z+(float)y/rows*box.size.z);
                int cell=CellAt(point);point.y=(cell<0?box.center.y:Mathf.Max(map.Cells[cell].Position.y,map.Cells[cell].HasWater?map.Cells[cell].WaterLevel:float.MinValue))+map.Radius*2.5f;
                vertices[y*(columns+1)+x]=point;
            }
            int offset=0;
            for(int y=0;y<rows;y++)for(int x=0;x<columns;x++)
            {
                int a=y*(columns+1)+x,b=a+columns+1;
                triangles[offset++]=a;triangles[offset++]=b;triangles[offset++]=a+1;
                triangles[offset++]=a+1;triangles[offset++]=b;triangles[offset++]=b+1;
            }
            mesh=new Mesh{name="World fog cloud surface",indexFormat=IndexFormat.UInt32};mesh.vertices=vertices;mesh.triangles=triangles;mesh.RecalculateBounds();
            var meshBounds=mesh.bounds;meshBounds.Expand(map.Radius*2);mesh.bounds=meshBounds;
            root=new GameObject("World exploration clouds",typeof(MeshFilter),typeof(MeshRenderer));root.transform.SetParent(parent,false);
            root.GetComponent<MeshFilter>().sharedMesh=mesh;
            var view=root.GetComponent<MeshRenderer>();view.sharedMaterial=material;view.shadowCastingMode=ShadowCastingMode.Off;view.receiveShadows=false;
        }
        private int CellAt(Vector3 position)
        {
            float q=position.x/(1.7320508075688772f*map.Radius)-position.z/(3*map.Radius),r=position.z/(1.5f*map.Radius),s=-q-r;
            int iq=Mathf.RoundToInt(q),ir=Mathf.RoundToInt(r),isum=Mathf.RoundToInt(s);
            float dq=Mathf.Abs(iq-q),dr=Mathf.Abs(ir-r),ds=Mathf.Abs(isum-s);
            if(dq>dr && dq>ds)iq=-ir-isum;else if(dr>ds)ir=-iq-isum;
            return cells.TryGetValue(Key(iq,ir),out int cell)?cell:-1;
        }
        internal bool Known(int cell) => cell<0 || data==null || data.IsKnown(cell+1);
        internal bool VisibleAt(Vector3 point) {int cell=CellAt(point);return cell>=0 && data!=null && data.IsVisible(cell+1);}
        internal void Bind(Material target)
        {target.SetTexture("_WorldFogMask",mask);target.SetVector("_WorldFogBounds",bounds);target.SetFloat("_WorldFogEnabled",1);}
        private void Paint(int cell)
        {
            byte lit=data.IsVisible(cell+1)?(byte)255:(byte)0,seen=data.IsKnown(cell+1)?(byte)255:(byte)0;
            for(int pixel=firstPixel[cell];pixel>=0;pixel=nextPixel[pixel]){pixels[pixel].r=lit;pixels[pixel].g=seen;}
        }
        internal void Update(WorldMapExplorationData value)
        {
            if(value.CellCount!=map.Cells.Length)throw new InvalidOperationException("World fog and map cell counts differ.");
            if(ReferenceEquals(data,value) && revision==value.Revision)return;
            bool reset=!ReferenceEquals(data,value) || value.KnownCount<knownCount;
            data=value;
            if(reset)
            {
                for(int i=0;i<pixels.Length;i++){pixels[i].r=0;pixels[i].g=0;}
                previousVisible.Clear();knownCount=0;
            }
            foreach(int cell in previousVisible)Paint(cell);
            for(int i=knownCount;i<data.KnownCount;i++)Paint(data.GetKnownAt(i)-1);
            previousVisible.Clear();
            for(int i=0;i<data.VisibleCount;i++){int cell=data.GetVisibleAt(i)-1;Paint(cell);previousVisible.Add(cell);}
            knownCount=data.KnownCount;revision=data.Revision;mask.SetPixels32(pixels);mask.Apply(false,false);
        }
        internal void SetVisible(bool value) => root.SetActive(value);
        private static void Release(Object value){if(Application.isPlaying)Object.Destroy(value);else Object.DestroyImmediate(value);}
        public void Dispose(){Release(root);Release(mesh);Release(material);Release(mask);}
    }
}

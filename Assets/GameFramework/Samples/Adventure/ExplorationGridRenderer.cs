using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ProjectY.Samples
{
    /// <summary>Nearby exploration cell fills. Navigation and fog remain owned by the MapArea snapshot.</summary>
    public sealed class ExplorationGridRenderer : IDisposable
    {
        [Serializable] public sealed class Settings
        {
            [Min(0)] public float ClearRadius = 3;
            [Min(.1f)] public float FadeRadius = 6;
            [Range(0,.2f)] public float CellInset = .045f;
            public Color Color = new Color(1f,.84f,.2f,.58f);
            public Color HoverColor = new Color(.12f,.9f,1f,.72f);
            public Color SelectedColor = new Color(.3f,1f,.28f,.8f);
            public void Validate()
            {
                if(ClearRadius<0 || FadeRadius<=ClearRadius || CellInset<0 || CellInset>=.5f || Color.a<0 || Color.a>1 || HoverColor.a<0 || HoverColor.a>1 || SelectedColor.a<0 || SelectedColor.a>1)
                    throw new InvalidOperationException("Invalid exploration grid radius, cell inset or opacity.");
            }
        }
        private readonly MapAreaViewData layout;
        private readonly Settings settings;
        private readonly Mesh mesh;
        private readonly Mesh hoverMesh, selectedMesh;
        private readonly Material material;
        private readonly MaterialPropertyBlock properties=new MaterialPropertyBlock();
        private readonly List<Vector3> vertices=new List<Vector3>(8192);
        private readonly List<int> triangles=new List<int>(8192);
        private readonly List<int> cells=new List<int>(512);
        private readonly Vector4[] centers=new Vector4[4];
        private readonly int[] memberCells=new int[4], memberLayers=new int[4];
        private readonly bool[] visible;
        private int members, revision=-1, visibleCount;
        private bool exploring;
        private int hovered=-1, selected=-1, hoverMeshCell=-1, selectedMeshCell=-1;
        public int CellCount => cells.Count;
        public ExplorationGridRenderer(MapAreaViewData layout,Settings settings)
        {
            settings.Validate();this.layout=layout;this.settings=settings;
            // An explicit Resources asset keeps the shader available in Player builds without Shader.Find/scene searches.
            var shader=Resources.Load<Shader>("Rendering/ExplorationGrid");
            if(shader==null) throw new InvalidOperationException("Missing Rendering/ExplorationGrid shader.");
            material=new Material(shader) {name="Exploration_Grid_Fade"};
            mesh=new Mesh {name="Exploration_NearbyHexes",indexFormat=IndexFormat.UInt32};mesh.MarkDynamic();
            hoverMesh=new Mesh {name="Exploration_Hover"};hoverMesh.MarkDynamic();
            selectedMesh=new Mesh {name="Exploration_Selected"};selectedMesh.MarkDynamic();
            visible=new bool[layout.Cells.Length];
        }
        public void SetState(MapAreaViewData.State state,bool isExploring)
        {
            exploring=isExploring;
            if(!isExploring) return;
            if(state.Members.Length<1 || state.Members.Length>4) throw new InvalidOperationException("Exploration grid requires 1–4 squad members.");
            bool changed=state.Members.Length!=members || state.Visible.Length!=visibleCount;
            for(int i=0;i<state.Members.Length;i++) changed|=memberCells[i]!=state.Members[i].CellIndex;
            if(state.Revision!=revision && !changed)
                foreach(var index in state.Visible) if(!visible[index]) {changed=true;break;}
            revision=state.Revision;
            if(!changed) return;
            members=state.Members.Length;visibleCount=state.Visible.Length;
            for(int i=0;i<members;i++) {memberCells[i]=state.Members[i].CellIndex;memberLayers[i]=layout.Cells[memberCells[i]].Layer;}
            Array.Clear(visible,0,visible.Length);foreach(var index in state.Visible) visible[index]=true;
            cells.Clear();vertices.Clear();triangles.Clear();layers.Clear();
            // Include a two-cell margin for interpolation and the outer edge of a hex. GPU fade hides it continuously.
            float limit=(settings.FadeRadius+2)*layout.Radius*1.7320508f;float limitSquared=limit*limit;
            foreach(var index in state.Visible)
            {
                var cell=layout.Cells[index];if(cell.Blocked) continue;
                bool nearby=false;
                for(int i=0;i<members&&!nearby;i++)
                {
                    var delta=cell.Position-layout.Cells[memberCells[i]].Position;delta.y=0;
                    nearby=cell.Layer==memberLayers[i] && delta.sqrMagnitude<=limitSquared;
                }
                if(!nearby) continue;
                cells.Add(index);
                AppendCell(index);
            }
            mesh.Clear();mesh.SetVertices(vertices);mesh.SetTriangles(triangles,0);mesh.SetUVs(0,layers);mesh.RecalculateBounds();layers.Clear();
        }
        private readonly List<Vector2> layers=new List<Vector2>(8192);
        private void AppendCell(int index)
        {
            int start=vertices.Count;
            TownSurfaceRenderer.AppendOverlay(layout,index,settings.CellInset,vertices,triangles);
            // Carry both floor and cell identity; interaction colors never spill into adjacent cells.
            for(int i=start;i<vertices.Count;i++) layers.Add(new Vector2(layout.Cells[index].Layer,index));
        }
        public bool ContainsCell(int index) => cells.Contains(index);
        public void SetInteraction(int hoveredCell,int selectedCell)
        {
            if(hoveredCell < -1 || hoveredCell>=layout.Cells.Length || selectedCell < -1 || selectedCell>=layout.Cells.Length)
                throw new ArgumentOutOfRangeException("Interaction cell is outside the current map.");
            hovered=hoveredCell;selected=selectedCell;
        }
        private int VisibleInteraction(int index) => index>=0 && visible[index] && !layout.Cells[index].Blocked ? index : -1;
        private static Color ShaderColor(Color value) => QualitySettings.activeColorSpace==ColorSpace.Linear?value.linear:value;
        // Exposed for deterministic presentation checks, using the same curve as the shader.
        public static float Opacity(float distance,float clearRadius,float fadeRadius)
        {
            if(clearRadius<0 || fadeRadius<=clearRadius) throw new ArgumentException("Invalid grid fade radii.");
            float t=Mathf.Clamp01((distance-clearRadius)/(fadeRadius-clearRadius));return 1-t*t*(3-2*t);
        }
        public void Draw(Camera camera,MapAreaViewData.State state,Func<int,Vector3> position)
        {
            if(!exploring || cells.Count==0) return;
            for(int i=0;i<members;i++)
            {
                var p=position(state.Members[i].ActorId);
                centers[i]=new Vector4(p.x,p.y,p.z,memberLayers[i]);
            }
            properties.SetVectorArray("_SquadCenters",centers);properties.SetInt("_SquadCount",members);
            float spacing=layout.Radius*1.7320508f;
            properties.SetVector("_FadeRadii",new Vector4(settings.ClearRadius*spacing,settings.FadeRadius*spacing,0,0));
            var hover=VisibleInteraction(hovered);var selection=VisibleInteraction(selected);
            properties.SetInt("_HoveredCell",hover);properties.SetInt("_SelectedCell",selection);
            properties.SetColor("_Color",ShaderColor(settings.Color));
            properties.SetColor("_HoverColor",ShaderColor(settings.HoverColor));properties.SetColor("_SelectedColor",ShaderColor(settings.SelectedColor));
            Graphics.DrawMesh(mesh,Matrix4x4.identity,material,0,camera,0,properties,ShadowCastingMode.Off,false,null,LightProbeUsage.Off);
            // Explicit visible targets remain readable beyond the ambient fade radius; only these two cells need extra geometry.
            if(hover!=selection) DrawInteraction(camera,hover,hoverMesh,ref hoverMeshCell);
            DrawInteraction(camera,selection,selectedMesh,ref selectedMeshCell);
        }
        private void DrawInteraction(Camera camera,int index,Mesh target,ref int cachedCell)
        {
            if(index<0 || ContainsCell(index)) return;
            if(cachedCell!=index)
            {
                vertices.Clear();triangles.Clear();layers.Clear();AppendCell(index);
                target.Clear();target.SetVertices(vertices);target.SetTriangles(triangles,0);target.SetUVs(0,layers);target.RecalculateBounds();
                cachedCell=index;
            }
            Graphics.DrawMesh(target,Matrix4x4.identity,material,0,camera,0,properties,ShadowCastingMode.Off,false,null,LightProbeUsage.Off);
        }
        private static void Destroy(UnityEngine.Object value)
        {if(Application.isPlaying) UnityEngine.Object.Destroy(value);else UnityEngine.Object.DestroyImmediate(value);}
        public void Dispose() {Destroy(mesh);Destroy(hoverMesh);Destroy(selectedMesh);Destroy(material);cells.Clear();vertices.Clear();triangles.Clear();layers.Clear();}
    }
}

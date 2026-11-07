using System;
using System.Collections.Generic;
using ProjectY.Data;
using UnityEngine;

namespace ProjectY.UI
{
    public sealed class StartMenuStage : MonoBehaviour
    {
        [SerializeField] private Camera menuCamera,mapCamera;
        [SerializeField] private Transform signpost,mapRoot;
        [SerializeField] private Transform[] signAnchors;
        [SerializeField] private GameObject treePrefab,housePrefab,castlePrefab;
        [SerializeField] private Material terrainMaterial;
        [SerializeField] private Vector3 homePosition=new Vector3(0,5.2f,13.5f),homeTarget=new Vector3(-1.2f,2,-.5f);
        [SerializeField] private Vector3 pagePosition=new Vector3(-8,4.7f,7.2f),pageTarget=new Vector3(-16,1.5f,-5);
        [SerializeField,Range(25,65)] private float homeFieldOfView=44;
        private GameObject miniature;
        private Mesh terrainMesh;
        public Camera Camera=>menuCamera;
        public Camera MapCamera=>mapCamera;
        public Transform[] SignAnchors=>signAnchors;
        public void Pose(float progress,float speed,float aspect)
        {
            float fit=Mathf.Max(1,1.62f/Mathf.Max(.7f,aspect));
            Vector3 home=homeTarget+(homePosition-homeTarget)*fit;
            menuCamera.transform.localPosition=Vector3.Lerp(home,pagePosition,progress);
            menuCamera.transform.LookAt(transform.TransformPoint(Vector3.Lerp(homeTarget,pageTarget,progress)));
            menuCamera.fieldOfView=homeFieldOfView+5*speed;menuCamera.aspect=aspect;
        }
        public void SetSnapshot(WorldMenuSnapshot snapshot)
        {
            snapshot.Validate();ClearMap();miniature=new GameObject("Menu snapshot");miniature.transform.SetParent(mapRoot,false);miniature.layer=30;
            int width=WorldMenuSnapshot.Width,height=WorldMenuSnapshot.Height;
            var vertices=new Vector3[(width-1)*(height-1)*6];var colors=new Color[vertices.Length];var triangles=new int[vertices.Length];int n=0;
            Action<int,int> add=(x,z)=>{int i=z*width+x;vertices[n]=new Vector3(x/(float)(width-1)*8.14f-4.07f,snapshot.Heights[i],z/(float)(height-1)*5.58f-2.79f);colors[n]=snapshot.Colors[i];triangles[n]=n;n++;};
            for(int z=0;z<height-1;z++)for(int x=0;x<width-1;x++){add(x,z);add(x,z+1);add(x+1,z+1);add(x,z);add(x+1,z+1);add(x+1,z);}
            terrainMesh=new Mesh{name="Bounded menu terrain"};terrainMesh.vertices=vertices;terrainMesh.colors=colors;terrainMesh.triangles=triangles;terrainMesh.RecalculateNormals();terrainMesh.RecalculateBounds();
            miniature.AddComponent<MeshFilter>().sharedMesh=terrainMesh;miniature.AddComponent<MeshRenderer>().sharedMaterial=terrainMaterial;
            for(int i=0;i<snapshot.Landmarks.Length;i++)
            {
                byte kind=snapshot.LandmarkKinds[i];var prefab=kind==0?treePrefab:kind==1?housePrefab:castlePrefab;
                if(prefab==null)throw new InvalidOperationException("Menu landmark prefab is not bound.");
                var model=Instantiate(prefab,miniature.transform,false);model.transform.localPosition=snapshot.Landmarks[i];
                model.transform.localScale=Vector3.one*(kind==0?.19f:kind==1?.24f:.19f);model.transform.localRotation=Quaternion.Euler(0,i*137.5f,0);
                foreach(var node in model.GetComponentsInChildren<Transform>(true))node.gameObject.layer=30;
            }
        }
        public void RenderThumbnail(Action<Camera> render)
        {
            var hidden=new List<Renderer>();
            foreach(var renderer in GetComponentsInChildren<Renderer>())
                if(renderer.enabled&&!renderer.transform.IsChildOf(mapRoot.parent)){hidden.Add(renderer);renderer.enabled=false;}
            try{render(mapCamera);}finally{foreach(var renderer in hidden)if(renderer!=null)renderer.enabled=true;}
        }
        private void ClearMap()
        {if(miniature!=null){miniature.SetActive(false);Remove(miniature);}miniature=null;if(terrainMesh!=null)Remove(terrainMesh);terrainMesh=null;}
        private static void Remove(UnityEngine.Object value){if(Application.isPlaying)Destroy(value);else DestroyImmediate(value);}
        private void OnDestroy()=>ClearMap();
#if UNITY_EDITOR
        public void Bind(Camera camera,Camera preview,Transform post,Transform map,Transform[] anchors,GameObject tree,GameObject house,GameObject castle,Material terrain)
        {menuCamera=camera;mapCamera=preview;signpost=post;mapRoot=map;signAnchors=anchors;treePrefab=tree;housePrefab=house;castlePrefab=castle;terrainMaterial=terrain;}
#endif
    }
}

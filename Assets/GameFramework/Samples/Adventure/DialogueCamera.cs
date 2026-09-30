using System;
using System.Collections.Generic;
using Cinemachine;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>拥有对话期间的输出相机；Cinemachine 混合双人、说话者与返回镜头。</summary>
    public sealed class DialogueCamera : IDisposable
    {
        private readonly Camera output;
        private readonly GameObject root;
        private readonly CinemachineBrain brain;
        private readonly CinemachineVirtualCamera saved, pair, npc, player;
        private readonly Rect originalRect;
        private readonly Vector3 originalPosition;
        private readonly Quaternion originalRotation;
        private readonly bool originalOrthographic;
        private readonly float originalFov, originalSize, originalNear, originalFar;
        private readonly float distance, height, pitch, fov, blendSeconds, closeup;
        private readonly IList<Bounds> obstacles;
        private readonly Func<Ray,float,float> terrainDistance;
        private Vector3 side;
        private bool returning, disposed;
        private float returnStarted;
        public bool Active => !disposed;
        public DialogueCamera(Camera camera, Transform parent, float distance, float height, float pitch, float fov, float blendSeconds, float closeup,
            IList<Bounds> obstacles, Func<Ray,float,float> terrainDistance)
        {
            output=camera;this.distance=distance;this.height=height;this.pitch=pitch;this.fov=fov;this.blendSeconds=blendSeconds;this.closeup=closeup;
            this.obstacles=obstacles;this.terrainDistance=terrainDistance;
            if (camera.GetComponent<CinemachineBrain>() != null) throw new InvalidOperationException("Dialogue camera needs exclusive Brain ownership.");
            originalRect=camera.rect;originalPosition=camera.transform.position;originalRotation=camera.transform.rotation;
            originalOrthographic=camera.orthographic;originalFov=camera.fieldOfView;originalSize=camera.orthographicSize;originalNear=camera.nearClipPlane;originalFar=camera.farClipPlane;
            root=new GameObject("DialogueCinemachine");root.transform.SetParent(parent,false);
            saved=Create("Return",10);pair=Create("Pair",0);npc=Create("NPC",0);player=Create("Player",0);
            saved.transform.SetPositionAndRotation(originalPosition,originalRotation);saved.m_Lens=LensSettings.FromCamera(camera);
            saved.m_Lens.ModeOverride=originalOrthographic?LensSettings.OverrideModes.Orthographic:LensSettings.OverrideModes.Perspective;
            brain=camera.gameObject.AddComponent<CinemachineBrain>();brain.m_UpdateMethod=CinemachineBrain.UpdateMethod.ManualUpdate;brain.m_IgnoreTimeScale=true;
            brain.m_DefaultBlend=new CinemachineBlendDefinition(CinemachineBlendDefinition.Style.EaseInOut,blendSeconds);
            brain.ManualUpdate();
        }
        private CinemachineVirtualCamera Create(string name,int priority)
        {
            var go=new GameObject(name);go.transform.SetParent(root.transform,false);
            var camera=go.AddComponent<CinemachineVirtualCamera>();camera.Priority=priority;
            camera.m_Lens=LensSettings.Default;camera.m_Lens.ModeOverride=LensSettings.OverrideModes.Perspective;
            camera.m_Lens.FieldOfView=fov;camera.m_Lens.NearClipPlane=.08f;camera.m_Lens.FarClipPlane=400;
            return camera;
        }
        public void Return()
        { if(disposed||returning)return;returning=true;returnStarted=Time.unscaledTime;saved.Priority=100; }
        private void Position(CinemachineVirtualCamera camera,Vector3 focus,float length)
        {
            var backward=(side*Mathf.Cos(pitch*Mathf.Deg2Rad)+Vector3.up*Mathf.Sin(pitch*Mathf.Deg2Rad)).normalized;
            var ray=new Ray(focus,backward);var actual=length;
            foreach(var obstacle in obstacles)if(obstacle.IntersectRay(ray,out var hit)&&hit>=0)actual=Mathf.Min(actual,Mathf.Max(.35f,hit-.2f));
            actual=Mathf.Max(.35f,terrainDistance(ray,actual)-.15f);
            var position=focus+backward*actual;
            camera.transform.SetPositionAndRotation(position,Quaternion.LookRotation(focus-position));
        }
        public void Tick(Vector3 actor,Vector3 target,string shot,float panelFraction)
        {
            if(disposed)return;
            if(returning)
            {
                brain.ManualUpdate();
                if(Time.unscaledTime-returnStarted>=blendSeconds && !brain.IsBlending)Dispose();
                return;
            }
            if(side.sqrMagnitude<.1f)
            {
                var axis=target-actor;axis.y=0;
                side=axis.sqrMagnitude>.01f?Vector3.Cross(axis.normalized,Vector3.up):-(originalRotation*Vector3.forward);
                side.y=0;side.Normalize();if(Vector3.Dot(side,originalPosition-(actor+target)*.5f)<0)side=-side;
            }
            output.rect=new Rect(0,0,Mathf.Clamp(1-panelFraction,.35f,1),1);
            var center=(actor+target)*.5f+Vector3.up*height;
            Position(pair,center,distance+Vector3.Distance(actor,target)*.55f);
            Position(npc,target+Vector3.up*height,distance*closeup);
            Position(player,actor+Vector3.up*height,distance*closeup);
            pair.Priority=shot=="pair"?30:0;npc.Priority=shot=="npc"?30:0;player.Priority=shot=="player"?30:0;
            brain.ManualUpdate();
        }
        public void Dispose()
        {
            if(disposed)return;disposed=true;
            brain.enabled=false;root.SetActive(false);
            output.transform.SetPositionAndRotation(originalPosition,originalRotation);output.rect=originalRect;
            output.orthographic=originalOrthographic;output.fieldOfView=originalFov;output.orthographicSize=originalSize;output.nearClipPlane=originalNear;output.farClipPlane=originalFar;
            if(Application.isPlaying){UnityEngine.Object.Destroy(brain);UnityEngine.Object.Destroy(root);}
            else{UnityEngine.Object.DestroyImmediate(brain);UnityEngine.Object.DestroyImmediate(root);}
        }
    }
}

using System;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Authorable presentation only: clips, grips and timing never change combat results.</summary>
    [CreateAssetMenu(menuName = "Project Y/Pawn Animation Set")]
    public sealed class PawnAnimationSet : ScriptableObject
    {
        [Serializable] public sealed class GripKey
        {
            [Range(0,1)] public float Time;
            public Vector3 WeaponRotation;
        }
        [Serializable] public sealed class Action
        {
            public int TemplateId;
            public string State;
            public AnimationClip Clip;
            [Min(.05f)] public float Duration = .6f;
            [Range(0, 1)] public float Impact = .45f;
            public bool UseAuthoredGrip;
            public GripKey[] GripKeys;
            public Vector3 OffGripOffset;
            public Vector3 GripRotation(float time)
            {
                if(GripKeys==null || GripKeys.Length<2) throw new InvalidOperationException("Authored grip needs at least two keys.");
                for(int i=1;i<GripKeys.Length;i++) if(time<=GripKeys[i].Time)
                    return Vector3.Lerp(GripKeys[i-1].WeaponRotation,GripKeys[i].WeaponRotation,Mathf.InverseLerp(GripKeys[i-1].Time,GripKeys[i].Time,time));
                return GripKeys[GripKeys.Length-1].WeaponRotation;
            }
        }
        [Serializable] public sealed class Hold
        {
            public int PoseId;
            public string IdleState;
            public Vector3 MainGripRotation, OffGripRotation;
            [Min(0)] public float HandHeadClearance = .24f;
            public string[] IdleVariants;
            public bool KeepWeaponUpright = true;
        }
        [Serializable] public sealed class AmbientVariant
        {
            public string State;
            public AnimationClip ReferenceClip;
            [Min(.001f)] public float Weight = 1;
        }
        [Serializable] public sealed class Skin
        {
            public int AssetId;
            public Mesh Mesh;
            public Material[] Materials;
        }
        public int[] BodyParts = { 1, 15, 19 };
        public RuntimeAnimatorController Controller;
        public Action[] Actions;
        public Hold[] Holds;
        public Skin[] Skins;
        public AnimationClip Hit, Death;
        public AmbientVariant[] IdleVariants, MoveVariants;
        public int VariationSeed = 137;
        public Vector2 IdleChangeSeconds = new Vector2(4,9), MoveChangeSeconds = new Vector2(7,13);
        public Vector2 IdlePlaybackRange = new Vector2(.92f,1.08f), MovePlaybackRange = new Vector2(.96f,1.04f);
        [Min(.05f)] public float AmbientBlendSeconds = .35f;
        [Min(.1f)] public float WalkSpeed = 2, RunSpeed = 4, BattleMoveSpeed = 7.5f;
        [Min(.05f)] public float BlendSeconds = .06f, HitSeconds = .3f, CorpseSeconds = .8f;
        [Range(.25f, 4)] public float PresentationSpeed = 1;
        [Min(0)] public float BaseHeight = .14f;
        public bool Supports(int bodyPart) => Array.IndexOf(BodyParts, bodyPart) >= 0;
        public Action GetAction(int id)
        {
            var action = Array.Find(Actions, item => item.TemplateId == id);
            return action ?? throw new InvalidOperationException("Missing pawn action: " + id);
        }
        public Hold GetHold(int id)
        {
            var hold = Array.Find(Holds, item => item.PoseId == id);
            return hold ?? throw new InvalidOperationException("Missing pawn hold: " + id);
        }
    }
}

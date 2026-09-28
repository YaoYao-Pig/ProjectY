using System;
using System.Collections.Generic;
using ProjectY.Data;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Manually clocked Humanoid playback. Does not write gameplay state or root position.</summary>
    public sealed class PawnAnimationView : MonoBehaviour
    {
        [Serializable] public sealed class Mount { public string Slot; public Transform Anchor; }
        [SerializeField] private Animator animator;
        [SerializeField] private PawnAnimationSet settings;
        [SerializeField] private Transform[] skinBones;
        [SerializeField] private Mount[] mounts;
        [SerializeField] private Transform mainGrip, offGrip;
        [SerializeField] private Transform rightUpper, rightLower, rightHand, leftUpper, leftLower, leftHand;
        [SerializeField] private Transform head;
        private readonly Queue<CombatActorData.PresentationAction> pending = new Queue<CombatActorData.PresentationAction>();
        private readonly Dictionary<string, Transform> anchors = new Dictionary<string, Transform>();
        private bool initialized, ready, dying, dead, reactionPending, moving;
        private int sequence, hp, poseId = -1, motionModuleId = -1;
        private float remaining, reactionDelay, deadElapsed;
        private string currentState, idleState = "Idle", actionState;
        private float actionDuration;
        private string interaction;
        private PawnAnimationSet.Action playingAction;
        private PawnAnimationSet.Hold holdSettings;
        private PawnAmbientMotion ambient;
        private int identity;
        private bool hasIdentity,ambientActive,ambientMoving;
        private EquipmentVisualData.Pose pose;
        private Vector3 facing;
        private bool riding;
        private Vector3 ridingSeat, ridingRestPosition, ridingRestHip;
        private Transform hips, leftThigh, leftShin, leftFoot, rightThigh, rightShin, rightFoot;
        public void SetRiding(bool value,Vector3 seat)
        {
            EnsureReady();riding=value;ridingSeat=seat;
            transform.localPosition=value?ridingRestPosition+seat-transform.localRotation*Vector3.Scale(ridingRestHip,transform.localScale):ridingRestPosition;
        }
        public PawnAnimationSet Settings => settings;
        public bool Busy => remaining > 0 || pending.Count > 0 || reactionPending || interaction != null;
        public float ReloadProgress => actionState == "Reload" && remaining > 0 ? 1 - remaining / actionDuration : -1;
        public bool DeathFinished => dead && !Busy && deadElapsed >= settings.CorpseSeconds;
        public bool IsDead => dead || dying;
        public Transform MainGrip => mainGrip;
        public Transform OffGrip => offGrip;
        public string AmbientState => ambient?.Current?.State;
        public void SetIdentity(int value)
        {
            if(hasIdentity && identity==value)return;
            identity=value;hasIdentity=true;ambient=new PawnAmbientMotion(settings,value);ambientActive=false;
        }

        public Transform Anchor(string slot)
        {
            EnsureReady();
            if (!anchors.TryGetValue(slot, out var anchor)) throw new InvalidOperationException("Missing animated mount: " + slot);
            return anchor;
        }
        private void EnsureReady()
        {
            if (ready) return;
            if (animator == null || settings == null || animator.avatar == null || !animator.avatar.isValid || !animator.avatar.isHuman)
                throw new InvalidOperationException("Pawn requires a valid Humanoid and animation set.");
            foreach (var mount in mounts) anchors.Add(mount.Slot, mount.Anchor);
            animator.runtimeAnimatorController = settings.Controller;
            animator.applyRootMotion = false;
            animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
            animator.enabled = false;
            animator.Rebind();
            hips=animator.GetBoneTransform(HumanBodyBones.Hips);
            ridingRestPosition=transform.localPosition;ridingRestHip=transform.InverseTransformPoint(hips.position);
            leftThigh=animator.GetBoneTransform(HumanBodyBones.LeftUpperLeg);leftShin=animator.GetBoneTransform(HumanBodyBones.LeftLowerLeg);leftFoot=animator.GetBoneTransform(HumanBodyBones.LeftFoot);
            rightThigh=animator.GetBoneTransform(HumanBodyBones.RightUpperLeg);rightShin=animator.GetBoneTransform(HumanBodyBones.RightLowerLeg);rightFoot=animator.GetBoneTransform(HumanBodyBones.RightFoot);
            ready = true;
            Play("Idle", 1, true);
            animator.Update(0);
        }
        public void SetHold(EquipmentVisualData.Pose value)
        {
            EnsureReady(); pose = value;
            int id = value == null ? 0 : value.HoldId;
            int module = value == null ? 0 : value.ModuleId;
            if (poseId == id && motionModuleId == module) return;
            motionModuleId = module;
            var hold = settings.GetHold(id); holdSettings=hold; poseId = id; idleState = hold.IdleState;
            mainGrip.localRotation = Quaternion.Euler(hold.MainGripRotation);
            offGrip.localRotation = Quaternion.Euler(hold.OffGripRotation);
            ambientActive=false;
            if (!Busy && !dead) {PlayAmbient(0,0,true);animator.Update(.001f);SolveGrip();}
        }
        public void Interact(bool talking)
        { EnsureReady(); interaction = talking ? "Talk" : "Interact"; }
        public void Capture(AdventureViewData.Actor actor, Vector3 target, float impactDelay)
        {
            EnsureReady();
            if (!initialized)
            {
                hp = actor.HP; sequence = actor.ActionSequence; initialized = true;
                return; // A newly revealed actor must not replay historical actions.
            }
            foreach (var action in actor.Actions)
                if (action.Sequence > sequence) pending.Enqueue(action);
            sequence = actor.ActionSequence;
            facing = target;
            if (actor.HP < hp)
            {
                reactionPending = true; reactionDelay = impactDelay; dying = actor.HP <= 0;
            }
            hp = actor.HP;
        }
        public void Tick(float deltaTime, float speed, Transform owner)
        {
            EnsureReady();
            float dt = Mathf.Max(0, deltaTime) * settings.PresentationSpeed;
            if (dt <= 0) return;
            moving = !riding && speed > .025f;
            if (reactionPending)
            {
                reactionDelay -= dt;
                if (reactionDelay <= 0)
                {
                    reactionPending = false;
                    playingAction = null;
                    currentState = null;
                    if (dying) { pending.Clear(); dead = true; remaining = settings.Death.length; Play("Death", 1, false); }
                    else { remaining = settings.HitSeconds; Play("Hit", settings.Hit.length / remaining, false); }
                }
            }
            else if (remaining > 0) remaining = Mathf.Max(0, remaining - dt);
            if (dead)
            {
                if (remaining > 0) animator.Update(Mathf.Min(dt, remaining));
                else deadElapsed += dt;
                return;
            }
            if (remaining <= 0 && !reactionPending && !moving)
            {
                while (pending.Count > 0 && remaining <= 0)
                {
                    var action = settings.GetAction(pending.Dequeue().TemplateId);
                    if (string.IsNullOrEmpty(action.State)) continue; // Explicit no-motion action.
                    var direction = facing - owner.position; direction.y = 0;
                    if (direction.sqrMagnitude > .001f) owner.rotation = Quaternion.LookRotation(direction);
                    remaining = actionDuration = action.Duration; actionState = action.State; currentState = null; playingAction=action;
                    Play(action.State, action.Clip.length / action.Duration, false);
                }
                if(remaining<=0 && interaction!=null)
                {remaining=interaction=="Talk"?1.2f:.8f;currentState=null;Play(interaction,1,false);interaction=null;}
            }
            if (remaining <= 0)
            {
                actionState = null;
                playingAction = null;
                PlayAmbient(dt,riding?0:speed,false);
            }
            animator.Update(dt);
            if(riding)
            {
                hips.position=owner.TransformPoint(ridingSeat);
                SolveArm(leftThigh,leftShin,leftFoot,owner.TransformPoint(ridingSeat+new Vector3(-.30f,-.70f,.05f)),
                    owner.TransformPoint(ridingSeat+new Vector3(-.50f,-.18f,.45f)),leftFoot.rotation);
                SolveArm(rightThigh,rightShin,rightFoot,owner.TransformPoint(ridingSeat+new Vector3(.30f,-.70f,.05f)),
                    owner.TransformPoint(ridingSeat+new Vector3(.50f,-.18f,.45f)),rightFoot.rotation);
            }
            SolveGrip();
        }
        private void Play(string state, float speed, bool immediate)
        {
            ambientActive=false;
            animator.SetFloat("PlaybackSpeed", speed);
            if (currentState == state && !immediate) return;
            currentState = state;
            if (immediate) animator.Play(state, 0, 0); else animator.CrossFadeInFixedTime(state, settings.BlendSeconds, 0, 0);
        }
        private void PlayAmbient(float deltaTime,float speed,bool immediate)
        {
            if(ambient==null || holdSettings==null)throw new InvalidOperationException("Pawn animation identity/hold must be configured before playback.");
            bool walking=speed>.025f;bool changed=ambient.Update(deltaTime,holdSettings,walking);
            float gait=Mathf.Clamp01((speed-settings.WalkSpeed)/Mathf.Max(.01f,settings.RunSpeed-settings.WalkSpeed));
            float rate=walking?Mathf.Clamp(speed/Mathf.Lerp(settings.WalkSpeed,settings.RunSpeed,gait),.25f,3):1;
            animator.SetFloat("Speed",gait);animator.SetFloat("PlaybackSpeed",rate*ambient.Rate);
            if(immediate || !ambientActive || changed)
            {
                float phase=ambientActive && ambientMoving && walking ? Mathf.Repeat(animator.GetCurrentAnimatorStateInfo(0).normalizedTime,1) : ambient.Phase;
                currentState=ambient.Current.State;
                if(immediate)animator.Play(currentState,0,phase);
                else animator.CrossFadeInFixedTime(currentState,settings.AmbientBlendSeconds,0,phase*ambient.Current.ReferenceClip.length);
            }
            ambientMoving=walking;ambientActive=true;
        }
        public void Skip()
        {
            pending.Clear(); reactionPending = false; remaining = 0; interaction = null;
            if (dying || dead) {dead = true; deadElapsed = settings.CorpseSeconds; animator.Play("Death", 0, .999f); animator.Update(0);}
            else {playingAction=null;actionState=null;PlayAmbient(0,0,true);animator.Update(0);SolveGrip();}
        }
        private void SolveGrip()
        {
            // Explicit two-bone solve also runs under the portrait/Edit Mode clock, without relying on animation callbacks.
            if (pose == null || dead || dying) return;
            var mainLocal = Quaternion.Euler(holdSettings.MainGripRotation);
            var offLocal = Quaternion.Euler(holdSettings.OffGripRotation);
            mainGrip.localRotation = mainLocal; offGrip.localRotation = offLocal;
            if(!pose.OffHandFollowsWeapon)
            {
                bool keepFrame=(ambientActive || pose.LockWeaponOrientation) && holdSettings.KeepWeaponUpright;
                var mainFrame = keepFrame ? transform.rotation*Quaternion.Euler(pose.WeaponRotation) : mainGrip.rotation;
                var offFrame = keepFrame ? transform.rotation*Quaternion.Euler(pose.OffWeaponRotation) : offGrip.rotation;
                if (playingAction != null && playingAction.UseAuthoredGrip)
                {
                    var authoredFrame=transform.rotation*Quaternion.Euler(playingAction.GripRotation(1-remaining/actionDuration));
                    if(playingAction.State=="OffAttack")offFrame=authoredFrame;else mainFrame=authoredFrame;
                }
                if (pose.HasMainWeapon) rightHand.rotation = mainFrame * Quaternion.Euler(pose.WeaponRotationOffset) * Quaternion.Euler(pose.PrimaryGrip.Rotation) * Quaternion.Inverse(mainLocal);
                if (pose.HasOffWeapon) leftHand.rotation = offFrame * Quaternion.Euler(pose.OffWeaponRotationOffset) * Quaternion.Euler(pose.SecondaryGrip.Rotation) * Quaternion.Inverse(offLocal);
                else if (pose.OffHandMode == "shield")
                {
                    var rotation = offFrame * Quaternion.Inverse(offLocal);
                    SolveArm(leftUpper,leftLower,leftHand,transform.TransformPoint(pose.OffHand)-rotation*offGrip.localPosition,transform.TransformPoint(pose.OffElbow),rotation);
                }
                return;
            }
            if(currentState=="Hit")return;
            bool authored=playingAction!=null && playingAction.UseAuthoredGrip;
            // Two-hand weapon orientation must remain authored during crossfades too; a source wrist can turn a long blade through the head.
            Quaternion baseRotation=transform.rotation*Quaternion.Euler(authored ? playingAction.GripRotation(1-remaining/actionDuration) : pose.WeaponRotation);
            Quaternion weaponRotation=baseRotation*Quaternion.Euler(pose.WeaponRotationOffset);
            Quaternion mainRotation=weaponRotation*Quaternion.Euler(pose.PrimaryGrip.Rotation)*Quaternion.Inverse(mainLocal);
            Quaternion offRotation=weaponRotation*Quaternion.Euler(pose.SecondaryGrip.Rotation)*Quaternion.Inverse(offLocal);
            Vector3 mainOffset=mainRotation*mainGrip.localPosition, offOffset=offRotation*offGrip.localPosition;
            Vector3 primaryPosition=Vector3.Scale(pose.PrimaryGrip.Position,pose.MainWeaponScale);
            Vector3 secondaryPosition=Vector3.Scale(pose.SecondaryGrip.Position,pose.MainWeaponScale);
            Vector3 separation=weaponRotation*(secondaryPosition-primaryPosition);
            if(authored) separation+=weaponRotation*playingAction.OffGripOffset*Mathf.Sin((1-remaining/actionDuration)*Mathf.PI);
            // Keep the authored primary anchor while rotating the weapon and secondary grip around it.
            Vector3 grip=transform.TransformPoint(pose.MainHand)+baseRotation*primaryPosition;
            grip.y=Mathf.Min(grip.y,head.position.y-holdSettings.HandHeadClearance);
            float rightReach=(rightLower.position-rightUpper.position).magnitude+(rightHand.position-rightLower.position).magnitude;
            float leftReach=(leftLower.position-leftUpper.position).magnitude+(leftHand.position-leftLower.position).magnitude;
            // Project into both arm reach spheres; avoids stretching one arm to an unreachable grip.
            for(int i=0;i<6;i++)
            {
                grip=rightUpper.position+Vector3.ClampMagnitude(grip-mainOffset-rightUpper.position,rightReach*.985f)+mainOffset;
                grip=leftUpper.position+Vector3.ClampMagnitude(grip+separation-offOffset-leftUpper.position,leftReach*.985f)-separation+offOffset;
                grip.y=Mathf.Min(grip.y,head.position.y-holdSettings.HandHeadClearance);
            }
            SolveArm(rightUpper,rightLower,rightHand,grip-mainOffset,transform.TransformPoint(pose.MainElbow),mainRotation);
            SolveArm(leftUpper,leftLower,leftHand,mainGrip.position+separation-offOffset,transform.TransformPoint(pose.OffElbow),offRotation);
        }
        private static void SolveArm(Transform upper,Transform lower,Transform hand,Vector3 goal,Vector3 pole,Quaternion handRotation)
        {
            Vector3 shoulder=upper.position;float a=Vector3.Distance(shoulder,lower.position),b=Vector3.Distance(lower.position,hand.position);
            Vector3 delta=goal-shoulder;float distance=Mathf.Clamp(delta.magnitude,Mathf.Abs(a-b)+.0001f,a+b-.0001f);
            Vector3 direction=delta.normalized;Vector3 bend=Vector3.ProjectOnPlane(pole-shoulder,direction);
            if(bend.sqrMagnitude<.000001f) bend=Vector3.ProjectOnPlane(lower.position-shoulder,direction);
            if(bend.sqrMagnitude<.000001f) bend=Vector3.Cross(direction,Vector3.up);
            float along=(a*a-b*b+distance*distance)/(2*distance);
            Vector3 elbow=shoulder+direction*along+bend.normalized*Mathf.Sqrt(Mathf.Max(0,a*a-along*along));
            upper.rotation=Quaternion.FromToRotation(lower.position-shoulder,elbow-shoulder)*upper.rotation;
            lower.rotation=Quaternion.FromToRotation(hand.position-lower.position,goal-lower.position)*lower.rotation;
            hand.rotation=handRotation;
        }
        public GameObject CreateSkin(int assetId, Transform parent)
        {
            var skin = Array.Find(settings.Skins, item => item.AssetId == assetId);
            if (skin == null) throw new InvalidOperationException("Missing skinned wearable: " + assetId);
            var obj = new GameObject("SkinnedWearable_" + assetId);
            obj.transform.SetParent(parent, false);
            var renderer = obj.AddComponent<SkinnedMeshRenderer>();
            renderer.sharedMesh = skin.Mesh; renderer.sharedMaterials = skin.Materials;
            renderer.bones = skinBones; renderer.rootBone = skinBones[0]; renderer.updateWhenOffscreen = true;
            return obj;
        }
#if UNITY_EDITOR
        public void Bind(Animator value, PawnAnimationSet set, Transform[] bones, Mount[] bindings, Transform main, Transform off)
        {
            animator = value; settings = set; skinBones = bones; mounts = bindings; mainGrip = main; offGrip = off;
            rightUpper=value.GetBoneTransform(HumanBodyBones.RightUpperArm);rightLower=value.GetBoneTransform(HumanBodyBones.RightLowerArm);rightHand=value.GetBoneTransform(HumanBodyBones.RightHand);
            leftUpper=value.GetBoneTransform(HumanBodyBones.LeftUpperArm);leftLower=value.GetBoneTransform(HumanBodyBones.LeftLowerArm);leftHand=value.GetBoneTransform(HumanBodyBones.LeftHand);
            head=value.GetBoneTransform(HumanBodyBones.Head);
        }
#endif
    }
}

// Execute once after the shared compilation, in the already open Editor. No Play or asset writes.
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.BlockParticleEffects effects=null;
int baseline=ProjectY.Samples.BlockParticleEffects.ActiveGlobalParticleCount;
System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.InvalidOperationException(message);};
try
{
    var root=new UnityEngine.GameObject("Skill depth isolated check");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    effects=new ProjectY.Samples.BlockParticleEffects(root.transform,illuminate:true);
    var profile=new ProjectY.Samples.BlockEffectProfile {Id=2304,Name="Meteor fixture",Pattern="meteor",Count=64,
        Color=new UnityEngine.Color(1f,.3f,.08f),Accent=UnityEngine.Color.white,Lifetime=2.6f,Size=.24f,
        Radius=1.65f,Height=5f,Emission=7f,Speed=3.8f,Gravity=4f};
    effects.Play(profile,UnityEngine.Vector3.left,UnityEngine.Vector3.zero,42);
    var systems=root.GetComponentsInChildren<UnityEngine.ParticleSystem>();
    check(systems.Length==1,"One staged meteor must use one pooled system.");
    var particles=new UnityEngine.ParticleSystem.Particle[64];
    systems[0].GetParticles(particles);
    float initialHeight=particles[0].position.y;
    check(initialHeight>4.5f && particles[0].startSize>.8f,"Meteor must start with a visible elevated rock.");
    var renderer=systems[0].GetComponent<UnityEngine.ParticleSystemRenderer>();
    check(renderer.mesh.triangles.Length==60,"Meteor must use the closed twenty-face rock mesh.");
    effects.Tick(.2f);systems[0].GetParticles(particles);
    check(particles[0].position.y<initialHeight-1f && particles[0].position.y>1f,"Meteor core must descend before impact.");
    float pausedY=particles[0].position.y;
    effects.Tick(0f);systems[0].GetParticles(particles);
    check(particles[0].position.y==pausedY,"A paused host must freeze spell motion.");
    effects.Tick(.25f);int live=systems[0].GetParticles(particles);bool impact=false;
    for(int i=0;i<live;i++)if(particles[i].startSize>0f && particles[i].position.y<1f)impact=true;
    check(impact,"Delayed impact fragments must appear at the landing point.");
    for(int i=0;i<12;i++)effects.Play(profile,UnityEngine.Vector3.left,UnityEngine.Vector3.zero,50+i);
    var lights=root.GetComponentsInChildren<UnityEngine.Light>();
    check(lights.Length==4,"A spell pool must cap transient lights at four.");
    foreach(var light in lights)check(light.shadows==UnityEngine.LightShadows.None && light.range<=5f,"Spell lights must remain bounded and shadow-free.");
    effects.Clear();check(effects.ActiveParticleCount==0,"Clear must release all particles including delayed fragments.");
    foreach(var light in lights)check(!light.enabled,"Clear must disable transient lights.");
    profile.Pattern="mist";profile.Emission=1.35f;profile.Size=.2f;profile.Height=.55f;
    effects.Play(profile,UnityEngine.Vector3.zero,UnityEngine.Vector3.zero,83);effects.Tick(.1f);
    systems[0].GetParticles(particles);
    check(particles[0].startColor.a<90 && particles[0].position.y<.8f,"Mist must remain translucent and below head height.");
    foreach(var light in lights)check(!light.enabled,"Mist must not create a bright area light.");
    effects.Tick(9f);check(!effects.Busy,"All staged particles must expire under a large final step.");
    effects.Dispose();effects=null;
    check(ProjectY.Samples.BlockParticleEffects.ActiveGlobalParticleCount==baseline,"Spell disposal must restore the global particle budget.");
    return "PASS staged meteor descent/impact, host pause, low-poly rock, light budget/cleanup, translucent mist, particle lifetime/disposal.";
}
finally
{
    effects?.Dispose();
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}

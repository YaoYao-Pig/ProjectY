const fs=require('node:fs');const path=require('node:path');
const base=path.resolve(__dirname,'../../Art/UIRefresh/2026-10-25');
const before=JSON.parse(fs.readFileSync(path.join(base,'matte/state-before.json'),'utf8').replace(/^\uFEFF/,''));
const after=JSON.parse(fs.readFileSync(path.join(base,'state-current.json'),'utf8'));
// Only these native layout additions belong to the adaptive pass; never waive removals.
const layoutAdditions=new Map([
 ['Common/TabButtonWidget',new Set(['LayoutElement'])],
 ['Narrative/NarrativeEntryWidget',new Set(['LayoutElement'])],
 ['Narrative/DialogueEntryWidget',new Set(['LayoutElement'])],
 ['Adventure/StoryChoiceWidget',new Set(['VerticalLayoutGroup','LayoutElement'])],
 ['Adventure/JournalSkillWidget',new Set(['VerticalLayoutGroup'])]
].map(([name,types])=>['Assets/DynamicAsset/UI/Prefabs/'+name+'.prefab',types]));
const report=[];
for(const old of before){
 const now=after.find(x=>x.path===old.path);if(!now)throw Error('Missing prefab '+old.path);
 const artBindings=[];
 for(const b of old.bindings){const n=now.bindings.find(x=>x.key===b.key);if(!n)throw Error('Removed binding '+b.key);if(b.key==='Skin'){if(n.type!==b.type)throw Error('Changed Skin binding type');artBindings.push('Skin');}else if(JSON.stringify(n)!==JSON.stringify(b))throw Error('Changed business binding '+old.path+' '+b.key);}
 if(JSON.stringify(old.localized)!==JSON.stringify(now.localized))throw Error('Localization binding changed '+old.path);
 if(JSON.stringify(old.protectedViews)!==JSON.stringify(now.protectedViews))throw Error('Protected 3D view changed '+old.path);
 const layoutChanges=[],addedComponents=[];
 for(const r of old.rects){
  const n=now.rects.find(x=>x.path===r.path);if(!n)throw Error('Old object removed '+old.path+' '+r.path);
  const additions=[...n.components];
  for(const component of r.components){const index=additions.indexOf(component);if(index<0)throw Error('Old component removed '+old.path+' '+r.path+' '+component);additions.splice(index,1);}
  const allowed=r.path===''?layoutAdditions.get(old.path):undefined;
  for(const component of additions){
   if(!allowed?.has(component)||r.components.includes(component)||additions.filter(x=>x===component).length!==1)throw Error('Unexpected component added '+old.path+' '+r.path+' '+component);
   addedComponents.push({path:r.path,type:component});
  }
  const {components:oldComponents,...oldRect}=r;const {components:newComponents,...newRect}=n;
  if(JSON.stringify(newRect)!==JSON.stringify(oldRect))layoutChanges.push(r.path);
 }
 report.push({path:old.path,businessBindingsPreserved:old.bindings.length-artBindings.length,artBindingsRepointed:artBindings,protectedViews:old.protectedViews.length,visualLayoutChanges:layoutChanges,addedComponents,addedBindings:now.bindings.filter(x=>!old.bindings.some(y=>y.key===x.key)).map(x=>x.key)});
}
const result={passed:true,prefabs:report.length,protected3DViews:report.reduce((n,x)=>n+x.protectedViews,0),businessBindingsPreserved:report.reduce((n,x)=>n+x.businessBindingsPreserved,0),report};
fs.writeFileSync(path.join(base,'matte/preservation-check.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));

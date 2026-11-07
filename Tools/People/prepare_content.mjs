// First-version source schemas and content. Existing rows are changed through Content Center review/save.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {readWorkspace,review,save} from '../ContentCenter/workspace.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const folder=path.join(root,'Config/Tables/People');fs.mkdirSync(folder,{recursive:true});
const field=(name,type,description,extra={})=>({name,type,description,...extra});
const profiles={version:1,name:'PeopleProfileTable',description:'人物动机与可配置的首版招募门槛；后续成长通过同一动机身份关联。',key:'id',fields:[
 field('id','int','稳定动机ID',{min:1,max:4}),field('kind','enum','招募规则',{values:['livelihood','apprentice','guardian','respect']}),
 ...['name','background','opening','request','joinedText'].map(name=>field(name,'text','人物动机与对白：'+name)),
 field('residentTemplateIds','int[]','适用普通居民模板',{ref:'MapAreaTownNpcTable'}),
 field('fee','int','付费路线金币',{min:0}),field('mentorSkills','int','导师已学技能数',{min:0}),
 field('victories','int','战阵认同所需真实胜利',{min:0}),field('trustRequired','int','关系路线所需信任',{min:0,max:100})],rows:[
 {id:1,kind:'livelihood',name:'重新谋生',background:'靠零工维持生计的人，希望积攒一笔安家的钱。',opening:'我愿意靠自己的双手挣一份前程，但离开前，总得把眼前的生活安顿好。',request:'提供一笔安家预支，或完成我发布的委托。帮助我的熟人，也会让我更信任你。',joinedText:'这笔信任我记下了。今后的路，我会自己走稳。',residentTemplateIds:[1,2,3,4],fee:80,mentorSkills:0,victories:0,trustRequired:40},
 {id:2,kind:'apprentice',name:'寻找师友',background:'已经掌握一些本职手艺，渴望跟随有经验的同行学习新本领。',opening:'我不想一辈子只会眼前这门手艺。你的队伍里，有能教我些什么的人吗？',request:'让掌握至少两门后天技艺的同伴担任导师；或者先帮我完成委托，再资助学习所需。',joinedText:'那就让我跟着你们学。等有一天，我也想把自己的本领传给别人。',residentTemplateIds:[1,2,5],fee:40,mentorSkills:2,victories:0,trustRequired:20},
 {id:3,kind:'guardian',name:'守护牵挂',background:'想看看远方，也担心留在故乡的熟人无人照应。',opening:'我不是不想出发。只是这里还有我放不下的人，不能说走就走。',request:'完成本镇的一份清剿或护送委托，让道路安全些；或者先邀请我的熟人同行，并赢得我的信任。',joinedText:'终于可以放心往前走了。以后，我也会站在同伴需要我的地方。',residentTemplateIds:[1,2,4],fee:0,mentorSkills:0,victories:0,trustRequired:20},
 {id:4,kind:'respect',name:'战阵认同',background:'经历过真实厮杀的战士，愿意听取有战绩之人的提议。',opening:'阵营不同，不代表每一场架都非打不可。让我看看你们有没有值得追随的本事。',request:'赢得两场正式战斗，队中有不低于我等级的成员，并准备解除旧约的费用。',joinedText:'旧约已清，往后的本事就用在新同伴身上。但我的经历，我不会忘记。',residentTemplateIds:[],fee:120,mentorSkills:0,victories:2,trustRequired:0}
]};
const names=['阿洛','米恩','希雅','洛缇','艾默','诺恩','莱维','伊芙','塔林','芙兰','塞恩','温蒂','科林','露恩','佩林','瑟雅','丹恩','莫莉','艾瑞','菲恩','奥蕾','瑞恩','莉珂','柏恩'];
const nameTable={version:1,name:'PeopleNameTable',description:'世界人物姓名池，生成一次后保存名称ID。',key:'id',fields:[field('id','int','姓名ID',{min:1}),field('name','text','人物姓名')],rows:names.map((name,i)=>({id:i+1,name}))};
for(const table of [profiles,nameTable]){const filename=path.join(folder,table.name+'.json');if(fs.existsSync(filename))throw new Error('Source already exists: '+filename);fs.writeFileSync(filename,JSON.stringify(table,null,2)+'\n','utf8');}
const state=readWorkspace(root),tables=new Map(state.entries.map(e=>[e.table.name,e.table]));
const operations=[];
const growth=tables.get('GrowthProfileTable'),pawn=tables.get('PawnTemplateTable');
const humans=tables.get('CombatUnitTable').rows.filter(row=>row.bodyInjuries!==false);
for(const unit of humans){
 if(!growth.rows.some(row=>row.unitId===unit.id))operations.push({op:'upsert',table:growth.name,row:{id:unit.id,unitId:unit.id,treeIds:[1],traitIds:[],potential:2,initialProfessionId:unit.id===1202?4:unit.id>=1201?12:unit.skillIds.includes(2)?2:1}});
 if(!pawn.rows.some(row=>row.unitId===unit.id)){
  const source=pawn.rows.find(row=>row.unitId===1);if(!source)throw new Error('No human pawn template');
  const next=Math.max(0,...pawn.rows.map(row=>row.id),...operations.filter(op=>op.table===pawn.name).map(op=>op.row.id))+1;
  operations.push({op:'upsert',table:pawn.name,row:{...source,id:next,unitId:unit.id}});
 }
}
const patch={revision:state.revision,operations};
fs.writeFileSync(path.join(root,'Tools/People/base-content.patch.json'),JSON.stringify(patch,null,2)+'\n');
const checked=review(root,patch);console.log(JSON.stringify({valid:checked.valid,operations:operations.length}));
console.log(JSON.stringify(save(root,patch)));

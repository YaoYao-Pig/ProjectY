import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {readWorkspace,review,save} from '../ContentCenter/workspace.mjs';
import {exportNarrative} from '../Narrative/workspace.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const defaults={
 PeopleAskCommissions:'看看你需要帮忙的事。',PeopleCommissionsOpening:'这些就是眼下需要帮忙的事情。',
 PeopleSaveInvalid:'人物记录与当前远征不一致，无法恢复。',PeopleRecruitInvalid:'这位人物当前无法离开原来的编制；已交战或仅剩一人的队伍需要先解决原有事务。',PeopleGrowthInvalid:'个人成长记录无效，请重新打开人物界面。',
 PeopleDialogueTalk:'交谈',PeopleDialogueTalkOwned:'交谈与培养',PeopleDialogueTalkOther:'交谈与招募',PeopleDialogueInspectionHint:'交谈了解人物的处境与愿望，讨论招募或共同成长。',PeopleDialogueHint:'共同经历会影响招募意愿与成长机会，选项下方会显示所需条件。',PeopleDialogueBusy:'请先结束当前对话',PeopleDialogueUnavailable:'当前无法与这位人物交谈',PeopleDialogueLivingActor:'需要一位能够交谈的队员',PeopleDialogueStale:'对话已推进，请选择当前选项',PeopleDialogueLeave:'暂时告别',PeopleDialogueNoInterjection:'请从当前人物的交谈选项中选择',
 PeopleExplorationOnly:'请在探索间隙交谈。',PeopleUnavailable:'当前无法与这位人物交谈。',PeopleComeCloser:'请先沿可通行道路靠近这位人物。',PeopleDuty:'这位人物仍需履行城镇职务，暂时不能离岗同行。',PeopleWorldParleyOnly:'请先在大地图上主动接触这支队伍，再与其中的成员交涉。',PeopleAuthoredNpc:'这位人物有自己的故事，请通过原有对话了解招募条件。',
 PeopleCaption:'%s · 信任 %d',PeopleOpening:'%s\n\n%s\n\n%s',PeopleBond:'在这里，我最牵挂的熟人是%s。',PeopleNoBond:'眼前的生活和未来的打算，都需要认真考虑。',
 PeopleAlreadyJoined:'这位人物已经加入队伍。',PeopleFinishCommission:'请先完成这位人物已经交给你的委托，再邀请同行。',PeopleAskBackground:'聊聊你的来历与牵挂。',PeopleAskWish:'接下来，你希望做些什么？',
 PeopleOfferAdvance:'提供 %d 金币安家预支，邀请同行。',PeopleNeedCoins:'需要 %d 金币。',PeopleOfferTrust:'以已经建立的信任邀请同行。',PeopleNeedTrust:'完成此人的委托，或通过帮助熟人将信任提升至 %d；当前信任 %d。',
 PeopleOfferMentor:'由队中有经验的同伴带领你学习。',PeopleNeedMentor:'需要一位掌握至少 %d 门已学技艺的存活同伴；当前最多 %d 门。',PeopleOfferSponsor:'帮助完成委托后，提供 %d 金币学习资助。',PeopleNeedSponsor:'需要完成此人的委托，并准备 %d 金币。',
 PeopleOfferSafety:'道路已经更安全了，一起出发吧。',PeopleNeedSafety:'需要完成本镇的一份清剿或护送委托。',PeopleOfferBond:'你牵挂的熟人已在队中，一起同行吧。',PeopleNeedBond:'需要你牵挂的熟人已经入队，且信任达到 %d。',
 PeopleOfferRespect:'展示战绩，并支付 %d 金币解除旧约。',PeopleNeedRespect:'需要 %d 场正式胜利、%d 金币，以及至少等级 %d 的存活同伴；当前胜利 %d 场、最高等级 %d。',
 PeopleJoinedTitle:'新的同行者',PeopleJoinedMemory:'%s因为「%s」决定同行。双方的约定是：%s',PeopleJourney:'旅途中',PeopleGrowthOption:'%s\n%s',PeopleGrowthSummary:'%s\n\n%s\n\n%s',
 PeopleWorldTalk:'与%s交涉',PeopleWorldTalkBody:'了解这位人物的来历与意愿，讨论是否愿意离开旧编制。原有能力、装备和伤势都会保留。',PeopleWorldStale:'队伍成员或接触状态已变化，请重新选择。'
};
const growth=JSON.parse(fs.readFileSync(path.join(root,'Tools/People/personal-growth-language.json'),'utf8'));
const entries=Object.fromEntries(Object.entries(defaults).map(([key,value])=>[key,{default:value,description:'世界人物与招募；格式参数按调用顺序填写'}]));
const descriptions={PeopleCaption:'人物对话副标题；动机名称、信任值',PeopleOpening:'人物介绍；背景、开场对白、完整熟人说明',
 PeopleBond:'熟人牵挂介绍；熟人姓名',PeopleOfferAdvance:'安家预支招募选项；金币数',PeopleNeedCoins:'招募金币不足；需要金币数',
 PeopleNeedTrust:'信任路线要求；目标信任值、当前信任值',PeopleNeedMentor:'导师路线要求；目标技能数、当前最多已学技能数',
 PeopleOfferSponsor:'学习资助招募选项；金币数',PeopleNeedSponsor:'学习资助路线要求；需要金币数',PeopleNeedBond:'熟人同行路线要求；目标信任值',
 PeopleOfferRespect:'战阵认同招募选项；解约金币数',PeopleNeedRespect:'战阵认同要求；目标胜利数、金币、目标等级、当前胜利数、当前最高等级',
 PeopleJoinedMemory:'加入经历正文；人物姓名、动机名称、所选招募约定',PeopleGrowthOption:'成长选项说明；禁用原因、完整条件和奖励说明',
 PeopleGrowthSummary:'个人成长话题；阶段标题、阶段正文、进度说明',PeopleWorldTalk:'世界队伍交涉选项；人物姓名'};
for(const [key,description]of Object.entries(descriptions))entries[key].description=description;
Object.assign(entries,growth);
const languageFile=path.join(root,'Lua/Language.lua');let text=fs.readFileSync(languageFile,'utf8');
let additions='';for(const [key,row]of Object.entries(entries)){
 if(new RegExp('^\\s*'+key+'\\s*=','m').test(text)){
  text=text.replace(new RegExp('^(\\s*'+key+'\\s*=.*?,)\\s*--.*$','m'),'$1 -- '+row.description);continue;
 }
 additions+='    '+key+' = '+JSON.stringify(row.default)+', -- '+row.description+'\n';
}
if(!text.includes('-- @localization-end'))throw new Error('Language marker missing');
fs.writeFileSync(languageFile,text.replace('-- @localization-end',additions+'-- @localization-end'),'utf8');
const rows=JSON.parse(fs.readFileSync(path.join(root,'Tools/People/traits.rows.json'),'utf8'));
const state=readWorkspace(root),traits=state.entries.find(e=>e.table.name==='CombatTraitTable').table;
const operations=rows.filter(row=>!traits.rows.some(existing=>existing.id===row.id&&JSON.stringify(existing)===JSON.stringify(row)))
 .map(row=>({op:'upsert',table:'CombatTraitTable',row}));
if(operations.length){const patch={revision:state.revision,operations};
 fs.writeFileSync(path.join(root,'Tools/People/growth-content.patch.json'),JSON.stringify(patch,null,2)+'\n');
 const checked=review(root,patch);console.log(JSON.stringify({valid:checked.valid,traits:operations.length}));
 console.log(JSON.stringify(save(root,patch)));
}
const current=readWorkspace(root);const result=exportNarrative(root,current.revision);
console.log(JSON.stringify({exported:true,result}));

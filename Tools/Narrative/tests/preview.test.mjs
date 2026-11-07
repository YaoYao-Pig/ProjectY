import test from 'node:test';
import assert from 'node:assert/strict';
import {createPreviewModel} from '../public/preview-model.mjs';
import {createNarrativeServer} from '../server.mjs';

function fixture(edit=()=>{}) {
  const data={
    MissionTable:[{id:1,name:'驿路',startConditionId:1,completeConditionId:4,actionIds:[1]}],
    QuestTable:[{id:11,missionId:1,name:'证言'}],
    DialogueTable:[{id:10,name:'询问',npcId:3,entryNodeId:100}],
    DialogueNodeTable:[{id:100,dialogueId:10,text:'前文',choiceIds:[2,1]},{id:101,dialogueId:10,text:'后文',choiceIds:[3]},{id:200,dialogueId:20,text:'别的对话',choiceIds:[]}],
    DialogueChoiceTable:[{id:1,text:'继续',nextNodeId:101,conditionId:1,actionIds:[1]},{id:2,text:'离开',nextNodeId:0,conditionId:2,actionIds:[]},{id:3,text:'返回',nextNodeId:100,conditionId:1,actionIds:[]}],
    DialogueInterjectionTable:[{id:1,nodeId:100,order:2,mode:'optional',nextNodeId:0},{id:2,nodeId:100,order:1,mode:'optional',nextNodeId:101},{id:3,nodeId:100,order:1,mode:'auto',nextNodeId:0}],
    ConditionTable:[{id:1,kind:'always',conditionIds:[],reason:'无条件'},{id:2,kind:'flag',conditionIds:[],key:'evidence',value:1,reason:'缺少证言'},{id:3,kind:'not',conditionIds:[2],reason:'不可有证言'},{id:4,kind:'any',conditionIds:[2,3],reason:'择一'}],
    NarrativeActionTable:[{id:1,kind:'set_flag',key:'evidence',value:1},{id:2,kind:'grant_item',targetId:9,value:2},{id:3,kind:'grant_experience',value:20}],
    NpcTable:[{id:3,name:'书记'}]
  };
  edit(data);
  return createPreviewModel(Object.entries(data).map(([name,rows])=>({name,rows})),{EquipmentItemTable:[{id:9,name:'信件'}]});
}
test('choice and quest selection resolve their narrative context, preserving authored option order',()=>{
  const m=fixture();assert.equal(m.focus('QuestTable:11').mission.name,'驿路');
  assert.equal(m.focus('DialogueChoiceTable:1').node.text,'前文');
  assert.deepEqual(m.focus('DialogueNodeTable:100').node.choiceIds,[2,1]);
  assert.equal(m.focus('DialogueInterjectionTable:2').node.id,100);
  assert.equal(m.focus('MissionTable:999').kind,'missing');
});
test('conditions retain OR/NOT nesting, flag equality and missing/cyclic draft diagnostics',()=>{
  const m=fixture(),tree=m.condition(4);
  assert.equal(tree.kind,'any');assert.equal(tree.children[1].kind,'not');assert.match(tree.children[0].text,/evidence ＝ 1/);
  assert.match(fixture(d=>d.ConditionTable[2].conditionIds=[4]).condition(4).children[1].children[0].error,/循环/);
  assert.match(m.condition(999).error,/不存在/);
  assert.equal(tree.children[0].reason,'缺少证言');
});
test('incoming context includes ordinary and companion branches in configured order',()=>{
  const m=fixture();assert.deepEqual(m.incoming(101).map(e=>[e.table,e.node.id]),[['DialogueChoiceTable',100],['DialogueInterjectionTable',100]]);
  assert.deepEqual(m.interjections(100).map(r=>r.id),[2,3,1]);
});
test('zero target ends a choice but stays on the current node for an optional interjection',()=>{
  const m=fixture(),choice=m.reconcile(100,[{table:'DialogueChoiceTable',id:2}]);assert.equal(choice.ended,true);
  const companion=m.reconcile(100,[{table:'DialogueInterjectionTable',id:1},{table:'DialogueInterjectionTable',id:1}]);
  assert.equal(companion.ended,false);assert.equal(companion.node.id,100);assert.equal(companion.steps.length,1);
  assert.equal(m.reconcile(100,[{table:'DialogueInterjectionTable',id:3}]).steps.length,0);
});
test('paths support loops and reconcile deleted, changed, unowned and cross-dialogue draft edges',()=>{
  const path=[{table:'DialogueChoiceTable',id:1},{table:'DialogueChoiceTable',id:3},{table:'DialogueChoiceTable',id:2}];
  assert.equal(fixture().reconcile(100,path).ended,true);
  const changed=fixture(d=>d.DialogueChoiceTable[0].nextNodeId=0).reconcile(100,path);assert.equal(changed.steps.length,1);assert.equal(changed.ended,true);
  for(const edit of [d=>d.DialogueChoiceTable.splice(0,1),d=>d.DialogueNodeTable[0].choiceIds=[2],d=>d.DialogueChoiceTable[0].nextNodeId=200,d=>d.DialogueNodeTable.splice(1,1)])assert.equal(fixture(edit).reconcile(100,path).steps.length,0);
});
test('result descriptions resolve source text without executing or mutating actions',()=>{
  const m=fixture(),before=structuredClone(m.rows('NarrativeActionTable'));
  assert.match(m.action(1).text,/evidence ＝ 1/);assert.match(m.action(2).text,/信件 × 2/);assert.match(m.action(3).text,/每位现有队员经验/);
  assert.equal(m.action(99).error,true);assert.deepEqual(m.rows('NarrativeActionTable'),before);
});
test('mission dialogue links exclude unrelated users of universal conditions',()=>{
  const m=fixture(),graph={edges:[
    {from:'MissionTable:1',to:'ConditionTable:1'},
    {from:'DialogueTable:99',to:'ConditionTable:1'},
    {from:'MissionTable:1',to:'ConditionTable:4'},
    {from:'ConditionTable:4',to:'ConditionTable:2'},
    {from:'DialogueChoiceTable:1',to:'ConditionTable:2'},
    {from:'DialogueNodeTable:100',to:'DialogueChoiceTable:1'},
    {from:'DialogueTable:10',to:'DialogueNodeTable:100'}
  ]};
  assert.deepEqual(m.relatedDialogues(m.get('MissionTable',1),m.rows('QuestTable'),graph).map(d=>d.id),[10]);
  assert.deepEqual(m.relatedDialogues(m.get('MissionTable',1),[],{edges:graph.edges.slice(0,2)}),[]);
});
test('preview assets are served with module content types and existing CSP protections',async t=>{
  const server=createNarrativeServer();await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));t.after(()=>new Promise(resolve=>server.close(resolve)));
  const base=`http://127.0.0.1:${server.address().port}`;
  for(const file of ['/preview.js','/preview-model.mjs']){const response=await fetch(base+file);assert.equal(response.status,200);assert.match(response.headers.get('content-type'),/text\/javascript/);assert.match(response.headers.get('content-security-policy'),/script-src 'self'/);assert.match(await response.text(),/export function/);}
});

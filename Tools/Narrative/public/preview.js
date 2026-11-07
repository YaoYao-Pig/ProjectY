import {createPreviewModel} from './preview-model.mjs';

const el=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
const button=(text,click,cls='text-button')=>{const node=el('button',cls,text);node.onclick=click;return node;};
const categories={basic:'基础任务',main:'主线任务',side:'支线任务',recruit:'招募任务'};

export function createPreview(root,kindLabel,onSelect) {
  let model,graph,selected,anchor,origin,steps=[],lastSelection,contextOrigin;
  const expanded=new Map();
  const link=(table,id,text)=>button(text||model.label(table,id),()=>onSelect(`${table}:${id}`));
  const note=text=>el('p','note',text);
  function disclosure(title,key,open=false) {
    const node=el('details','disclosure');node.open=expanded.has(key)?expanded.get(key):open;
    node.append(el('summary','',title));node.ontoggle=()=>expanded.set(key,node.open);return node;
  }
  function condition(id,title='条件',open=false,key=title+id) {
    const data=model.condition(id),box=disclosure(`${title} · ${data.text}`,key,open);
    const draw=c=>{
      const node=el('div','condition-branch'+(c.error?' invalid':''));
      node.append(link('ConditionTable',c.id,`#${c.id} · ${c.text}`));
      if(c.reason)node.append(el('small','condition-reason',`未满足提示：${c.reason}`));
      for(const child of c.children)node.append(draw(child));
      return node;
    };
    box.append(draw(data));return box;
  }
  function actions(ids,title='执行结果') {
    const box=el('div','action-list');box.append(el('div','section-label',title));
    if(!ids.length)box.append(note('无配置动作'));
    for(const id of ids) {
      const a=model.action(id),line=el('div','action-row'+(a.error?' invalid':''));
      line.append(el('span','action-symbol',a.kind==='set_flag'?'◆':'↗'),link('NarrativeActionTable',id,a.text));box.append(line);
      if(a.kind==='claim_mission') {
        const mission=model.get('MissionTable',a.row.targetId);
        if(mission) {
          const nested=disclosure('任务结算动作',`claim-${id}`);
          for(const reward of mission.actionIds)nested.append(link('NarrativeActionTable',reward,model.action(reward).text));
          box.append(nested);
        }
      }
    }
    return box;
  }
  function missionView(context) {
    kindLabel.textContent='任务手记';
    const mission=context.mission;
    if(!mission){root.append(note('所属任务不存在或已在草稿中删除。'));return;}
    const quests=model.rows('QuestTable').filter(q=>q.missionId===mission.id);
    const cover=el('section','mission-cover');
    cover.append(el('div','eyebrow',`${categories[mission.category]||mission.category} / #${mission.id}`),el('h3','story-title',mission.name),el('p','story-description',mission.description));
    const lifecycle=el('div','lifecycle');
    for(const text of ['未接取','进行中','待结算','已完成'])lifecycle.append(el('span','',text));
    cover.append(lifecycle);root.append(cover);
    root.append(condition(mission.startConditionId,mission.autoAccept?'自动接取条件':'接取条件',false,`mission-start-${mission.id}`));
    const section=el('section','quest-section');
    section.append(el('div','section-heading',`阶段与前后文 · ${quests.length}`),note('按 ID 排列；激活顺序由条件决定，可并行或汇合。'));
    if(!quests.length)section.append(note('这个任务尚未配置阶段。'));
    for(const quest of quests) {
      const card=el('article','quest-card'+(context.quest?.id===quest.id?' current':''));
      const top=el('div','card-heading');top.append(el('span','badge',context.quest?.id===quest.id?'正在编辑':`阶段 #${quest.id}`),link('QuestTable',quest.id,'编辑 ↗'));
      card.append(top,el('h4','',quest.name),el('p','story-description',quest.description));
      const details=disclosure('激活 → 达成 → 结果',`quest-${quest.id}`,context.quest?.id===quest.id);
      details.append(note('仅在所属任务进行中推进'),condition(quest.startConditionId,'激活条件',true,`quest-start-${quest.id}`),condition(quest.completeConditionId,'达成条件',true,`quest-end-${quest.id}`),actions(quest.actionIds,quest.autoComplete?'达成后自动结算':'达成后等待结算'));
      card.append(details);section.append(card);
    }
    root.append(section);
    const ending=el('section','result-card');
    ending.append(el('div','section-heading','任务结局与报酬'),condition(mission.completeConditionId,'任务达成条件',true,`mission-end-${mission.id}`),actions(mission.actionIds,mission.autoComplete?'就绪后自动发放':'就绪后手动领取'));
    root.append(ending);
    const dialogues=model.relatedDialogues(mission,quests,graph),related=disclosure(`关联对白 · ${dialogues.length}`,`mission-dialogues-${mission.id}`,true);
    if(!dialogues.length)related.append(note('未找到通过条件或动作关联的对白。'));
    for(const d of dialogues)related.append(link('DialogueTable',d.id,`${model.label('NpcTable',d.npcId)} · ${d.name} ↗`));
    root.append(related);
  }
  function line(node,history=false) {
    const dialogue=model.get('DialogueTable',node.dialogueId);
    const speaker=node.speaker==='npc'?(dialogue?model.label('NpcTable',dialogue.npcId):'缺失对话对象'):node.speaker==='player'?'你':'旁白';
    const card=el('article',`dialogue-line ${node.speaker}${history?' history':''}`),heading=el('div','card-heading');
    heading.append(el('strong','speaker',speaker),link('DialogueNodeTable',node.id,`#${node.id} ↗`));
    card.append(heading,el('p','dialogue-text',node.text));return card;
  }
  function jump(nodeId) {origin=nodeId;steps=[];draw();root.scrollTop=0;}
  function follow(table,row) {
    if(steps.length>=80)return;
    steps.push({table,id:row.id});draw();root.querySelector('[data-current]')?.scrollIntoView({block:'nearest'});
  }
  function branch(row,table,node,used) {
    const isChoice=table==='DialogueChoiceTable',current=selected===`${table}:${row.id}`;
    const card=el('article',`choice-card${isChoice?'':' companion'}${current?' current':''}`);
    const head=el('div','card-heading');
    head.append(el('span','badge',isChoice?'你的选择':row.mode==='auto'?'自动插话 · 所有符合队员':'邀请队员发言'),link(table,row.id,'编辑 ↗'));
    card.append(head);
    if(!isChoice)card.append(el('strong','speaker',row.cue));
    card.append(el('p','choice-text',row.text),condition(row.conditionId,'可用条件',current,`branch-${table}-${row.id}`));
    if(isChoice) {
      card.append(note(row.hideWhenLocked?'条件不满足时隐藏':'条件不满足时显示原因并禁用'));
      if(row.actionIds.length)card.append(actions(row.actionIds,'选择后'));
    } else card.append(note('同一队员满足整组条件；每条插话在一次会话中消费一次。'));
    const next=row.nextNodeId?model.get('DialogueNodeTable',row.nextNodeId):null;
    const invalid=row.nextNodeId&&(!next||next.dialogueId!==node.dialogueId)||!isChoice&&row.mode==='auto'&&row.nextNodeId;
    if(invalid)card.append(el('p','invalid','无效跳转：目标缺失、跨对话或自动插话配置了跳转。'));
    else if(next) {
      const target=el('div','next-context');target.append(link('DialogueNodeTable',next.id,`→ 后文 #${next.id}`),el('p','',next.text));card.append(target);
    } else card.append(el('div','next-context',isChoice?(row.worldAction==='attack'?'→ 结束对话，进入战斗':'→ 结束对话'):'↳ 留在当前节点'));
    if(isChoice||row.mode==='optional') {
      const visited=used.has(row.id)&&!isChoice;
      const b=button(visited?'已在这条预览路径中发言':next?'沿此分支预览 →':isChoice?'预览此结局 →':'预览这次发言 →',()=>follow(table,row),'branch-button');
      b.disabled=Boolean(invalid||visited||steps.length>=80);card.append(b);
    }
    return card;
  }
  function dialogueView(context) {
    kindLabel.textContent='对白与分支';
    if(!context.node){root.append(el('p','invalid','对话入口节点不存在或已删除。'));return;}
    if(contextOrigin!==context.node.id){origin=context.node.id;contextOrigin=origin;steps=[];}
    const session=model.reconcile(origin,steps);steps=session.steps;
    const node=session.node;
    if(!node){root.append(el('p','invalid','预览节点不存在或已删除。'),button('返回当前编辑节点',()=>jump(context.node.id)));return;}
    const dialogue=model.get('DialogueTable',node.dialogueId);
    const heading=el('div','dialogue-context');
    heading.append(el('div','eyebrow',`DIALOGUE / #${node.dialogueId}`),dialogue?link('DialogueTable',dialogue.id,dialogue.name):note('所属对话缺失'));
    if(dialogue)heading.append(condition(dialogue.conditionId,'对话入口条件',false,`entry-${dialogue.id}`));
    root.append(heading);
    const toolbar=el('div','preview-toolbar');
    const back=button('← 退一步',()=>{steps.pop();draw();});back.disabled=!steps.length;
    toolbar.append(back,button('回到编辑节点',()=>jump(context.node.id)));
    if(dialogue)toolbar.append(button('从对话开头',()=>jump(dialogue.entryNodeId)));
    root.append(toolbar);
    if(context.owners.length>1) {
      const owners=disclosure(`此选项被 ${context.owners.length} 个节点使用`,'owners-'+selected);
      for(const n of context.owners)owners.append(button(`#${n.id} · ${n.text}`,()=>jump(n.id)));root.append(owners);
    }
    const incoming=model.incoming(node.id),before=disclosure(`前文来源 · ${incoming.length}${dialogue?.entryNodeId===node.id?' · 对话入口':''}`,`incoming-${node.id}`);
    if(!incoming.length)before.append(note(dialogue?.entryNodeId===node.id?'这是对话的起始节点。':'没有选项或插话跳转到此节点。'));
    for(const edge of incoming) {
      const item=el('div','incoming-card');
      if(edge.node)item.append(button(`← #${edge.node.id} · ${edge.node.text}`,()=>jump(edge.node.id)));
      else item.append(el('p','invalid','来源节点已删除'));
      item.append(link(edge.table,edge.row.id,`经由：${edge.row.text}`),condition(edge.row.conditionId,'进入条件',false,`incoming-edge-${edge.table}-${edge.row.id}`));
      if(edge.table==='DialogueChoiceTable'&&edge.row.actionIds.length)item.append(actions(edge.row.actionIds,'进入前执行'));before.append(item);
    }
    root.append(before);
    if(steps.length) {
      const history=disclosure(`已读上下文 · ${steps.length} 次选择`,`history-${anchor}`,true);
      for(const step of steps) {
        history.append(line(model.get('DialogueNodeTable',step.from),true));
        const choice=model.get(step.table,step.id),card=el('div','history-choice');
        card.append(el('span','speaker',step.table==='DialogueChoiceTable'?'你选择了':choice.cue),el('p','',choice.text));
        if(step.table==='DialogueChoiceTable'&&choice.actionIds.length)card.append(actions(choice.actionIds,'此步配置结果'));
        history.append(card);
      }
      root.append(history);
    }
    if(session.ended) {
      const ending=el('section','ending-card');ending.dataset.current='true';
      const last=model.get(steps.at(-1).table,steps.at(-1).id);
      ending.append(el('div','eyebrow','END OF THIS BRANCH'),el('h3','',last.worldAction==='attack'?'会话结束 · 开始战斗':'会话结束'),note('本次仅浏览配置，条件未求值，结果未执行。'),button('重新从编辑节点阅读',()=>jump(context.node.id),'branch-button'));root.append(ending);return;
    }
    const current=line(node);current.dataset.current='true';current.append(el('small','shot-label',`当前节点 · ${{pair:'双人构图',npc:'NPC 特写',player:'玩家特写'}[node.shot]||node.shot}`));root.append(current);
    const inserts=model.interjections(node.id);
    for(const row of inserts)root.append(branch(row,'DialogueInterjectionTable',node,session.used));
    if(node.choiceIds.length)root.append(el('div','section-heading',`接下来，你会怎么说？ · ${node.choiceIds.length}`));
    for(const id of node.choiceIds) {
      const row=model.get('DialogueChoiceTable',id);
      if(row)root.append(branch(row,'DialogueChoiceTable',node,session.used));
      else root.append(el('p','invalid',`选项 #${id} 不存在或已删除`));
    }
    if(!node.choiceIds.length)root.append(note('没有普通选项；可结束对话。主动插话仍按配置提供。'));
    if(steps.length>=80)root.append(note('已预览 80 步，请退一步或回到开头继续查看。'));
  }
  function entityView(context) {
    kindLabel.textContent='条件与关联';
    if(context.name==='ConditionTable')root.append(condition(context.row.id,'当前条件',true,'entity-condition'));
    else if(context.name==='NarrativeActionTable')root.append(actions([context.row.id],'当前动作'));
    else root.append(el('h3','story-title',model.label(context.name,context.row.id)));
    const edges=graph.edges.filter(e=>e.to===selected||e.from===selected);
    root.append(el('div','section-heading','关联内容'));
    if(!edges.length)root.append(note('尚无引用。可在属性中配置与任务或对白的关联。'));
    const unique=new Set();
    for(const e of edges) {
      const key=e.from===selected?e.to:e.from;if(unique.has(key))continue;unique.add(key);
      const [name,id]=key.split(':');if(!model.get(name,Number(id)))continue;
      root.append(link(name,Number(id),`${e.from===selected?'引用 →':'来自 ←'} ${model.label(name,Number(id))}`));
    }
  }
  function draw() {
    const scroll=root.scrollTop;root.replaceChildren();
    const context=model.focus(anchor);
    if(selected!==anchor) {
      const [name,id]=selected.split(':'),editing=el('div','context-editing');
      editing.append(note('正在编辑关联配置 · 下方保留故事上下文'),link(anchor.split(':')[0],Number(anchor.split(':')[1]),'返回故事编辑 ↗'));
      if(name==='ConditionTable')editing.append(condition(Number(id),'当前条件',true,'editing-condition-'+id));
      if(name==='NarrativeActionTable')editing.append(actions([Number(id)],'当前动作'));
      root.append(editing);
    }
    if(context.kind==='mission')missionView(context);
    else if(context.kind==='dialogue')dialogueView(context);
    else if(context.kind==='entity')entityView(context);
    else {kindLabel.textContent='草稿';root.append(note('条目已删除。选择其他内容继续预览。'));}
    root.scrollTop=scroll;
  }
  return {
    render(tables,references,draftGraph,key) {
      model=createPreviewModel(tables,references);graph=draftGraph;selected=key;
      const selectionChanged=key!==lastSelection;
      if(selectionChanged) {
        const auxiliary=/^(ConditionTable|NarrativeActionTable):/.test(key);
        if(!auxiliary||!anchor||!['mission','dialogue'].includes(model.focus(anchor).kind)) {anchor=key;origin=null;contextOrigin=null;steps=[];}
        lastSelection=key;root.scrollTop=0;
      }
      draw();
      if(selectionChanged)root.querySelector('.current')?.scrollIntoView({block:'nearest'});
    },
    reset(){lastSelection=null;anchor=null;contextOrigin=null;steps=[];expanded.clear();}
  };
}

-- Real widget controllers, isolated from world generation and player saves.
local context={log=function(message) error(message,0) end}
local dialogue=require('UI.Widget.DialogueEntry')(context,TypographyDialogue)
local choice=require('UI.Widget.StoryChoice')(context,TypographyChoice)
dialogue:Bind();choice:Bind()
local speaker=dialogue.view.Title.font
local body=dialogue.view.Body.font
local choiceFont=choice.view.Title.font
local row={title=TypographyTitle,body=TypographyBody,kind='npc',available=true}
dialogue:SetData(row,TypographyUtilityFont,nil)
assert(dialogue.view.Title.font==speaker and dialogue.view.Body.font==body)
dialogue:SetData(row,TypographyUtilityFont,function()end)
assert(dialogue.view.Title.font==body,'Dialogue options must use the narrative font')
dialogue:SetData(row,TypographyUtilityFont,nil)
assert(dialogue.view.Title.font==speaker,'Recycled dialogue must restore the speaker font')
choice:SetData(row,{Font=TypographyUtilityFont},function()end)
assert(choice.view.Title.font==choiceFont,'GrowthRow must not replace the story choice font')
assert(choice.view.Body.font==TypographyUtilityFont,'Choice costs and requirements retain utility type')
choice:SetData(nil)
choice:SetData(row,{Font=TypographyUtilityFont},function()end)
assert(choice.view.Title.font==choiceFont,'Recycled choice must retain the narrative font')
dialogue:Dispose();choice:Dispose()
return 'PASS real DialogueEntry and StoryChoice Bind/SetData, option/speaker transitions and pooled reuse'

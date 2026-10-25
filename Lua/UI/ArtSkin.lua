-- Explicit prefab artwork bindings; presentation only, without input or gameplay state.
local Skin={}
local spriteKeys={'panel_light','panel_dark','header_strip','inset_light','button_light','button_accent','button_hover','button_pressed',
    'tab_light','tab_accent','slot_frame','selected_frame','node_round','rule_horizontal',
    'node_learned','node_available','node_locked'}
local colorKeys={'ink','muted','accent_ink','on_accent','disabled_ink','on_dark'}
local nodeSprites={owned='node_learned',eligible='node_available',locked='node_locked',source='node_locked'}
local ImageType=CS.UnityEngine.UI.Image.Type
local Transition=CS.UnityEngine.UI.Selectable.Transition
local Color=CS.UnityEngine.Color
local white=Color.white
function Skin.Read(reference)
    local skin={sprites={},colors={}}
    for _,key in ipairs(spriteKeys) do skin.sprites[key]=assert(reference:GetImage(key).sprite,'Missing UI skin Sprite: '..key) end
    for _,key in ipairs(colorKeys) do skin.colors[key]=reference:GetImage(key).color end
    return skin
end
function Skin.ReadRewards(reference)
    local result={}
    for _,key in ipairs({'coins','experience','item','recruit','relation','reputation','card_background','card_accent'}) do
        result[key]=assert(reference:GetImage(key).sprite,'Missing reward artwork: '..key)
    end
    return result
end
local function inset(rect,left,top,right,bottom)
    rect.anchorMin=CS.UnityEngine.Vector2.zero;rect.anchorMax=CS.UnityEngine.Vector2.one
    rect.offsetMin=CS.UnityEngine.Vector2(left,bottom);rect.offsetMax=CS.UnityEngine.Vector2(-right,-top)
end
function Skin.FitTab(view)
    -- Selection is already expressed by the sprite; keep each label inside its measured layout cell.
    view.Root.localScale=CS.UnityEngine.Vector3.one
    view.Sizing.minWidth=92;view.Sizing.preferredWidth=math.max(92,view.Label.preferredWidth+40)
    view.Sizing.minHeight=74;view.Sizing.preferredHeight=74
    view.Sizing.flexibleWidth=0;view.Sizing.flexibleHeight=0
    inset(view.Label.rectTransform,20,16,20,16)
    local line=view.Selected.rectTransform
    line.anchorMin=CS.UnityEngine.Vector2(0,0);line.anchorMax=CS.UnityEngine.Vector2(1,0)
    line.anchoredPosition=CS.UnityEngine.Vector2(0,8);line.sizeDelta=CS.UnityEngine.Vector2(-40,2)
    line.pivot=CS.UnityEngine.Vector2(.5,0)
end
function Skin.FitEntry(view,compact)
    view.Layout.padding=compact and CS.UnityEngine.RectOffset(0,0,12,12) or CS.UnityEngine.RectOffset(38,38,32,36);view.Layout.spacing=8
    view.Layout.childControlWidth=true;view.Layout.childControlHeight=true
    view.Layout.childForceExpandWidth=true;view.Layout.childForceExpandHeight=false
    view.Sizing.minHeight=compact and 0 or 96;view.Sizing.preferredHeight=-1;view.Sizing.flexibleHeight=0
    view.Title.enableWordWrapping=true;view.Body.enableWordWrapping=true
    if compact then view.Button.transition=Transition.None;view.Background.color=Color.clear end
end
function Skin.ApplyReward(skin,rewards,view,row,width)
    view.Background.sprite=rewards.card_background;view.Background.type=ImageType.Sliced
    view.Background.pixelsPerUnitMultiplier=.4;view.Background.color=white
    view.Badge.color=Color.clear
    if row.kind~='item' or not view.Icon.enabled then
        view.Icon.sprite=assert(rewards[row.kind],'Unknown reward artwork: '..row.kind)
        view.Icon.enabled=true;view.Icon.preserveAspect=true;view.Icon.color=white
        view.Glyph.gameObject:SetActive(false)
    end
    local tones={coins=Color(.55,.34,.10),experience=Color(.16,.39,.53),item=Color(.27,.39,.28),
        recruit=Color(.40,.29,.55),relation=Color(.61,.26,.22),reputation=Color(.19,.43,.34)}
    view.Name.color=skin.colors.ink;view.Note.color=skin.colors.muted;view.Amount.color=assert(tones[row.kind])
    view.Name.fontSize=14;view.Amount.fontSize=22;view.Note.fontSize=11
    local y=22
    for _,text in ipairs({view.Name,view.Amount,view.Note}) do
        text.enableWordWrapping=true;text.overflowMode=CS.TMPro.TextOverflowModes.Overflow
        text.alignment=CS.TMPro.TextAlignmentOptions.TopLeft
        local height=text.text~='' and math.ceil(text:GetPreferredValues(text.text,width-108,math.huge).y)+2 or 0
        local rect=text.rectTransform
        rect.anchorMin=CS.UnityEngine.Vector2(0,1);rect.anchorMax=rect.anchorMin;rect.pivot=rect.anchorMin
        rect.anchoredPosition=CS.UnityEngine.Vector2(86,-y);rect.sizeDelta=CS.UnityEngine.Vector2(width-108,height)
        if height>0 then y=y+height+4 end
    end
    view.Accent.sprite=rewards.card_accent;view.Accent.type=ImageType.Sliced;view.Accent.color=white
    local accent=view.Accent.rectTransform
    accent.anchorMin=CS.UnityEngine.Vector2(0,0);accent.anchorMax=CS.UnityEngine.Vector2(0,1)
    accent.offsetMin=CS.UnityEngine.Vector2(8,20);accent.offsetMax=CS.UnityEngine.Vector2(11,-20)
    return math.max(144,y+36)
end
function Skin.ApplyImage(skin,image,key)
    image.sprite=assert(skin.sprites[key],'Unknown UI skin Sprite: '..key)
    image.type=ImageType.Sliced;image.pixelsPerUnitMultiplier=.4;image.color=white
end
function Skin.ApplySkillNode(skin,view,state)
    local key=assert(nodeSprites[state],'Unknown UI skin node state: '..tostring(state))
    view.Ring.sprite=assert(skin.sprites[key],'Missing UI skin Sprite: '..key)
    view.Ring.type=ImageType.Simple;view.Ring.color=white
end
function Skin.ApplyButton(skin,button,label,options)
    options=options or {}
    local accent=options.selected or options.emphasis
    local normal=options.normal or (options.dark and 'panel_dark' or 'button_light')
    local active=options.active or 'button_accent'
    local disabled=options.disabled or (options.dark and normal or 'button_light')
    local image=assert(button.image,'UI skin button requires an Image target')
    -- Clear the old ColorTint/override before reapplying the current Selectable state.
    button.transition=Transition.None;image.overrideSprite=nil
    image:CrossFadeColor(white,0,true,true)
    Skin.ApplyImage(skin,image,accent and active or normal)
    if not accent and not options.dark then
        local colors=button.colors
        colors.normalColor=white;colors.highlightedColor=Color(1.04,1.04,1.04,1)
        colors.pressedColor=Color(.88,.88,.88,1);colors.selectedColor=Color(.98,.98,.98,1)
        colors.disabledColor=Color(.94,.94,.94,.65);colors.colorMultiplier=1;colors.fadeDuration=.08
        button.colors=colors;button.transition=Transition.ColorTint
    else
        local states=button.spriteState
        states.highlightedSprite=skin.sprites[accent and 'button_hover' or normal]
        states.pressedSprite=skin.sprites[accent and 'button_pressed' or normal]
        states.selectedSprite=skin.sprites[accent and active or normal]
        states.disabledSprite=skin.sprites[disabled]
        button.spriteState=states;button.transition=Transition.SpriteSwap
    end
    if label then
        label.color=options.dark and skin.colors.on_dark or (not button.interactable and skin.colors.disabled_ink
            or accent and skin.colors.on_accent or skin.colors.ink)
    end
end
return Skin

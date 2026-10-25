-- 技能图标复用已保存的 Sprite；仅未配置图片时显示目录符号。
local Icon={}
function Icon.Set(image,style,skill,icons,glyphCode,fallbackTint)
    local icon=icons:Get(skill.iconId)
    image.preserveAspect=true
    if icon.spritePath~='' then
        style:SetArt(image,icon.spritePath);style:Tint(image,'FFFFFF')
        return true
    end
    style:SetGlyph(image,glyphCode);image.enabled=true;style:Tint(image,fallbackTint)
    return false
end
return Icon

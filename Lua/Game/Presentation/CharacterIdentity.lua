local L=require('Language')
local Identity={}

-- A disposable presentation value; names and professions remain configuration text.
function Identity.Read(stats,actor,displayName)
    local template=stats:Template(actor)
    local professionId=actor.Growth.CurrentProfessionId
    if professionId==0 then professionId=actor.InitialProfessionId end
    local name=displayName or (stats.inspection and stats.inspection.targets:Name(actor)) or template.name
    local profession=professionId>0 and stats.growth.professions.professions:Get(professionId).name or nil
    -- Legacy party templates include their starting profession after the separator.
    if profession and name==template.name then name=name:match('^(.-)%s*·') or name end
    local title=stats.titles:Equipped(actor)
    return {name=name,profession=profession,title=title and title.name or nil}
end

function Identity.Format(identity,nameSize,detailSize,titleColor,marker)
    local lines={}
    if identity.title then
        lines[#lines+1]=string.format('<size=%d><color=#%s>%s</color></size>',detailSize,titleColor,
            string.format(L.CharacterIdentityTitle,identity.title))
    end
    lines[#lines+1]=string.format('<size=%d>%s%s</size>',nameSize,marker or '',identity.name)
    if identity.profession then lines[#lines+1]=string.format('<size=%d>%s</size>',detailSize,identity.profession) end
    return table.concat(lines,'\n')
end

return Identity

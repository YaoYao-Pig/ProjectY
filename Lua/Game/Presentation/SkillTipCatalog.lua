-- Shared tooltip content only. Effective attributes and discovery state belong to their gameplay owners.
local Color=require('Config.Color')
local Catalog={};Catalog.__index=Catalog
local linkColor='#8BCFE7'

function Catalog.Escape(text)
    assert(type(text)=='string','Tooltip plain text must be a string')
    return (text:gsub('<','＜'):gsub('>','＞'))
end

function Catalog.New(config)
    local self=setmetatable({tags=config:GetTable('SkillTagTable'),texts=config:GetTable('SkillTipTextTable'),
        descriptions=config:GetTable('SkillDescriptionTable'),synergies=config:GetTable('SkillSynergyTable')},Catalog)
    for _,tag in ipairs(self.tags:All())do
        Color.Normalize(tag.textColor);Color.Normalize(tag.backgroundColor)
    end
    for _,row in ipairs(self.texts:All())do self:Rich(row.body) end
    for _,skill in ipairs(config:GetTable('CombatSkillTable'):All())do self:Description(skill.id) end
    for _,row in ipairs(self.synergies:All())do
        assert(math.tointeger(row.id) and row.id>0 and row.id<=65535,'Skill synergy ID must fit the persistent bitset (1..65535)')
        assert(#row.runeIds>0,'Skill synergy needs at least one rune: '..row.id)
        local seen={};for _,id in ipairs(row.runeIds) do
            assert(not seen[id],'Duplicate rune in synergy '..row.id);seen[id]=true
        end
        self:Rich(row.body)
    end
    return self
end

function Catalog:Rich(text)
    assert(type(text)=='string','Tooltip rich text must be a string')
    local unmatched=text:gsub('<link="([^"]+)">(.-)</link>',function(target,label)
        assert(not label:find('<link',1,true),'Tooltip links cannot contain nested links')
        local id=target:match('^term:([%w_%-]+)$')
        assert(id,'Tooltip links must use term:<id>: '..target)
        self.texts:Get(id)
        return ''
    end)
    assert(not unmatched:find('<link',1,true) and not unmatched:find('</link>',1,true),'Malformed tooltip link')
    return (text:gsub('<link="([^"]+)">(.-)</link>',function(target,label)
        return '<link="'..target..'"><color='..linkColor..'><u>'..label..'</u></color></link>'
    end))
end

function Catalog:Description(skillId)
    local row=self.descriptions:Get(skillId);local tags={};local paragraphs={}
    assert(#row.tagIds>0,'Skill tooltip needs at least one category: '..skillId)
    for _,id in ipairs(row.tagIds)do
        local tag=self.tags:Get(id)
        tags[#tags+1]={name=tag.name,textColor=Color.Normalize(tag.textColor),backgroundColor=Color.Normalize(tag.backgroundColor)}
    end
    if row.body~='' then paragraphs[#paragraphs+1]=row.body end
    for _,id in ipairs(row.fragmentIds)do paragraphs[#paragraphs+1]=self.texts:Get(id).body end
    assert(#paragraphs>0,'Skill tooltip needs an effect description: '..skillId)
    return {tags=tags,body=self:Rich(table.concat(paragraphs,'\n'))}
end

function Catalog:Term(id)
    local row=self.texts:Get(id)
    return {title=row.name,body=self:Rich(row.body)}
end

function Catalog:Synergies()
    local rows={}
    for _,row in ipairs(self.synergies:All())do rows[#rows+1]=row end
    table.sort(rows,function(a,b)return a.id<b.id end)
    return rows
end

return Catalog

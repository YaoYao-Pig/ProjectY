local Chronicle = {}; Chronicle.__index = Chronicle
function Chronicle.New(config, data, stats)
    local self = setmetatable({data=data,stats=stats,templates={}}, Chronicle)
    for _, row in ipairs(config:GetTable('StoryLogTemplateTable'):All()) do
        assert(not self.templates[row.kind] and row.color:match('^%x%x%x%x%x%x$'), 'Invalid story log template')
        self.templates[row.kind] = row
    end
    return self
end
function Chronicle.Format(template, values)
    return (template:gsub('{([%w_]+)}', function(key) return assert(values[key], 'Unknown story token: '..key) end))
end
function Chronicle:Values(actor, location, title, detail)
    local names = {}
    for i = 0, self.data.PartyCount-1 do
        local other = self.data:GetPartyAt(i)
        if not actor or other.Id ~= actor.Id then names[#names+1] = self.stats:Template(other).name end
    end
    return {actor=actor and self.stats:Template(actor).name or '小队',location=location,title=title,detail=detail,
        companions=#names > 0 and table.concat(names,'、') or '一路的见闻'}
end
function Chronicle:Record(kind, actor, title, detail, location, shared, eventId, choiceId)
    local template = assert(self.templates[kind], 'Unknown log kind: '..kind)
    local values = self:Values(actor, location, title, detail)
    values.detail = Chronicle.Format(detail, values)
    self.data:Record(kind,title,Chronicle.Format(template.template,values),location,eventId or 0,choiceId or 0,actor and actor.Id or 0,shared == true)
end
function Chronicle:RecordPair(kind,actor,other,title,detail,location,delta)
    assert(actor and other and actor.Id~=other.Id,'A shared experience needs two different actors')
    local template=assert(self.templates[kind],'Unknown log kind: '..kind)
    local values=self:Values(actor,location,title,detail)
    values.other=self.stats:Template(other).name
    values.companions=values.other
    values.detail=Chronicle.Format(detail,values)
    self.data:RecordPair(kind,title,Chronicle.Format(template.template,values),location,0,0,actor.Id,other.Id,delta or 0)
end
function Chronicle:Rows(actorId)
    local rows = {}
    for i = self.data.JournalCount-1, 0, -1 do
        local entry = self.data:GetJournalAt(i)
        if not actorId or entry:Involves(actorId) then
            local template = assert(self.templates[entry.Kind])
            local minute=math.floor(entry.Minutes%1440)
            rows[#rows+1] = {sequence=entry.Sequence,title=entry.Title,body=entry.Body,location=entry.Location,label=template.label,color=template.color,
                date=string.format('第%d日 %02d:%02d',entry.Day,math.floor(minute/60),minute%60),subjectId=entry.SubjectId,objectId=entry.ObjectId,relationDelta=entry.RelationDelta}
        end
    end
    return rows
end
return Chronicle

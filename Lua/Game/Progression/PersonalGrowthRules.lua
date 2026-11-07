local L=require('Language')
local Rules={};Rules.__index=Rules
local counters={{field='requiredWins',record='BattleWins',key='PeopleGrowthWins'},
    {field='requiredRescues',record='Rescues',key='PeopleGrowthRescues'},
    {field='requiredLearnedSkills',record='LearnedSkills',key='PeopleGrowthLearning'}}
function Rules.New(config)
    local self=setmetatable({stages=config:GetTable('PersonalGrowthStageTable'),choices=config:GetTable('PersonalGrowthChoiceTable'),
        traits=config:GetTable('CombatTraitTable'),skills=config:GetTable('CombatSkillTable'),byProfile={},byStage={}},Rules)
    for _,row in ipairs(self.stages:All())do
        assert(row.profileId>=1 and row.profileId<=4 and (row.stage==1 or row.stage==2),'Invalid personal growth stage')
        assert(row.conditionMode=='all' or row.conditionMode=='any','Invalid personal growth condition mode')
        self.byProfile[row.profileId]=self.byProfile[row.profileId] or {}
        assert(not self.byProfile[row.profileId][row.stage],'Duplicate personal growth stage')
        self.byProfile[row.profileId][row.stage]=row;self.byStage[row.id]={}
        local required=0
        for _,counter in ipairs(counters)do
            assert(row[counter.field]>=0 and math.tointeger(row[counter.field]),'Invalid personal growth requirement')
            required=required+row[counter.field]
        end
        assert(required>0,'Personal growth must require real experiences')
    end
    local traits={}
    for _,row in ipairs(self.choices:All())do
        local stage=self.stages:Get(row.stageId)
        self.traits:Get(row.traitId)
        assert(not traits[row.traitId],'Personal growth traits must identify a unique choice')
        traits[row.traitId]=true
        assert(#row.skillIds<=1,'A personal growth choice grants at most one skill')
        for _,skillId in ipairs(row.skillIds)do assert(self.skills:Get(skillId).skillKind~='item','Personal growth cannot grant an item action')end
        assert((stage.stage==2)==row.replacePreviousTrait,'Only final growth replaces the first-stage trait')
        local choices=self.byStage[row.stageId];choices[#choices+1]=row
    end
    for profileId=1,4 do
        local stages=assert(self.byProfile[profileId],'Missing personal growth profile')
        for stage=1,2 do
            local row=assert(stages[stage],'Missing personal growth stage')
            local choices=self.byStage[row.id]
            assert(#choices==2,'Each personal growth stage needs exactly two choices')
            table.sort(choices,function(a,b)return a.id<b.id end)
        end
    end
    return self
end
function Rules:Current(record)
    assert(record.Stage>=0 and record.Stage<=2,'Invalid saved personal growth stage')
    local profile=assert(self.byProfile[record.ProfileId],'Missing saved personal growth profile')
    return profile[record.Stage+1]
end
function Rules:Eligible(record,stage)
    local any,all=false,true
    for _,counter in ipairs(counters)do
        local required=stage[counter.field]
        if required>0 then
            local met=record[counter.record]>=required
            any=any or met;all=all and met
        end
    end
    return stage.conditionMode=='any' and any or stage.conditionMode=='all' and all
end
function Rules:Progress(record,stage)
    local parts={}
    for _,counter in ipairs(counters)do
        local required=stage[counter.field]
        if required>0 then parts[#parts+1]=string.format(L[counter.key],record[counter.record],required)end
    end
    return string.format(stage.conditionMode=='any' and L.PeopleGrowthAny or L.PeopleGrowthAll,table.concat(parts,L.PeopleGrowthSeparator))
end
function Rules:KnowsSkill(actor,skillId,stats)
    if actor.Growth:HasSkill(skillId)then return true end
    for _,id in ipairs(stats:Template(actor).skillIds)do if id==skillId then return true end end
    return false
end
function Rules:Reward(actor,record,choice,stats)
    local trait=self.traits:Get(choice.traitId)
    local parts={string.format(L.PeopleGrowthTrait,trait.name,trait.description)}
    if choice.replacePreviousTrait then
        local previous=self.choices:Get(record.Branch1)
        parts[#parts+1]=string.format(L.PeopleGrowthReplaces,self.traits:Get(previous.traitId).name)
    end
    for _,skillId in ipairs(choice.skillIds)do
        local skill=self.skills:Get(skillId)
        parts[#parts+1]=string.format(self:KnowsSkill(actor,skillId,stats) and L.PeopleGrowthSkillKnown or L.PeopleGrowthSkill,skill.name,skill.description)
    end
    return table.concat(parts,'\n')
end
function Rules:ValidateRecord(record,stats)
    self:Current(record)
    local activeTrait
    for stage=1,2 do
        local id=stage==1 and record.Branch1 or record.Branch2
        if record.Stage>=stage then
            local choice=self.choices:Get(id)
            local definition=self.byProfile[record.ProfileId][stage]
            assert(choice.stageId==definition.id,'Saved growth choice belongs to another stage')
            assert(self:Eligible(record,definition),'Saved growth choice lacks its required experiences')
            activeTrait=choice.traitId
            if stage==2 then
                for _,skillId in ipairs(choice.skillIds)do
                    assert(self:KnowsSkill(record.Actor,skillId,stats),'Saved personal growth skill is missing')
                end
            end
        else assert(id==0,'Uncompleted personal growth contains a choice')end
    end
    for _,choice in ipairs(self.choices:All())do
        assert(record.Actor:HasTrait(choice.traitId)==(choice.traitId==activeTrait),
            'Saved personal growth trait does not match its selected stage')
    end
end
return Rules

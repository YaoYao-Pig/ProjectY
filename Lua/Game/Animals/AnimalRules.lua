-- 动物配置与即时查询。生命、归属、随机数及亲密度只保存在 CombatActorData。
local Hex=require('Game.Map.HexGrid')
local Rules={};Rules.__index=Rules
function Rules.New(config)
    local self=setmetatable({species=config:GetTable('AnimalSpeciesTable'),skills=config:GetTable('AnimalSkillTable'),
        rule=config:GetTable('AnimalRuleTable'):Get(1),byUnit={},bySkill={}},Rules)
    for _,row in ipairs(self.species:All()) do
        assert(not self.byUnit[row.unitId],'Duplicate animal unit template')
        assert(#row.footprintQ>0 and #row.footprintQ==#row.footprintR,'Animal footprint arrays differ')
        assert(#row.riderSeat==3 and row.initialBond<=row.maximumBond,'Invalid animal riding profile')
        local seen,origin={},false
        for i,q in ipairs(row.footprintQ) do
            local r=row.footprintR[i];local key=Hex.Key(q,r)
            assert(not seen[key],'Duplicate animal footprint cell');seen[key]=true
            if q==0 and r==0 then origin=true end
        end
        assert(origin,'Animal footprint must contain its anchor')
        local reached={[Hex.Key(0,0)]=true};local count=1;local changed=true
        while changed do
            changed=false
            for i,q in ipairs(row.footprintQ) do
                local r=row.footprintR[i];local key=Hex.Key(q,r)
                if not reached[key] then for d=1,6 do
                    local nq,nr=Hex.Neighbor(q,r,d)
                    if reached[Hex.Key(nq,nr)] then reached[key]=true;count=count+1;changed=true;break end
                end end
            end
        end
        assert(count==#row.footprintQ,'Animal footprint must be connected')
        self.byUnit[row.unitId]=row
    end
    for _,row in ipairs(self.skills:All()) do
        assert(not self.bySkill[row.skillId],'Duplicate cavalry skill')
        assert(row.minimumDistance<=row.maximumDistance,'Invalid cavalry distance')
        assert(row.minimumBond<=self.species:Get(row.speciesId).maximumBond,'Unreachable animal skill bond')
        self.bySkill[row.skillId]=row
    end
    assert(self.rule.minimumChance<=self.rule.maximumChance,'Invalid taming chance clamp')
    return self
end
function Rules:Species(actor)
    local mount=actor.MountedAnimal
    return self.byUnit[mount and mount.TemplateId or actor.TemplateId]
end
function Rules:Cells(actor,board,q,r)
    local species=self:Species(actor);q=q or actor.Q;r=r or actor.R
    if not species then return {board:Find(q,r)} end
    local cells={}
    for i,dq in ipairs(species.footprintQ) do
        local cell=board:Find(q+dq,r+species.footprintR[i]);if not cell then return nil end
        cells[#cells+1]=cell
    end
    return cells
end
function Rules:CanPlace(actor,board,q,r,occupied,allowed)
    local cells=self:Cells(actor,board,q,r);if not cells or #cells==0 then return false end
    for _,cell in ipairs(cells) do
        if cell.blocked or (occupied and occupied[Hex.Key(cell.q,cell.r)]) or (allowed and not allowed(cell)) then return false end
    end
    return true
end
function Rules:Occupy(actor,board,occupied)
    for _,cell in ipairs(assert(self:Cells(actor,board),'Animal footprint outside map')) do occupied[Hex.Key(cell.q,cell.r)]=actor end
end
function Rules:Distance(a,b,board)
    local distance=math.huge
    for _,x in ipairs(assert(self:Cells(a,board))) do for _,y in ipairs(assert(self:Cells(b,board))) do
        distance=math.min(distance,Hex.Distance(x.q,x.r,y.q,y.r))
    end end
    return distance
end
function Rules:MoveRange(actor,template)
    return actor.MountedAnimal and self.species:Get(actor.MountedAnimal.AnimalSpeciesId).moveRange or template.moveRange
end
function Rules:AddSkills(actor,ids)
    local mount=actor.MountedAnimal;if not mount then return ids end
    local owned={};for _,id in ipairs(ids) do owned[id]=true end
    for _,row in ipairs(self.skills:All()) do
        if row.speciesId==mount.AnimalSpeciesId and mount.AnimalBond>=row.minimumBond and not owned[row.skillId] then
            ids[#ids+1]=row.skillId;owned[row.skillId]=true
        end
    end
    return ids
end
function Rules:TameChance(source,target,stats)
    local species=assert(self.byUnit[target.TemplateId],'Taming needs an animal')
    local chance=self.rule.chance:Evaluate({affinity=stats:Get(source,'animalAffinity'),charisma=stats:Get(source,'charisma'),
        missingHealth=1-target.HP/target.MaxHP,hostile=target.Team==2 and 1 or 0,difficulty=species.tameDifficulty})
    assert(chance==chance and math.abs(chance)<math.huge,'Invalid taming chance')
    return math.max(self.rule.minimumChance,math.min(self.rule.maximumChance,chance))
end
function Rules:CanTame(source,target)
    if source.MountedAnimal then return false,'已经骑乘动物' end
    if source.HP<=0 or source.Team~=1 then return false,'请选择存活的队员' end
    if not target or target.HP<=0 or not self.byUnit[target.TemplateId] or target.AnimalOwnerId~=0 then return false,'请选择未驯服的动物' end
    if target.TameRetryTurns>0 then return false,'动物暂不接受驯服，还需 '..target.TameRetryTurns..' 回合' end
    return true
end
function Rules:Tame(source,target,stats)
    local chance=self:TameChance(source,target,stats)
    local species=self.byUnit[target.TemplateId]
    if target:RollAnimalPercent()>=math.floor(chance*100) then target:DelayTaming(species.tameRetryTurns);return false,chance end
    assert(species.rideable,'Non-rideable animal ownership is not configured in this release')
    source:TameAndRide(target,species.initialBond)
    return true,chance
end
function Rules:BattleBond(actor)
    local mount=actor.MountedAnimal
    if mount and mount.HP>0 then
        local species=self.species:Get(mount.AnimalSpeciesId)
        mount:AddAnimalBond(species.bondPerBattle,species.maximumBond)
    end
end
-- 技能只规划落点；命令校验成功后由战斗系统统一扣费、移动与结算。
function Rules:Landing(actor,target,board,skillId,occupied,allowed)
    local rule=assert(self.bySkill[skillId]);local distance=Hex.Distance(actor.Q,actor.R,target.q,target.r)
    if distance<rule.minimumDistance or distance>rule.maximumDistance then return nil,'目标不在骑兵技能距离内' end
    if rule.movement=='leap' then
        if not self:CanPlace(actor,board,target.q,target.r,occupied,allowed) then return nil,'跳跃落点不能容纳坐骑' end
        if board.area and not board.area:CanSee(board:Find(actor.Q,actor.R),target) then return nil,'高大障碍遮挡了跳跃路线' end
        return target,distance
    end
    if rule.movement=='charge' then
        for direction=1,6 do
            local dq,dr=Hex.Neighbor(0,0,direction)
            if actor.Q+dq*distance==target.q and actor.R+dr*distance==target.r then
                local landing
                for step=1,distance-1 do
                    local q,r=actor.Q+dq*step,actor.R+dr*step
                    if not self:CanPlace(actor,board,q,r,occupied,allowed) then return nil,'冲击直线被阻挡' end
                    landing=board:Find(q,r)
                end
                return landing,distance-1
            end
        end
        return nil,'冲击需要六边形直线上的目标'
    end
    local best,bestDistance
    for _,cell in ipairs(board:Neighbors(target)) do
        local jump=Hex.Distance(actor.Q,actor.R,cell.q,cell.r)
        if jump>0 and jump<=rule.maximumDistance-1 and self:CanPlace(actor,board,cell.q,cell.r,occupied,allowed)
            and (not bestDistance or jump<bestDistance) then best,bestDistance=cell,jump end
    end
    return best,best and bestDistance or '没有能容纳坐骑的飞扑落点'
end
return Rules

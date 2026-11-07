param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
# Uses an already compiled project DLL and isolated data only; no Editor, compilation or player saves.
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
$flags=[Reflection.BindingFlags]'Instance,Static,Public,NonPublic'
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Invoke-Hidden($Target,[string]$Name,[object[]]$Arguments=@()){
    $type=if($Target -is [Type]){$Target}else{$Target.GetType()}
    $instance=if($Target -is [Type]){$null}else{$Target}
    return $type.GetMethod($Name,$flags).Invoke($instance,$Arguments)
}
function New-Saved([string]$Name){return [Activator]::CreateInstance($assembly.GetType('ProjectY.Data.'+$Name),$true)}
function Saved-Array([string]$Name,[object[]]$Rows){
    $array=[Array]::CreateInstance($assembly.GetType('ProjectY.Data.'+$Name),$Rows.Count)
    for($i=0;$i -lt $Rows.Count;$i++){$array.SetValue($Rows[$i],$i)}
    return ,$array
}
function Assert-InvalidSave([scriptblock]$Action,[string]$Message){
    $rejected=$false
    try{& $Action | Out-Null}catch{
        $cause=$_.Exception
        while($null-ne $cause.InnerException){$cause=$cause.InnerException}
        if($cause -is [IO.InvalidDataException]){$rejected=$true}else{throw}
    }
    Assert-True $rejected $Message
}

# Supply this diagnostic through the existing text service, without loading Unity resources.
[ProjectY.Data.LocalizationService]::Shared.SetText('LuaTxt','ForgeSaveInvalid','Invalid equipment legacy fixture')
$adventure=[ProjectY.Data.AdventureData]::new()
$player=[ProjectY.Data.PlayerData]::new()
$player.AddCoins(100)
$bag=$adventure.Equipment
$camp=[ProjectY.Data.CampData]::For($adventure)
foreach($item in @(40,41,81,82,100)){$bag.Grid.Define($item,1,1)}
$bag.Grid.Configure(8,8)
[ProjectY.Data.EquipmentAffixData]::Define($bag,40,[int[]]@(3),[int[]]@(1))
[ProjectY.Data.EquipmentAffixData]::Define($bag,41,[int[]]@(4),[int[]]@(1))
$actor=$adventure.AddPartyActor(1,1)
$bag.AddStack(81,10)
$bag.AddStack(82,2)
$bag.AddStack(100,1)
$weapon=$bag.AddWeapon(40)
$legacy=[ProjectY.Data.EquipmentLegacyData]::Of($weapon)
Assert-True ($bag.SetRune($weapon.Id,1,100)) 'Rune fixture failed.'
Assert-True ($bag.Equip($actor.Id,$weapon.Id)) 'Equipped fixture failed.'
$condition=[ProjectY.Data.EquipmentConditionData]::Of($weapon)
Invoke-Hidden $condition 'Damage' @([int]70) | Out-Null
$camp.Open()
Assert-True ($camp.Upgrade(1,0,$camp.Revision,0,[int[]]@(),[int[]]@(),$bag,$player)-eq '') 'Facility fixture failed.'
Assert-True ($camp.Deposit(81,4,80,$camp.Revision,$bag)-eq '') 'Storage fixture failed.'
$campRevision=$camp.Revision
$bagRevision=$bag.Revision
$beforeCoins=$player.Coins
$beforeCurrent=$condition.Current
$forge=[ProjectY.Data.EquipmentForgeState]
Assert-True ($forge::Forge($adventure,$player,$weapon.Id,$campRevision,$bagRevision,1,1,10,[int[]]@(81,82),[int[]]@(6,3))-eq 'ForgeInsufficientMaterials') 'Partial-material forge was accepted.'
Assert-True ($forge::Forge($adventure,$player,$weapon.Id,$campRevision,$bagRevision,1,1,101,[int[]]@(),[int[]]@())-eq 'ForgeInsufficientCoins') 'Unaffordable forge was accepted.'
Assert-True ($forge::Forge($adventure,$player,$weapon.Id,$campRevision-1,$bagRevision,1,1,10,[int[]]@(),[int[]]@())-eq 'ForgeStateChanged') 'Stale camp click was accepted.'
Assert-True ($forge::Forge($adventure,$player,$weapon.Id,$campRevision,$bagRevision-1,1,1,10,[int[]]@(),[int[]]@())-eq 'ForgeStateChanged') 'Stale equipment click was accepted.'
Assert-True ($forge::Forge($adventure,$player,$weapon.Id,$campRevision,$bagRevision,1,2,10,[int[]]@(),[int[]]@())-eq 'ForgeFacilityRequired') 'Missing facility level was accepted.'
Assert-True ($camp.Revision-eq $campRevision -and $bag.Revision-eq $bagRevision -and $player.Coins-eq $beforeCoins -and $camp.Stored(81)-eq 4 -and $bag.CountItem(81)-eq 6 -and $bag.CountItem(82)-eq 2 -and $condition.Current-eq $beforeCurrent -and -not $legacy.Forged) 'Failed forge partially mutated state.'
Assert-True ($forge::Forge($adventure,$player,$weapon.Id,$campRevision,$bagRevision,1,1,10,[int[]]@(81,82),[int[]]@(6,1))-eq '') 'Valid forge failed.'
Assert-True ([object]::ReferenceEquals($weapon,$bag.GetWeapon($weapon.Id)) -and $weapon.ItemId-eq 40 -and $weapon.OwnerActorId-eq $actor.Id -and $weapon.Hand-eq 'weapon' -and $weapon.GetRune(1)-eq 100 -and [ProjectY.Data.EquipmentAffixData]::Of($weapon)-eq 3) 'Forge replaced identity, ownership, affix or attachment.'
Assert-True ($legacy.Forged -and $condition.Current-eq 100 -and $condition.Maximum-eq 100 -and $condition.BaseMaximum-eq 100 -and $condition.ThresholdArmed -and $camp.Stored(81)-eq 0 -and $bag.CountItem(81)-eq 4 -and $bag.CountItem(82)-eq 1 -and $player.Coins-eq 90) 'Forge did not restore condition or consume warehouse-first exact costs.'
Assert-True ($forge::Forge($adventure,$player,$weapon.Id,$camp.Revision,$bag.Revision,1,1,10,[int[]]@(),[int[]]@())-eq 'ForgeAlreadyWhole') 'Whole forged weapon was charged again.'
Write-Host 'PASS atomic forge: revisions, facility, funds, all materials, item identity and full durability'

Assert-True (-not $legacy.Awaken() -and -not $legacy.AcceptWish() -and -not $legacy.FulfillWish()) 'Growth stages were skipped.'
Assert-True ($legacy.RecordDeed(1,$actor.Id,101,7,10)) 'First deed was not recorded.'
Assert-True (-not $legacy.RecordDeed(1,$actor.Id,101,7,10)) 'Same rule and target were recorded twice.'
Assert-True ($legacy.RecordDeed(1,$actor.Id,102,8,11)) 'A second legendary target was suppressed.'
Assert-True (-not $legacy.ChoosePath(2,2) -and $legacy.ChoosePath(1,1) -and -not $legacy.ChoosePath(2,1)) 'Path prerequisite or one-time choice failed.'
Assert-True ($legacy.Awaken() -and -not $legacy.Awaken() -and $legacy.AcceptWish() -and -not $legacy.AcceptWish() -and $legacy.FulfillWish() -and -not $legacy.FulfillWish()) 'Awakening or wish transition replay failed.'
Invoke-Hidden $condition 'Damage' @([int]80) | Out-Null
Assert-True ($forge::Forge($adventure,$player,$weapon.Id,$camp.Revision,$bag.Revision,1,1,5,[int[]]@(),[int[]]@())-eq '') 'Reforging a worn legendary weapon failed.'
Assert-True ($condition.Current-eq 100 -and $condition.Maximum-eq 100 -and $legacy.DeedCount-eq 2 -and $legacy.PathId-eq 1 -and $legacy.Awakened -and $legacy.WishState-eq 2 -and $player.Coins-eq 85) 'Reforge reset growth or failed to restore wear.'
$enemyWeapon=$bag.AddWeapon(41)
Assert-True ($bag.Equip(999,$enemyWeapon.Id)) 'Enemy ownership fixture failed.'
Assert-True ($forge::Forge($adventure,$player,$enemyWeapon.Id,$camp.Revision,$bag.Revision,1,1,5,[int[]]@(),[int[]]@())-eq 'ForgeWeaponUnavailable') 'Enemy-owned equipment was forged.'
$bagWeapon=$bag.AddWeapon(40)
Assert-True ($forge::Forge($adventure,$player,$bagWeapon.Id,$camp.Revision,$bag.Revision,1,1,0,[int[]]@(),[int[]]@())-eq '') 'Backpack equipment could not be forged.'
Write-Host 'PASS history, branching, awakening and wishes remain attached to the same weapon through reforging'

# Exercise both inventory/equipped restoration and the shared container restoration path.
$owners=[Collections.Generic.HashSet[int]]::new()
$owners.Add($actor.Id)|Out-Null
$owners.Add(999)|Out-Null
$savedBag=Invoke-Hidden $bag 'CaptureSave' (,$owners)
$restoredBag=Invoke-Hidden $bag 'PrepareSave' @($savedBag,$owners)
$restored=[ProjectY.Data.EquipmentLegacyData]::Of($restoredBag.GetWeapon($weapon.Id))
Assert-True ($restored.PathId-eq 1 -and $restored.WishState-eq 2 -and $restored.DeedCount-eq 2 -and $restored.GetDeedAt(1).TargetId-eq 102) 'Inventory save lost legacy state.'
$ground=Invoke-Hidden $weapon 'CaptureSave'
$ground.owner=0
$ground.hand=''
$groundIds=[Collections.Generic.HashSet[int]]::new()
$restoredGround=Invoke-Hidden $bag 'PrepareGroundWeapon' @($ground,$groundIds)
Assert-True ([ProjectY.Data.EquipmentLegacyData]::Of($restoredGround).WishState-eq 2 -and $restoredGround.GetRune(1)-eq 100) 'Container save lost history or attachment.'

$saved=Invoke-Hidden $legacy 'Capture'
$saved.deeds=Saved-Array 'EquipmentDeedSave' @($saved.deeds[0],$saved.deeds[0])
Assert-InvalidSave {Invoke-Hidden ([ProjectY.Data.EquipmentLegacyData]) 'Prepare' @($saved)} 'Duplicate deeds were accepted.'
$saved=Invoke-Hidden $legacy 'Capture'
$saved.pathId=0
Assert-InvalidSave {Invoke-Hidden ([ProjectY.Data.EquipmentLegacyData]) 'Prepare' @($saved)} 'Awakened weapon without a path was accepted.'
$saved=Invoke-Hidden $legacy 'Capture'
$saved.format=0
Assert-InvalidSave {Invoke-Hidden ([ProjectY.Data.EquipmentLegacyData]) 'Prepare' @($saved)} 'Missing legacy format marker was accepted.'
$saved=Invoke-Hidden $legacy 'Capture'
$saved.deeds=$null
Assert-InvalidSave {Invoke-Hidden ([ProjectY.Data.EquipmentLegacyData]) 'Prepare' @($saved)} 'Missing deed list was accepted.'
Write-Host 'PASS equipped/backpack/container save round trips and corrupt legacy state rejection'

# Build each WeaponSave route: inventory/enemy equipment, area loot, caravan cargo, deferred conflict cargo.
$document=New-Saved 'CharacterSaveDocument'
$document.version=26
$document.equipment=$savedBag
$document.narrative=New-Saved 'NarrativeSave'
$document.narrative.minutes=100
$document.expedition=New-Saved 'ExpeditionSave'
$containers=@()
for($i=0;$i -lt 3;$i++){
    $loot=New-Saved 'LootSave'
    $loot.weapon=Invoke-Hidden $weapon 'CaptureSave'
    $container=New-Saved 'ContainerSave'
    $container.search=Saved-Array 'LootSave' @($loot)
    $containers+=,$container
}
$area=New-Saved 'AreaSave'
$area.loot=Saved-Array 'ContainerSave' @($containers[0])
$document.expedition.areas=Saved-Array 'AreaSave' @($area)
$document.expedition.parties=New-Saved 'WorldPartiesSave'
$party=New-Saved 'WorldPartySave'
$party.cargo=$containers[1]
$document.expedition.parties.parties=Saved-Array 'WorldPartySave' @($party)
$document.expedition.parties.factions=New-Saved 'WorldFactionsSave'
$conflict=New-Saved 'WorldFactionConflictSave'
$conflict.pendingCargo=Saved-Array 'ContainerSave' @($containers[2])
$document.expedition.parties.factions.conflicts=Saved-Array 'WorldFactionConflictSave' @($conflict)
Invoke-Hidden ([ProjectY.Data.EquipmentLegacyData]) 'MigrateAndValidate' @($document) | Out-Null
$allSaved=@($document.equipment.weapons)+@($containers | ForEach-Object {$_.search[0].weapon})
foreach($row in $allSaved){Assert-True ($row.legacy.format-eq 1 -and -not $row.legacy.forged -and $row.legacy.deeds.Length-eq 0) 'Legacy migration missed a WeaponSave ownership route.'}
$document.version=28
Invoke-Hidden ([ProjectY.Data.EquipmentLegacyData]) 'MigrateAndValidate' @($document) | Out-Null
foreach($row in $allSaved){
    $prior=$row.legacy
    $row.legacy=$null
    Assert-InvalidSave {Invoke-Hidden ([ProjectY.Data.EquipmentLegacyData]) 'MigrateAndValidate' @($document)} 'A current-format missing legacy record was accepted.'
    $row.legacy=$prior
}
$allSaved[0].legacy=Invoke-Hidden $legacy 'Capture'
$document.narrative.minutes=10
Assert-InvalidSave {Invoke-Hidden ([ProjectY.Data.EquipmentLegacyData]) 'MigrateAndValidate' @($document)} 'A deed from after the saved narrative clock was accepted.'
Write-Host 'PASS old-save migration and current-save validation across every physical weapon ownership route'

$evidence=[ProjectY.Data.EquipmentLegacyBattleData]::For($adventure)
$target=[ProjectY.Data.CombatActorData]::new(999,1)
$evidence.Begin()
Assert-True ($evidence.Record($weapon,$actor,$target,101,$false) -and -not $evidence.Record($weapon,$actor,$target,101,$false)) 'Battle contribution was duplicated.'
$target.GetType().GetProperty('HP',$flags).SetValue($target,0)
$evidence.MarkDefeated($target)
Assert-True ($evidence.WasDefeated($target) -and $evidence.Finish() -and -not $evidence.Finish() -and [object]::ReferenceEquals($evidence.GetAt(0).Weapon,$weapon)) 'Battle death evidence or one-time settlement failed.'
$evidence.Begin()
Assert-True ($evidence.Count-eq 0 -and -not $evidence.WasDefeated($target)) 'Next battle retained old contribution or death evidence.'
$evidence.Reset()
$camp.Close()
Assert-True ($forge::Forge($adventure,$player,$bagWeapon.Id,$camp.Revision,$bag.Revision,1,1,1,[int[]]@(),[int[]]@())-eq 'ForgeCampClosed') 'Closed camp accepted a forge command.'
$adventure.BeginEvent(1,1)
Assert-True ($forge::Forge($adventure,$player,$bagWeapon.Id,$camp.Revision,$bag.Revision,1,1,1,[int[]]@(),[int[]]@())-eq 'ForgeMapRequired') 'Non-map phase accepted a forge command.'
Write-Host 'PASS transient battle evidence and forge phase/session boundaries'

param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
# Uses an already compiled assembly and isolated data only. Does not start Unity or compile.
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
$lootGridProperty=[ProjectY.Data.MapAreaLootData].GetProperty('SearchGrid',([Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic))
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function New-Inventory {
    $result=[ProjectY.Data.EquipmentData]::new()
    $result.Grid.Configure(12,10)
    foreach($item in @(2,21,31,51,52,57)){$result.Grid.Define($item,1,1)}
    foreach($item in @(2,51,52,57)){[ProjectY.Data.EquipmentAffixData]::Define($result,$item,[int[]]@(1),[int[]]@(1))}
    return $result
}
$bag=New-Inventory
[ProjectY.Data.EquipmentCombatState]::Initialize($bag,901,2,0,[int[]]@(51,52,57),[string[]]@('head','body','offhand'))
$head=$bag.Worn(901,'head')
$body=$bag.Worn(901,'body')
$shield=$bag.Worn(901,'offhand')
$weapon=$bag.Equipped(901)
$headCondition=[ProjectY.Data.EquipmentConditionData]::Of($head)
$bodyCondition=[ProjectY.Data.EquipmentConditionData]::Of($body)
Assert-True ([ProjectY.Data.EquipmentCombatState]::DamageArmorAt($bag,901,'head',40)-eq 40) 'Head armor damage was incorrect.'
Assert-True ($headCondition.Current-eq 60 -and $bodyCondition.Current-eq 100) 'Head damage changed body armor.'
Assert-True ([ProjectY.Data.EquipmentCombatState]::DamageArmorAt($bag,901,'body',51)-eq 51) 'Body armor damage was incorrect.'
Assert-True ($bodyCondition.Current-eq 49 -and $bodyCondition.Maximum-eq 95 -and $headCondition.Current-eq 60) 'Body damage lost permanent-condition behavior or changed head armor.'
Assert-True ([ProjectY.Data.EquipmentConditionData]::Of($shield).Current-eq 100) 'Targeted armor damage affected the shield.'
$revision=$bag.Revision
Assert-True ([ProjectY.Data.EquipmentCombatState]::DamageArmorAt($bag,902,'body',10)-eq 0) 'Missing armor absorbed damage.'
Assert-True ($bag.Revision-eq $revision) 'Missing armor changed inventory revision.'
$rejected=$false
try{[ProjectY.Data.EquipmentCombatState]::DamageArmorAt($bag,901,'offhand',10)|Out-Null}catch{$rejected=$true}
Assert-True ($rejected -and $bag.Revision-eq $revision) 'Invalid targeted armor slot was accepted or mutated data.'
Assert-True ([ProjectY.Data.EquipmentCombatState]::DamageArmorAt($bag,901,'body',100)-eq 49) 'Armor damage was not capped by remaining condition.'
Assert-True ($bodyCondition.Broken) 'Body armor did not break.'
Write-Host 'PASS targeted head/body damage, permanent-condition threshold, shield exclusion and missing/invalid slots'

$magazine=$bag.AddMagazine(21,31,12,7)
Assert-True ($bag.AttachMagazine($weapon.Id,$magazine.Id)) 'Fixture magazine attachment failed.'
[ProjectY.Data.EquipmentCombatState]::DamageWeapon($bag,$weapon.Id,100)|Out-Null
$area=[ProjectY.Data.MapAreaStateData]::new(1,7,1)
$session=[ProjectY.Data.LootSessionData]::new()
$area.AddLoot(1,102,'armor fixture',[int[]]@(),[int[]]@(),$true)|Out-Null
$corpse=$area.GetLootAt(0)
$corpseGrid=$lootGridProperty.GetValue($corpse)
$session.Prepare($corpse,[string[]]@(),[int[]]@(),[int[]]@())
$revision=$bag.Revision
[ProjectY.Data.EquipmentCombatState]::DropActor($bag,$area,$corpse.Id,901)
Assert-True ($bag.Revision-eq $revision+1 -and $bag.WearableCount-eq 0 -and $bag.WeaponCount-eq 0 -and $bag.MagazineCount-eq 0) 'Corpse settlement retained equipment or missed its revision.'
Assert-True ($body.OwnerActorId-eq 0 -and $body.Slot-eq '') 'Destroyed armor retained its dead owner.'
$missing=$false
try{$bag.GetWearable($body.Id)|Out-Null}catch{$missing=$true}
Assert-True $missing 'Destroyed armor remained addressable in the inventory.'
$session.Open($area,[int[]]@($corpse.Id),$false,'fixture','fixture')
Assert-True ($session.Count-eq 3 -and $corpseGrid.Count-eq 3) 'Corpse did not contain exactly the broken weapon, damaged helmet and intact shield.'
$entries=@{}
for($index=0;$index-lt $session.Count;$index++){$entry=$session.GetAt($index);$entries[$entry.ItemId]=$entry}
Assert-True (-not $entries.ContainsKey(52)) 'Destroyed body armor entered corpse loot.'
Assert-True ([object]::ReferenceEquals([ProjectY.Data.EquipmentConditionData]::Of($entries[51]),$headCondition)) 'Damaged helmet was recreated.'
Assert-True ([ProjectY.Data.EquipmentConditionData]::Of($entries[57]).Current-eq 100) 'Intact shield condition was lost.'
Assert-True ([ProjectY.Data.EquipmentConditionData]::Of($entries[2]).Broken) 'Broken weapon drop behavior changed.'
$revision=$bag.Revision
[ProjectY.Data.EquipmentCombatState]::DropActor($bag,$area,$corpse.Id,901)
Assert-True ($bag.Revision-eq $revision -and $session.Count-eq 3 -and $corpseGrid.Count-eq 3) 'Repeated corpse settlement duplicated equipment.'
$received=New-Inventory
$entry=$entries[2]
$session.Advance($entry.Key,2,1)|Out-Null
Assert-True ($session.Take($received,$entry.Key,0,0,$false,0,0,0)) 'Broken weapon could no longer be looted.'
Assert-True ([object]::ReferenceEquals($received.GetWeapon($weapon.Id),$weapon) -and [object]::ReferenceEquals($received.GetMagazine($magazine.Id),$magazine) -and $magazine.Rounds-eq 7) 'Dropped weapon or loaded ammunition lost identity/state.'
$session.Close()
Write-Host 'PASS destroyed armor discarded once, intact/damaged armor retains identity, broken weapon and loaded magazine rules unchanged'

[ProjectY.Data.EquipmentCombatState]::Initialize($bag,902,0,0,[int[]]@(52),[string[]]@('body'))
[ProjectY.Data.EquipmentCombatState]::DamageArmorAt($bag,902,'body',100)|Out-Null
$area.AddLoot(2,102,'destroyed-only fixture',[int[]]@(),[int[]]@(),$true)|Out-Null
$empty=$area.GetLootAt(1)
$emptyGrid=$lootGridProperty.GetValue($empty)
$session.Prepare($empty,[string[]]@(),[int[]]@(),[int[]]@())
$revision=$bag.Revision
[ProjectY.Data.EquipmentCombatState]::DropActor($bag,$area,$empty.Id,902)
Assert-True ($bag.WearableCount-eq 0 -and $bag.Revision-eq $revision+1 -and $emptyGrid.Count-eq 0 -and $empty.Looted) 'Destroyed-only loadout was not fully removed.'
$revision=$bag.Revision
[ProjectY.Data.EquipmentCombatState]::DropActor($bag,$area,$empty.Id,902)
Assert-True ($bag.Revision-eq $revision -and $emptyGrid.Count-eq 0) 'Destroyed-only settlement was not idempotent.'
Write-Host 'PASS destroyed-only equipment leaves no inventory instance or corpse item'

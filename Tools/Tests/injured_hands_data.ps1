param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)|Out-Null
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$bag=[ProjectY.Data.EquipmentData]::new()
$bag.Grid.Configure(12,10)
foreach($id in @(40,52,57)){
    $bag.Grid.Define($id,1,1)
    [ProjectY.Data.EquipmentAffixData]::Define($bag,$id,[int[]]@(1),[int[]]@(1))
}
[ProjectY.Data.EquipmentCombatState]::Initialize($bag,901,40,0,[int[]]@(52,57),[string[]]@('body','offhand'))
$shield=$bag.Worn(901,'offhand')
$armor=$bag.Worn(901,'body')
$blade=$bag.Equipped(901)
[ProjectY.Data.EquipmentCombatState]::DamageArmor($bag,901,25)|Out-Null
$area=[ProjectY.Data.MapAreaStateData]::new(1,7,1)
$area.AddLoot(1,102,'injured shield',[int[]]@(),[int[]]@(),$true)
$container=$area.GetLootAt(0)
$session=[ProjectY.Data.LootSessionData]::new()
$session.Prepare($container,[string[]]@(),[int[]]@(),[int[]]@())
[ProjectY.Data.EquipmentCombatState]::DropWearable($bag,$area,$container.Id,901,$shield.Id)
Assert-True ($null-eq $bag.Worn(901,'offhand') -and [object]::ReferenceEquals($bag.Worn(901,'body'),$armor) -and [object]::ReferenceEquals($bag.Equipped(901),$blade)) 'Dropping the shield changed unrelated equipment.'
Assert-True ($shield.OwnerActorId-eq 0 -and $shield.Slot-eq '') 'Dropped shield retained its previous owner.'
$session.Open($area,[int[]]@($container.Id),$false,'fixture','fixture')
Assert-True ($session.Count-eq 1) 'Shield drop count is incorrect.'
$entry=$session.GetAt(0)
Assert-True ([ProjectY.Data.EquipmentConditionData]::Of($entry).Current-eq 75) 'Dropped shield lost its durability.'
$revision=$bag.Revision
$rejected=$false
try{[ProjectY.Data.EquipmentCombatState]::DropWearable($bag,$area,$container.Id,901,$shield.Id)}catch{$rejected=$true}
Assert-True ($rejected -and $bag.Revision-eq $revision -and $session.Count-eq 1) 'Repeated drop duplicated the shield.'
$session.Advance($entry.Key,2,1)|Out-Null
Assert-True ($session.Take($bag,$entry.Key,0,0,$false,0,0,0)) 'Shield could not be recovered into the bag.'
Assert-True ([object]::ReferenceEquals($bag.GetWearable($shield.Id),$shield) -and [ProjectY.Data.EquipmentConditionData]::Of($shield).Current-eq 75) 'Recovered shield did not preserve instance identity and condition.'
Assert-True ($container.Looted -and $entry.Count-eq 0) 'Recovered shield remained on the ground.'
$session.Close()
Write-Host 'PASS injured shield transfers once, preserves identity/durability, and leaves main hand/body armor intact'

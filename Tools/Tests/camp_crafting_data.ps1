param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
# Isolated data objects only; use an already compiled DLL, with no Editor or player saves.
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}

$camp=[ProjectY.Data.CampData]::new()
$bag=[ProjectY.Data.EquipmentData]::new()
$player=[ProjectY.Data.PlayerData]::new()
foreach($item in @(81,31,40,51)){$bag.Grid.Define($item,1,1)}
[ProjectY.Data.EquipmentAffixData]::Define($bag,40,[int[]]@(3),[int[]]@(1))
[ProjectY.Data.EquipmentAffixData]::Define($bag,51,[int[]]@(4),[int[]]@(1))
$bag.Grid.Configure(4,1)
$bag.AddStack(81,1)
$camp.Open()
Assert-True ($camp.Upgrade(1,0,$camp.Revision,0,[int[]]@(),[int[]]@(),$bag,$player)-eq '') 'Fixture upgrade failed.'
Assert-True ($camp.Enqueue(1,1,1,0,60,$camp.Revision,0,[int[]]@(),[int[]]@(),$bag,$player)-eq '') 'Fixture production failed.'
$version=$camp.Revision
$bagVersion=$bag.Revision
$ids=[int[]]@(31,40,51)
$counts=[int[]]@(12,2,1)
$kinds=[string[]]@('ammo','weapon','wearable')
Assert-True ($camp.Claim(1,$version,59,$ids,$counts,$kinds,$bag)-eq 'CampProductionPending') 'Unfinished production was claimable.'
Assert-True ($camp.Claim(1,$version,60,$ids,$counts,$kinds,$bag)-eq 'UICampText31') 'Mixed outputs bypassed the full-group capacity check.'
Assert-True ($camp.Revision-eq $version -and $camp.JobCount-eq 1 -and $bag.Revision-eq $bagVersion) 'Failed claim changed order or inventory revision.'
Assert-True ($bag.CountItem(31)-eq 0 -and $bag.WeaponCount-eq 0 -and $bag.WearableCount-eq 0 -and $bag.Grid.Count-eq 1) 'Failed claim partially granted output.'
Assert-True ($bag.CountItem(81)-eq 1 -and $null-ne $bag.Grid.Find('s81')) 'Failed claim altered existing inventory.'
$rejected=$false
try{$camp.Claim(1,$version,60,[int[]]@(31,21),[int[]]@(12,1),[string[]]@('ammo','magazine'),$bag)|Out-Null}catch{$rejected=$true}
Assert-True $rejected 'A magazine output without ammunition specification was accepted.'
Assert-True ($camp.Revision-eq $version -and $camp.JobCount-eq 1 -and $bag.Revision-eq $bagVersion) 'Unsupported output changed the order or earlier output.'
Write-Host 'PASS unfinished/full/unsupported claims preserve the entire order and inventory'

$bag.ConsumeStack(81,1)
Assert-True ($camp.Claim(1,$version,60,$ids,$counts,$kinds,$bag)-eq '') 'Valid mixed-output claim failed.'
Assert-True ($camp.JobCount-eq 0 -and $camp.Revision-eq $version+1) 'Successful claim did not close exactly one order.'
Assert-True ($bag.CountItem(31)-eq 12 -and $bag.WeaponCount-eq 2 -and $bag.WearableCount-eq 1 -and $bag.Grid.Count-eq 4) 'Successful claim granted incorrect quantities or occupancy.'
$first=$bag.GetWeaponAt(0)
$second=$bag.GetWeaponAt(1)
$armor=$bag.GetWearableAt(0)
Assert-True ($first.ItemId-eq 40 -and $second.ItemId-eq 40 -and $armor.ItemId-eq 51) 'Equipment output used incorrect item IDs.'
Assert-True ($first.Id-ne $second.Id -and $first.Id-ne $armor.Id -and $second.Id-ne $armor.Id) 'Equipment output reused an instance ID.'
foreach($weapon in @($first,$second)){
    Assert-True ($weapon.OwnerActorId-eq 0 -and $null-ne $bag.Grid.Find('w'+$weapon.Id)) 'Created weapon is missing from the shared backpack.'
    Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($weapon)-eq 3) 'Crafted weapon skipped its configured affix pool.'
}
Assert-True ($armor.OwnerActorId-eq 0 -and $null-ne $bag.Grid.Find('g'+$armor.Id)) 'Created wearable is missing from the shared backpack.'
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($armor)-eq 4) 'Crafted wearable skipped its configured affix pool.'
foreach($item in @($first,$second,$armor)){
    $condition=[ProjectY.Data.EquipmentConditionData]::Of($item)
    Assert-True ($condition.Current-eq 100 -and $condition.Maximum-eq 100 -and $condition.BaseMaximum-eq 100 -and -not $condition.Broken) 'New equipment did not receive the existing fresh durability state.'
}
Write-Host 'PASS mixed outputs create separate equipment with configured affixes and fresh durability'

$claimedVersion=$bag.Revision
Assert-True ($camp.Claim(1,$version,60,$ids,$counts,$kinds,$bag)-eq 'UICampText5') 'Stale duplicate claim was accepted.'
Assert-True ($camp.Claim(1,$camp.Revision,60,$ids,$counts,$kinds,$bag)-eq 'UICampText12') 'An absent order was claimed twice.'
Assert-True ($bag.Revision-eq $claimedVersion -and $bag.WeaponCount-eq 2 -and $bag.WearableCount-eq 1 -and $bag.CountItem(31)-eq 12) 'Duplicate claims changed output quantities.'
Write-Host 'PASS duplicate claims cannot duplicate equipment or stack output'

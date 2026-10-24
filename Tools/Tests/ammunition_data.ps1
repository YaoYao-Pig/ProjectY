param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
# Isolated data objects and in-memory save DTOs only. Never compile or open player saves.
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
$hidden=[Reflection.BindingFlags]'Instance,NonPublic'
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Invoke-Hidden($Instance,[string]$Name,[object[]]$Arguments){
    $method=$Instance.GetType().GetMethod($Name,$hidden)
    if($null-eq $method){throw "Missing compiled method: $Name"}
    return $method.Invoke($Instance,$Arguments)
}
function New-Bag([int]$Width=6,[int]$Height=1){
    $bag=[ProjectY.Data.EquipmentData]::new();$bag.Grid.Configure($Width,$Height)
    foreach($item in @(21,31,822,823,820,81)){$bag.Grid.Define($item,1,1)}
    foreach($ammo in @(31,822,823)){[ProjectY.Data.EquipmentAmmunition]::Define($bag,$ammo,1)}
    [ProjectY.Data.EquipmentAmmunition]::Define($bag,820,2)
    return $bag
}
function Capture($Bag){
    $arguments=[object[]]::new(1);$arguments[0]=[Collections.Generic.HashSet[int]]::new()
    return Invoke-Hidden $Bag 'CaptureSave' $arguments
}
function Prepare($Bag,$Payload){
    $arguments=[object[]]::new(2);$arguments[0]=$Payload;$arguments[1]=[Collections.Generic.HashSet[int]]::new()
    return Invoke-Hidden $Bag 'PrepareSave' $arguments
}
function State-Text($Bag){return ((Capture $Bag)|ConvertTo-Json -Depth 12 -Compress)}
function Ammo-Total($Bag,[int]$Item){
    $total=[long]$Bag.CountItem($Item)
    for($i=0;$i-lt $Bag.MagazineCount;$i++){$mag=$Bag.GetMagazineAt($i);if($mag.AmmoItemId-eq $Item){$total+=$mag.Rounds}}
    return $total
}
function Refill($Bag,$Magazine,[int]$Ammo){return [ProjectY.Data.EquipmentAmmunition]::Refill($Bag,$Magazine.Id,$Ammo)}
function Add-Pile($Bag,[int]$Item,[int]$Count,[int]$X){
    $area=[ProjectY.Data.MapAreaStateData]::new(1,8,1)
    $area.AddLoot(1,1,'isolated ammunition fixture',[int[]]@($Item),[int[]]@($Count),$false)
    $session=[ProjectY.Data.LootSessionData]::new()
    $session.Prepare($area.GetLootAt(0),[string[]]@('ammo'),[int[]]@(1),[int[]]@(1))
    $session.Open($area,[int[]]@(1),$false,'test','')
    $entry=$session.GetAt(0);[void]$session.Advance($entry.Key,2,1)
    Assert-True ($session.Take($Bag,$entry.Key,$X,0,$false,0,0,0)) 'Fixture independent ammo transfer failed.'
    Assert-True ($entry.Count-eq 0) 'Fixture loot still owns transferred ammo.'
    for($i=0;$i-lt $Bag.StackCount;$i++){
        $row=$Bag.GetStackAt($i);$key=[ProjectY.Data.InventoryStacks]::Key($row);$place=$Bag.Grid.Find($key)
        if($row.ItemId-eq $Item -and $null-ne $place -and $place.X-eq $X){return $row}
    }
    throw 'Fixture independent ammo pile was not found.'
}

$bag=New-Bag
$mag=$bag.AddMagazine(21,31,5,2);$bag.AddStack(31,5);$bag.AddStack(820,1)
Assert-True ((Refill $bag $mag 31)-eq '') 'Same-type refill failed.'
Assert-True ($mag.AmmoItemId-eq 31 -and $mag.Rounds-eq 5 -and $bag.CountItem(31)-eq 2 -and (Ammo-Total $bag 31)-eq 7) 'Same-type refill lost or duplicated rounds.'
$before=State-Text $bag;$revision=$bag.Revision
Assert-True ((Refill $bag $mag 31)-eq 'AmmoMagazineFull') 'Full magazine accepted more rounds.'
Assert-True ((Refill $bag $mag 820)-eq 'AmmoIncompatible') 'Cross-caliber ammunition was accepted.'
Assert-True ((Refill $bag $mag 823)-eq 'AmmoUnavailable') 'Unavailable ammunition changed the magazine.'
Assert-True ($bag.Revision-eq $revision -and (State-Text $bag)-eq $before) 'Rejected refill changed inventory, counters or magazine state.'
Write-Host 'PASS same-type refill and atomic full/unavailable/cross-caliber rejection'

$full=New-Bag 2 1
$fullMag=$full.AddMagazine(21,31,5,3);$full.AddStack(822,10)
$before=State-Text $full;$revision=$full.Revision
Assert-True ((Refill $full $fullMag 822)-eq 'AmmoReturnBackpackFull') 'Switch accepted an old-ammo return that cannot fit.'
Assert-True ($full.Revision-eq $revision -and (State-Text $full)-eq $before) 'Full-backpack rejection partially consumed or returned ammunition.'

$exchange=New-Bag 2 1
$exchangeMag=$exchange.AddMagazine(21,31,5,3);$exchange.AddStack(822,5)
Assert-True ((Refill $exchange $exchangeMag 822)-eq '') 'Consuming the complete incoming stack did not free room for returned ammo.'
Assert-True ($exchangeMag.AmmoItemId-eq 822 -and $exchangeMag.Rounds-eq 5 -and $exchange.CountItem(31)-eq 3 -and $exchange.CountItem(822)-eq 0) 'Successful exchange has incorrect ammunition ownership.'
Assert-True ($exchange.Grid.Count-eq 2 -and $null-ne $exchange.Grid.Find('s31') -and $null-eq $exchange.Grid.Find('s822')) 'Exchange left a ghost incoming stack or omitted returned ammunition.'
foreach($ammo in @(31,822,31,822,31,822)){
    Assert-True ((Refill $exchange $exchangeMag $ammo)-eq '') 'Repeated ammunition exchange failed.'
    Assert-True ((Ammo-Total $exchange 31)-eq 3 -and (Ammo-Total $exchange 822)-eq 5 -and $exchange.Grid.Count-eq 2) 'Repeated exchanges lost, duplicated or stranded ammunition.'
}
Write-Host 'PASS full-backpack atomicity, consumed-stack space reuse and repeated per-type conservation'

$split=New-Bag 6 1
$splitMag=$split.AddMagazine(21,31,5,1);$split.AddStack(822,2)
$older=Add-Pile $split 822 3 3
$newer=Add-Pile $split 822 4 5
$olderKey=[ProjectY.Data.InventoryStacks]::Key($older)
$newerKey=[ProjectY.Data.InventoryStacks]::Key($newer)
Assert-True ($olderKey-like 'p*' -and $newerKey-like 'p*' -and $olderKey-ne $newerKey) 'Fixture did not create independent ammunition piles.'
Assert-True ((Refill $split $splitMag 822)-eq '') 'Refill across canonical and independent piles failed.'
Assert-True ($null-eq $split.Grid.Find('s822') -and $null-eq $split.Grid.Find($olderKey) -and $newer.Count-eq 4) 'Refill did not consume canonical then oldest independent pile first.'
Assert-True ($split.Grid.Find($newerKey).X-eq 5 -and (Ammo-Total $split 822)-eq 9 -and (Ammo-Total $split 31)-eq 1) 'Independent-pile refill moved sibling stock or changed totals.'

$saved=Capture $split
Assert-True ($saved.magazines[0].ammo-eq 822 -and $saved.magazines[0].rounds-eq 5) 'Save payload recorded the default rather than actual loaded ammunition.'
$restored=Prepare $split $saved
Assert-True ((State-Text $restored)-eq (State-Text $split)) 'PrepareSave changed ammunition type, piles, placement or counters.'
$restoredMag=$restored.GetMagazine($splitMag.Id)
Assert-True ((Refill $restored $restoredMag 31)-eq '') 'Prepared inventory lost caliber definitions needed for future exchanges.'
Assert-True ($restoredMag.AmmoItemId-eq 31 -and $restoredMag.Rounds-eq 1 -and $restored.CountItem(822)-eq 9) 'Prepared inventory could not return the previous actual ammo type.'
Assert-True ($null-eq $restored.Grid.Find('s822') -and $null-ne $restored.Grid.Find($newerKey)) 'Returning old ammunition did not merge into its existing independent pile.'
Assert-True ((Ammo-Total $restored 31)-eq 1 -and (Ammo-Total $restored 822)-eq 9) 'Save/restore/exchange changed per-type totals.'
Assert-True ((State-Text $split)-eq ($saved|ConvertTo-Json -Depth 12 -Compress)) 'Changing the prepared inventory mutated the original data object.'
$loaded=New-Bag 6 1
$arguments=[object[]]::new(1);$arguments[0]=$restored
Invoke-Hidden $loaded 'TakePrepared' $arguments|Out-Null
Assert-True ((Refill $loaded ($loaded.GetMagazine($splitMag.Id)) 822)-eq '') 'Installed prepared inventory cannot continue exchanging ammunition.'
Assert-True ((Ammo-Total $loaded 31)-eq 1 -and (Ammo-Total $loaded 822)-eq 9) 'TakePrepared exchange changed per-type totals.'
Write-Host 'PASS deterministic independent-pile consumption, actual-type save/restore and continued exchanges'

$overflow=New-Bag
$overflowMag=$overflow.AddMagazine(21,31,5,1)
$overflow.AddStack(31,[int]::MaxValue);$overflow.AddStack(822,1)
$before=State-Text $overflow;$revision=$overflow.Revision
Assert-True ((Refill $overflow $overflowMag 822)-eq 'AmmoCountLimit') 'Returned ammo overflow was accepted.'
Assert-True ($overflow.Revision-eq $revision -and (State-Text $overflow)-eq $before) 'Overflow rejection changed magazine or inventory.'
Write-Host 'PASS returned-ammunition overflow is rejected before mutation'

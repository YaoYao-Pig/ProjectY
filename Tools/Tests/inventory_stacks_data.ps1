param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
# Run only against an already compiled project DLL. No Editor, compilation or player save files.
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
$hidden=[Reflection.BindingFlags]'Instance,NonPublic'
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Invoke-Hidden($Instance,[string]$Name,[object[]]$Arguments){
    $method=$Instance.GetType().GetMethod($Name,$hidden)
    if($null-eq $method){throw "Missing compiled method: $Name"}
    return $method.Invoke($Instance,$Arguments)
}
function New-Bag([int]$Width=8,[int]$Height=6){
    $bag=[ProjectY.Data.EquipmentData]::new();$bag.Grid.Configure($Width,$Height)
    foreach($item in @(10,11,12,13,14,15,16,83)){$bag.Grid.Define($item,1,1)}
    $bag.Grid.Define(10,2,1);$bag.Grid.Define(15,1,2);$bag.Grid.Define(16,2,2)
    [ProjectY.Data.EquipmentAffixData]::Define($bag,16,[int[]]@(1),[int[]]@(1))
    return $bag
}
function New-Loot([int]$Item,[int]$Count,[int]$Width=1,[int]$Height=1){
    $area=[ProjectY.Data.MapAreaStateData]::new(1,8,1)
    $area.AddLoot(1,1,'isolated test container',[int[]]@($Item),[int[]]@($Count),$false)
    $container=$area.GetLootAt(0);$session=[ProjectY.Data.LootSessionData]::new()
    $session.Prepare($container,[string[]]@('stack'),[int[]]@($Width),[int[]]@($Height))
    $session.Open($area,[int[]]@(1),$false,'test','')
    $entry=$session.GetAt(0);[void]$session.Advance($entry.Key,2,1)
    return [pscustomobject]@{Area=$area;Container=$container;Session=$session;Entry=$entry}
}
function Stack-Rows($Bag,[int]$Item){
    $rows=@();for($i=0;$i-lt $Bag.StackCount;$i++){$r=$Bag.GetStackAt($i);if($r.ItemId-eq $Item -and $r.Count-gt 0){$rows+=$r}}
    return ,$rows
}
function Stack-Key($Row){return [ProjectY.Data.InventoryStacks]::Key($Row)}
function Add-Pile($Bag,[int]$Item,[int]$Count,[int]$X,[int]$Y,[bool]$Rotated=$false,[int]$Width=1,[int]$Height=1){
    $loot=New-Loot $Item $Count $Width $Height
    Assert-True ($loot.Session.Take($Bag,$loot.Entry.Key,$X,$Y,$Rotated,0,0,0)) 'Fixture pile transfer failed.'
    return $loot
}
function Capture($Bag){
    $invokeArgs=[object[]]::new(1);$invokeArgs[0]=[Collections.Generic.HashSet[int]]::new()
    return Invoke-Hidden $Bag 'CaptureSave' $invokeArgs
}
function Prepare($Bag,$Payload){
    $invokeArgs=[object[]]::new(2);$invokeArgs[0]=$Payload;$invokeArgs[1]=[Collections.Generic.HashSet[int]]::new()
    return Invoke-Hidden $Bag 'PrepareSave' $invokeArgs
}
function State-Text($Bag){
    $save=Capture $Bag
    return ($save | ConvertTo-Json -Depth 12 -Compress)
}
function Expect-Rejected([scriptblock]$Action,[string]$Message){
    $rejected=$false;try{& $Action | Out-Null}catch{$rejected=$true}
    Assert-True $rejected $Message
}

$bag=New-Bag;$bag.AddStack(10,5)
$first=Add-Pile $bag 10 3 3 0 $false 2 1
$rows=Stack-Rows $bag 10;$independent=@($rows|Where-Object{(Stack-Key $_)-like 'p*'})
Assert-True ($rows.Count-eq 2 -and $independent.Count-eq 1 -and $bag.CountItem(10)-eq 8) 'Dropping identical loot on empty cells did not create a separate pile.'
$pileKey=Stack-Key $independent[0]
Assert-True ($bag.Grid.Find('s10').X-eq 0 -and $bag.Grid.Find($pileKey).X-eq 3 -and $first.Entry.Count-eq 0) 'New pile moved canonical stock or left source loot duplicated.'
$merge=Add-Pile $bag 10 2 1 0 $false 2 1
Assert-True ((Stack-Rows $bag 10).Count-eq 2 -and $bag.CountItem(10)-eq 10 -and $independent[0].Count-eq 3) 'Dropping onto the existing canonical pile did not merge only that pile.'
Assert-True ($bag.Move($pileKey,5,1,$true)) 'Independent pile rotation/movement failed.'
Assert-True ($bag.Grid.Find($pileKey).Rotated -and $bag.Grid.Find($pileKey).Width-eq 1 -and $bag.Grid.Find($pileKey).Height-eq 2 -and $bag.Grid.Find('s10').X-eq 0) 'Rotating one pile affected its sibling.'
$bag.AddStack(11,1);$blocked=$bag.Grid.Find('s11');$snapshot=State-Text $bag
Assert-True (-not $bag.Move($pileKey,$blocked.X,$blocked.Y,$false)) 'Different item collision was accepted.'
Assert-True (-not $bag.Move($pileKey,8,0,$false)) 'Out-of-bounds pile move was accepted.'
Assert-True ((State-Text $bag)-eq $snapshot) 'Rejected move changed quantities, positions or counters.'
$blockedLoot=New-Loot 10 9 2 1
Assert-True (-not $blockedLoot.Session.Take($bag,$blockedLoot.Entry.Key,$blocked.X,$blocked.Y,$false,0,0,0)) 'Loot transfer onto a different item succeeded.'
Assert-True ((State-Text $bag)-eq $snapshot -and $blockedLoot.Entry.Count-eq 9) 'Rejected loot placement lost or duplicated items.'
Write-Host 'PASS empty-cell new pile, explicit same-item merge, independent rotation and atomic invalid placement'

$saved=Capture $bag;$restored=Prepare $bag $saved
Assert-True ((State-Text $restored)-eq (State-Text $bag)) 'Capture/prepare did not preserve keys, coordinates, quantities and counters.'
$copy=New-Bag;$invokeArgs=[object[]]::new(1);$invokeArgs[0]=$restored;Invoke-Hidden $copy 'TakePrepared' $invokeArgs | Out-Null
Assert-True ((State-Text $copy)-eq (State-Text $bag)) 'TakePrepared did not preserve the pile counter or grid.'
$counter=$saved.nextPileId;$extra=Add-Pile $copy 10 1 7 4 $true 2 1
Assert-True ($null-ne $copy.Grid.Find('p'+$counter) -and (Capture $copy).nextPileId-eq $counter+1) 'Restored independent-pile counter was reused or not advanced.'
$baseline=State-Text $bag
$invalid=Capture $bag;$invalid.nextPileId=$invalid.piles[0].id
Expect-Rejected {Prepare $bag $invalid} 'Invalid pile counter was accepted.'
$invalid=Capture $bag;$invalid.piles[0].count=[int]::MaxValue
Expect-Rejected {Prepare $bag $invalid} 'Aggregated stack overflow was accepted.'
$invalid=Capture $bag;$invalid.placements[1].x=$invalid.placements[0].x;$invalid.placements[1].y=$invalid.placements[0].y
Expect-Rejected {Prepare $bag $invalid} 'Overlapping saved pile placement was accepted.'
Assert-True ((State-Text $bag)-eq $baseline) 'Rejected save preparation mutated the live inventory.'
$legacy=New-Bag;$legacy.AddStack(10,4);$legacyPayload=Capture $legacy
Assert-True ($legacyPayload.piles.Length-eq 0 -and $legacyPayload.stacks.Length-eq 1 -and $legacyPayload.nextPileId-eq 1) 'Canonical old-format stack payload was not retained.'
$legacyRestored=Prepare $legacy $legacyPayload
Assert-True ($legacyRestored.CountItem(10)-eq 4 -and $null-ne $legacyRestored.Grid.Find('s10')) 'Canonical legacy stack cannot be read.'
Write-Host 'PASS save capture/prepare/copy, stable counters, canonical compatibility and malformed-payload isolation'

$deposit=New-Loot 11 1
$bagCount=$bag.CountItem(10);$selectedCount=$independent[0].Count
Assert-True ($deposit.Session.Put($bag,$pileKey,3,1,$true)) 'Independent pile could not be deposited.'
Assert-True ($bag.CountItem(10)-eq $bagCount-$selectedCount -and $null-ne $bag.Grid.Find('s10') -and $null-eq $bag.Grid.Find($pileKey)) 'Deposit moved sibling quantities instead of only selected pile.'
$stored=$deposit.Session.GetAt($deposit.Session.Count-1)
Assert-True ($stored.ItemId-eq 10 -and $stored.Count-eq $selectedCount -and $stored.Revealed) 'Container did not receive exactly the selected pile.'
Assert-True ($deposit.Session.Take($bag,$stored.Key,5,1,$true,0,0,0)) 'Deposited pile could not return to inventory.'
Assert-True ($stored.Count-eq 0 -and $bag.CountItem(10)-eq $bagCount -and (Stack-Rows $bag 10).Count-eq 2) 'Container roundtrip lost or duplicated selected pile.'
$returned=@((Stack-Rows $bag 10)|Where-Object{(Stack-Key $_)-like 'p*'})[0];$returnedKey=Stack-Key $returned
Assert-True ($bag.Move($returnedKey,1,0,$false)) 'Moving a pile onto its same-item sibling did not merge.'
Assert-True ((Stack-Rows $bag 10).Count-eq 1 -and $bag.CountItem(10)-eq $bagCount -and $null-eq $bag.Grid.Find($returnedKey)) 'Same-backpack merge duplicated stock or left a ghost placement.'
$full=New-Bag 2 1;$full.AddStack(10,2);$more=New-Loot 11 3;$fullBefore=State-Text $full
Assert-True (-not $more.Session.Take($full,$more.Entry.Key,0,0,$false,0,0,0)) 'Full inventory unexpectedly accepted another item.'
Assert-True ((State-Text $full)-eq $fullBefore -and $more.Entry.Count-eq 3) 'Full inventory failure changed source or destination.'
Write-Host 'PASS selected-pile container roundtrip, same-backpack merging and full-inventory rollback'

$consume=New-Bag;$consume.AddStack(12,1);$a=Add-Pile $consume 12 2 3 0;$b=Add-Pile $consume 12 3 5 0
$consume.ConsumeStack(12,4)
Assert-True ($consume.CountItem(12)-eq 2 -and (Stack-Rows $consume 12).Count-eq 1 -and $null-eq $consume.Grid.Find('s12')) 'Consumption did not span piles or remove empty placements.'
$before=State-Text $consume;Expect-Rejected {$consume.ConsumeStack(12,3)} 'Insufficient cross-pile consumption was accepted.'
Assert-True ((State-Text $consume)-eq $before) 'Failed consumption changed the inventory.'
$consume.AddStack(13,1);$invokeArgs=[object[]]::new(2);$invokeArgs[0]=[int[]]@(12,13);$invokeArgs[1]=[int[]]@(1,2)
$before=State-Text $consume;Expect-Rejected {Invoke-Hidden $consume 'ConsumeMaterials' $invokeArgs} 'Incomplete multi-material transaction was accepted.'
Assert-True ((State-Text $consume)-eq $before) 'Multi-material preflight consumed earlier valid materials.'
$invokeArgs[1]=[int[]]@(2,1);Invoke-Hidden $consume 'ConsumeMaterials' $invokeArgs | Out-Null
Assert-True ($consume.CountItem(12)-eq 0 -and $consume.CountItem(13)-eq 0) 'Construction materials did not consume independent piles.'
$consume.AddStack(14,2);$ammo=Add-Pile $consume 14 5 3 0;$mag=$consume.AddMagazine(15,14,6,0)
Assert-True ($consume.FillMagazine($mag.Id)-eq 6 -and $mag.Rounds-eq 6 -and $consume.CountItem(14)-eq 1) 'Magazine fill stopped at one loose-ammo pile.'
$consume.AddStack(12,1);$rune=Add-Pile $consume 12 2 5 2;$consume.ConsumeStack(12,1);$weapon=$consume.AddWeapon(16)
Assert-True ($null-eq $consume.Grid.Find('s12') -and (Stack-Key (Stack-Rows $consume 12)[0])-like 'p*') 'Rune fixture must retain an independent pile after consuming canonical stock.'
Assert-True ($consume.SetRune($weapon.Id,1,12) -and $weapon.GetRune(1)-eq 12 -and $consume.CountItem(12)-eq 1) 'Rune install did not use an independent pile.'
Assert-True ($consume.SetRune($weapon.Id,1,0) -and $consume.CountItem(12)-eq 2) 'Removed rune did not return without loss.'
$player=[ProjectY.Data.PlayerData]::new();$player.AddCoins(500)
[void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($consume,$weapon.Id,40)
$consume.AddStack(83,1);$metal=Add-Pile $consume 83 1 7 0
Assert-True ([ProjectY.Data.EquipmentCombatState]::Repair($consume,$player,'w'+$weapon.Id,83)) 'Repair could not consume materials split across piles.'
Assert-True ($consume.CountItem(83)-eq 0) 'Repair did not consume the exact cross-pile material budget.'
Write-Host 'PASS cross-pile consumption/construction, magazine fill, rune install/remove and repair'

$actor=[ProjectY.Data.CombatActorData]::new(1,1);$actor.SetMaxHP(100);$actor.Restore();$actor.Deploy(1,0,0);$actor.BeginTurn(4)
[ProjectY.Data.BattleMovement]::Move($actor,1,0,1,2,5)
Assert-True ($actor.AP-eq 3 -and [ProjectY.Data.BattleMovement]::Spent($actor)-eq 2 -and -not $actor.Moved) 'First movement segment charged the wrong AP or ended movement early.'
[ProjectY.Data.BattleMovement]::Move($actor,2,0,1,1,5)
Assert-True ($actor.AP-eq 3 -and [ProjectY.Data.BattleMovement]::Spent($actor)-eq 3) 'Second segment charged movement AP again.'
Expect-Rejected {[ProjectY.Data.BattleMovement]::Move($actor,3,0,1,3,5)} 'Over-budget movement segment was accepted.'
Assert-True ($actor.Q-eq 2 -and $actor.R-eq 0 -and $actor.AP-eq 3 -and [ProjectY.Data.BattleMovement]::Spent($actor)-eq 3) 'Rejected segment changed actor state.'
$actor.SpendAction('main',2)
Assert-True ([ProjectY.Data.BattleMovement]::Remaining($actor,5)-eq 0) 'Main action failed to close remaining movement.'
Expect-Rejected {[ProjectY.Data.BattleMovement]::Move($actor,3,0,1,1,5)} 'Movement remained available after main action.'
$actor.BeginTurn(4);Assert-True ([ProjectY.Data.BattleMovement]::Spent($actor)-eq 0) 'New turn did not reset movement distance.'
$actor.Move(4,0,1);Assert-True ($actor.Moved -and $actor.AP-eq 3) 'Legacy Move no longer preserves one-shot movement semantics.'
Write-Host 'PASS segmented movement AP/distance budget, action closure, rejection atomicity and turn reset'
Write-Host 'PASS inventory_stacks_data complete (in-memory Data only; no disk save or Editor activity)'

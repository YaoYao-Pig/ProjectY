param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
function Check([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
$bag=[ProjectY.Data.EquipmentData]::new()
$bag.Grid.Configure(6,4)
$bag.Grid.Define(81,2,1)
$bag.Grid.Define(82,1,2)
$bag.AddStack(81,12)
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$grant=$bag.GetType().GetMethod('GrantAt',$flags)
Check ($grant.Invoke($bag,[object[]]@(81,'material',7,3,0,$false,0,0,0))) 'Independent source pile creation failed.'
$pile=$null
for($i=0;$i-lt $bag.StackCount;$i++){$row=$bag.GetStackAt($i);if([ProjectY.Data.InventoryStacks]::Key($row)-eq 'p1'){$pile=$row}}
Check ($null-ne $pile -and $pile.Count-eq 7) 'Independent source identity missing.'
$camp=[ProjectY.Data.CampData]::new();$camp.Open()
Check ($camp.DepositAt('p1',0,0,$false,80,$camp.Revision,$bag.Revision,'material',$bag)-eq '') 'Exact pile deposit failed.'
Check ($bag.CountItem(81)-eq 12 -and $bag.GetStackAt(0).Count-eq 12 -and $camp.Stored(81)-eq 7) 'Deposit consumed a different pile.'
$before=$camp.Revision;$bagBefore=$bag.Revision
Check ($camp.DepositAt('s81',11,9,$false,80,$before,$bagBefore,'material',$bag)-eq 'CampWarehousePlacementInvalid') 'Out-of-bounds warehouse drop succeeded.'
Check ($camp.Revision-eq $before -and $bag.Revision-eq $bagBefore -and $bag.CountItem(81)-eq 12) 'Invalid drop mutated ownership.'
Check ($camp.DepositAt('s81',3,0,$false,80,$camp.Revision,$bag.Revision,'material',$bag)-eq '') 'Second independent warehouse pile failed.'
Check ($camp.StorageCount-eq 2 -and $camp.Stored(81)-eq 19) 'Empty-grid drop merged unexpectedly.'
Check ($camp.MoveStored('c2',0,0,$false,$camp.Revision)-eq '') 'Explicit same-kind merge failed.'
Check ($camp.StorageCount-eq 1 -and $camp.Stored(81)-eq 19 -and $null-eq $camp.Warehouse.Find('c2')) 'Merged pile retained ownership or placement.'
$bag.AddStack(82,1);$before=$camp.Revision;$bagBefore=$bag.Revision
Check ($camp.WithdrawAt('c1',0,0,$false,$before,$bagBefore,'material',$bag)-eq 'CampWithdrawBackpackFull') 'Occupied backpack drop succeeded.'
Check ($camp.Revision-eq $before -and $bag.Revision-eq $bagBefore -and $camp.Stored(81)-eq 19) 'Failed withdrawal partially transferred.'
Check ($camp.WithdrawAt('c1',2,2,$true,$camp.Revision,$bag.Revision,'material',$bag)-eq '') 'Rotated withdrawal failed.'
$place=$bag.Grid.Find('s81')
Check ($place.X-eq 2 -and $place.Y-eq 2 -and $place.Rotated -and $bag.CountItem(81)-eq 19 -and $camp.StoredTotal-eq 0) 'Withdrawal ignored the requested cell or rotation.'
$before=$camp.Revision;$bagBefore=$bag.Revision
Check ($camp.DepositAt('s81',0,0,$false,10,$before,$bagBefore,'material',$bag)-eq 'CampWarehouseFull') 'Warehouse item capacity was bypassed.'
Check ($camp.DepositAt('s81',0,0,$false,80,$before,$bagBefore-1,'material',$bag)-eq 'UICampText5') 'Stale backpack revision was accepted.'
Check ($camp.DepositAt('s81',0,0,$false,80,$before,$bagBefore,'weapon',$bag)-eq 'CampUnsupportedItem') 'Mismatched item identity entered warehouse.'
Check ($camp.Revision-eq $before -and $bag.Revision-eq $bagBefore) 'Rejected transfer changed revisions.'
Check ($camp.DepositAt('s81',5,3,$true,80,$camp.Revision,$bag.Revision,'material',$bag)-eq '') 'Save fixture deposit failed.'
$capture=$camp.GetType().GetMethod('Capture',$flags)
$save=$capture.Invoke($camp,@())
$prepare=$camp.GetType().GetMethod('Prepare',[Reflection.BindingFlags]'Static,NonPublic')
$restored=$prepare.Invoke($null,[object[]]@($save));$restored.EnsureWarehouse($bag.Grid)
$key=$restored.GetStorageAt(0).Key;$place=$restored.Warehouse.Find($key)
Check ($place.X-eq 5 -and $place.Y-eq 3 -and $place.Rotated -and $restored.Stored(81)-eq 19) 'Warehouse save roundtrip lost placement or count.'
$save.GetType().GetField('gridVersion').SetValue($save,0)
$legacy=$prepare.Invoke($null,[object[]]@($save));$legacy.EnsureWarehouse($bag.Grid)
Check ($legacy.Stored(81)-eq 19 -and $legacy.Warehouse.Count-eq 1 -and $legacy.Warehouse.GetAt(0).X-eq 0) 'Legacy quantities were not deterministically placed.'
$save.GetType().GetField('gridVersion').SetValue($save,1)
$savedRows=$save.GetType().GetField('storage').GetValue($save)
$savedRows[0].GetType().GetField('x').SetValue($savedRows[0],99)
$invalid=$prepare.Invoke($null,[object[]]@($save));$rejected=$false
try{$invalid.EnsureWarehouse($bag.Grid)}catch{$rejected=$true}
Check $rejected 'Corrupt saved placement was silently accepted.'
Write-Host 'PASS exact source piles, independent storage, explicit merge, illegal drops, rotation, capacity, stale versions, whitelist, save roundtrip and legacy placement'

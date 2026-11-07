param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
function Check([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
$bag=[ProjectY.Data.EquipmentData]::new();$bag.Grid.Configure(12,10)
foreach($id in @(40,51,21,31,12)){$bag.Grid.Define($id,2,2)}
$bag.Grid.Define(40,1,3)
foreach($id in @(40,51)){[ProjectY.Data.EquipmentAffixData]::Define($bag,$id,[int[]]@(3),[int[]]@(1))}
$weapon=$bag.AddWeapon(40);$armor=$bag.AddWearable(51);$magazine=$bag.AddMagazine(21,31,8,5);$loose=$bag.AddMagazine(21,31,8,3)
$bag.AddStack(12,1);Check ($bag.SetRune($weapon.Id,2,12)) 'Attachment fixture failed.'
Check ($bag.AttachMagazine($weapon.Id,$magazine.Id)) 'Loaded-magazine fixture failed.'
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$condition=[ProjectY.Data.EquipmentConditionData]::Of($weapon);$condition.GetType().GetMethod('Damage',$flags).Invoke($condition,[object[]]@(61)) | Out-Null
$armorCondition=[ProjectY.Data.EquipmentConditionData]::Of($armor);$armorCondition.GetType().GetMethod('Damage',$flags).Invoke($armorCondition,[object[]]@(23)) | Out-Null
$legacy=[ProjectY.Data.EquipmentLegacyData]::Of($weapon);$legacy.GetType().GetMethod('MarkForged',$flags).Invoke($legacy,@()) | Out-Null
Check ($legacy.RecordDeed(1,1,7,1,60)) 'Deed fixture failed.'
Check ($legacy.ChoosePath(1,1) -and $legacy.Awaken() -and $legacy.AcceptWish()) 'Spirit fixture failed.'
$camp=[ProjectY.Data.CampData]::new();$camp.Open();$weaponKey='w'+$weapon.Id;$armorKey='g'+$armor.Id;$magazineKey='m'+$loose.Id
Check ($camp.DepositAt($weaponKey,0,0,$false,80,$camp.Revision,$bag.Revision,'weapon',$bag)-eq '') 'Weapon deposit failed.'
Check ($camp.DepositAt($armorKey,3,0,$false,80,$camp.Revision,$bag.Revision,'wearable',$bag)-eq '') 'Armor deposit failed.'
Check ($camp.DepositAt($magazineKey,6,0,$false,80,$camp.Revision,$bag.Revision,'magazine',$bag)-eq '') 'Loose magazine deposit failed.'
Check ($camp.StoredTotal-eq 3 -and $camp.StorageCount-eq 3 -and $null-eq $bag.Grid.Find($weaponKey)) 'Stored equipment location/count is wrong.'
Check ([object]::ReferenceEquals($weapon,$bag.GetWeapon($weapon.Id)) -and [object]::ReferenceEquals($magazine,$bag.GetMagazine($magazine.Id))) 'Storage replaced a physical instance.'
Check (-not $bag.CanEquip(1,$weapon.Id) -and -not $bag.CanWear(1,'body',$armor.Id)) 'Stored equipment can be equipped remotely.'
Check (-not $bag.CanAttachMagazine($weapon.Id,$loose.Id) -and -not $bag.SetRune($weapon.Id,2,0)) 'Stored equipment can be modified remotely.'
$before=$camp.Revision;$bagBefore=$bag.Revision
Check ($camp.WithdrawAt($weaponKey,11,9,$false,$before,$bagBefore,'weapon',$bag)-eq 'CampWithdrawBackpackFull') 'Invalid withdrawal succeeded.'
Check ($camp.Revision-eq $before -and $bag.Revision-eq $bagBefore -and $camp.StorageCount-eq 3) 'Rejected withdrawal changed state.'
Check ($camp.MoveStored($armorKey,0,0,$false,$camp.Revision)-eq 'CampWarehousePlacementInvalid') 'Equipment merged with another instance.'
$capture=$bag.GetType().GetMethod('CaptureSave',$flags);$actors=[Collections.Generic.HashSet[int]]::new();$captureArgs=[object[]]::new(1);$captureArgs[0]=$actors;$savedBag=$capture.Invoke($bag,$captureArgs)
$campSave=$camp.GetType().GetMethod('Capture',$flags).Invoke($camp,@())
$preparedCamp=$camp.GetType().GetMethod('Prepare',[Reflection.BindingFlags]'Static,NonPublic').Invoke($null,[object[]]@($campSave));$preparedCamp.EnsureWarehouse($bag.Grid)
$reserved=$preparedCamp.GetType().GetProperty('StoredEquipmentItems',$flags).GetValue($preparedCamp)
$preparedBag=$bag.GetType().GetMethod('PrepareWarehouseSave',$flags).Invoke($bag,[object[]]@($savedBag,$actors,$reserved))
$preparedCamp.GetType().GetMethod('ValidateEquipment',$flags).Invoke($preparedCamp,[object[]]@($preparedBag))
$bag.GetType().GetMethod('TakePrepared',$flags).Invoke($bag,[object[]]@($preparedBag))
$camp.GetType().GetMethod('TakePrepared',$flags).Invoke($camp,[object[]]@($preparedCamp))
$preparedBag=$bag;$preparedCamp=$camp
$preparedCamp.GetType().GetMethod('ValidateEquipment',$flags).Invoke($preparedCamp,[object[]]@($preparedBag))
$restored=$preparedBag.GetWeapon($weapon.Id);$restoredLegacy=[ProjectY.Data.EquipmentLegacyData]::Of($restored)
Check ([ProjectY.Data.EquipmentConditionData]::Of($restored).Current-eq 39 -and [ProjectY.Data.EquipmentConditionData]::Of($restored).Maximum-eq 95) 'Weapon condition lost in save.'
Check ([ProjectY.Data.EquipmentAffixData]::Of($restored)-eq 3 -and $restored.GetRune(2)-eq 12 -and $restored.MagazineId-eq $magazine.Id) 'Affix/attachment/magazine identity lost.'
Check ($preparedBag.GetMagazine($magazine.Id).Rounds-eq 5 -and $preparedBag.GetMagazine($loose.Id).Rounds-eq 3) 'Ammo count lost.'
Check ($restoredLegacy.Forged -and $restoredLegacy.PathId-eq 1 -and $restoredLegacy.Awakened -and $restoredLegacy.WishState-eq 1 -and $restoredLegacy.DeedCount-eq 1) 'Equipment growth or spirit was reset.'
Check ([ProjectY.Data.EquipmentConditionData]::Of($preparedBag.GetWearable($armor.Id)).Current-eq 77) 'Armor condition was reset.'
$preparedCamp.Open()
Check ($preparedCamp.WithdrawAt($weaponKey,7,5,$true,$preparedCamp.Revision,$preparedBag.Revision,'weapon',$preparedBag)-eq '') 'Saved weapon withdrawal failed.'
Check ($preparedBag.Grid.Find($weaponKey).X-eq 7 -and $preparedBag.Grid.Find($weaponKey).Y-eq 5 -and $preparedBag.Grid.Find($weaponKey).Rotated -and $preparedBag.Grid.Find($weaponKey).Width-eq 3 -and $preparedBag.Grid.Find($weaponKey).Height-eq 1) 'Requested equipment drop position or rotated shape lost.'
Check ([object]::ReferenceEquals($restored,$preparedBag.GetWeapon($weapon.Id))) 'Withdrawal regenerated the weapon.'
# A stored reference cannot also own a backpack placement in the same save.
$savedAfter=$capture.Invoke($preparedBag,$captureArgs);$rejected=$false
try{$bag.GetType().GetMethod('PrepareWarehouseSave',$flags).Invoke($bag,[object[]]@($savedAfter,$actors,$reserved))|Out-Null}catch{$rejected=$true}
Check $rejected 'Duplicate backpack/warehouse ownership was accepted.'
$other=$preparedBag.AddWeapon(40);$otherKey='w'+$other.Id
Check ($preparedCamp.DepositAt($weaponKey,0,0,$false,80,$preparedCamp.Revision,$preparedBag.Revision,'weapon',$preparedBag)-eq '') 'First identical-template deposit failed.'
Check ($preparedCamp.DepositAt($otherKey,3,3,$false,80,$preparedCamp.Revision,$preparedBag.Revision,'weapon',$preparedBag)-eq '') 'Second identical-template deposit failed.'
$before=$preparedCamp.Revision
Check ($preparedCamp.MoveStored($otherKey,0,0,$false,$before)-eq 'CampWarehousePlacementInvalid') 'Identical equipment instances merged.'
Check ($preparedCamp.Revision-eq $before -and $null-ne $preparedCamp.Warehouse.Find($weaponKey) -and $null-ne $preparedCamp.Warehouse.Find($otherKey)) 'Rejected identical-equipment merge lost an instance.'
Write-Host 'PASS weapons, armor, magazines, exact identity, durability, affixes, attachments, loaded ammunition, growth, spirit, rejected drops and saved ownership'

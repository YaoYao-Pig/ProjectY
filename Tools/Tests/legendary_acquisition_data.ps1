param([Parameter(Mandatory = $true)][string]$AssemblyPath)

# Managed Data only. Consume an already compiled assembly; never compile, open Unity or touch user saves.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$assembly = [Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
$instanceFlags = [Reflection.BindingFlags]'Instance,NonPublic'
$staticFlags = [Reflection.BindingFlags]'Static,NonPublic'
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

$data = [ProjectY.Data.EquipmentData]::new()
$data.Grid.Configure(12, 10)
$data.Grid.Define(40, 2, 3)
$data.Grid.Define(9002, 2, 4)
[ProjectY.Data.EquipmentAffixData]::Define($data, 40, [int[]]@(1, 6), [int[]]@(10, 1))
[ProjectY.Data.EquipmentAffixData]::Define($data, 9002, [int[]]@(1), [int[]]@(1))
$area = [ProjectY.Data.MapAreaStateData]::new(7, 30, 1)
$story = [ProjectY.Data.NarrativeData]::new()
$session = [ProjectY.Data.LootSessionData]::new()
$area.AddLoot(2, 10, 'Existing test chest', [int[]]@(40), [int[]]@(1), $false)
[ProjectY.Data.ContainerState]::Initialize($area, 1, 30, $false, 0, 0, [int[]]@(2))
$old = $area.GetLootAt(0)
$session.Prepare($old, [string[]]@('weapon'), [int[]]@(2), [int[]]@(3))
[ProjectY.Data.EquipmentAffixData]::PrepareLoot($data, $old)
$oldWeapon = [ProjectY.Data.EquipmentCombatState]::GroundWeapon($old)
$area.CompleteLootInitialization()

[ProjectY.Data.LegendaryAcquisitionState]::AppendContainer($area, $story, 3, 9102, 9002, 'New named chest', 60, $false, 0, 0, [int[]]@(3))
Assert-True ($area.LootCount -eq 2 -and [object]::ReferenceEquals($old, $area.GetLootAt(0))) 'Appending changed existing container identity.'
Assert-True ([object]::ReferenceEquals($oldWeapon, [ProjectY.Data.EquipmentCombatState]::GroundWeapon($old))) 'Appending regenerated existing contents.'
$added = $area.GetLootAt(1)
$session.Prepare($added, [string[]]@('weapon'), [int[]]@(2), [int[]]@(4))
[ProjectY.Data.EquipmentAffixData]::PrepareLoot($data, $added)
$weapon = [ProjectY.Data.EquipmentCombatState]::GroundWeapon($added)
Assert-True ($weapon.ItemId -eq 9002 -and [ProjectY.Data.EquipmentAffixData]::Of($weapon) -eq 1) 'Named physical loot did not use fixed quality.'
$story.SetValue('flag:legendary_equipment_issued_9002', 1)
$story.SetValue('flag:legendary_equipment_site_9002', 7)
[ProjectY.Data.EquipmentAffixData]::PrepareLoot($data, $added)
Assert-True ([object]::ReferenceEquals($weapon, [ProjectY.Data.EquipmentCombatState]::GroundWeapon($added))) 'Repeated preparation copied the unique instance.'
Write-Host 'PASS existing initialized area appends one real container and preserves old/new physical identities'

$rejected = $false
try { [ProjectY.Data.LegendaryAcquisitionState]::AppendContainer($area, $story, 4, 9102, 9002, 'Duplicate', 60, $false, 0, 0, [int[]]@(4)) } catch { $rejected = $true }
Assert-True ($rejected -and $area.LootCount -eq 2) 'Issued identity was appended again.'
$emptyStory = [ProjectY.Data.NarrativeData]::new()
$rejected = $false
try { [ProjectY.Data.LegendaryAcquisitionState]::AppendContainer($area, $emptyStory, 4, 9102, 9002, 'Duplicate source', 60, $false, 0, 0, [int[]]@(4)) } catch { $rejected = $true }
Assert-True ($rejected -and $area.LootCount -eq 2) 'Existing source table was appended twice.'
$rejected = $false
try { [ProjectY.Data.LegendaryAcquisitionState]::AppendContainer($area, $emptyStory, 3, 9109, 9009, 'Overlap', 60, $false, 0, 0, [int[]]@(3)) } catch { $rejected = $true }
Assert-True ($rejected -and $area.LootCount -eq 2) 'Overlapping migration changed the area.'
Write-Host 'PASS issued/source/footprint rejection does not mutate existing loot'

$session.Open($area, [int[]]@($added.Id), $false, 'Named equipment test', '')
$entry = $session.GetAt(0)
[void]$session.Advance($entry.Key, 2, 1)
Assert-True (-not $session.Take($data, $entry.Key, 100, 100, $false, 0, 0, 0)) 'Invalid pickup unexpectedly succeeded.'
Assert-True ($entry.Count -eq 1 -and [ProjectY.Data.EquipmentAffixData]::Of($entry) -eq 1) 'Failed pickup changed unique loot.'
Assert-True ($session.Take($data, $entry.Key, 0, 0, $false, 0, 0, 0)) 'Valid pickup failed.'
Assert-True ([object]::ReferenceEquals($weapon, $data.GetWeapon($weapon.Id))) 'Pickup replaced the original physical weapon.'
Assert-True ($session.Put($data, ('w' + $weapon.Id), 0, 0, $false)) 'Deposit failed.'
$returned = $session.GetAt($session.Count - 1)
Assert-True ($session.Take($data, $returned.Key, 0, 0, $false, 0, 0, 0)) 'Retaking deposited weapon failed.'
Assert-True ([object]::ReferenceEquals($weapon, $data.GetWeapon($weapon.Id)) -and [ProjectY.Data.EquipmentAffixData]::Of($weapon) -eq 1) 'Roundtrip changed named identity/quality.'
Write-Host 'PASS failed pickup and two-way container transfers preserve the same named instance'

$savedFacts = $story.GetType().GetMethod('Capture', $instanceFlags).Invoke($story, [object[]]@())
$restoreArgs = [object[]]::new(1)
$restoreArgs[0] = $savedFacts
$restoredFacts = $story.GetType().GetMethod('Prepare', $staticFlags).Invoke($null, $restoreArgs)
Assert-True ($restoredFacts.GetValue('flag:legendary_equipment_issued_9002') -eq 1 -and $restoredFacts.GetValue('flag:legendary_equipment_site_9002') -eq 7) 'Existing Narrative save roundtrip lost unique ownership.'
$owners = [Collections.Generic.HashSet[int]]::new()
$captureArgs = [object[]]::new(1)
$captureArgs[0] = $owners
$savedEquipment = $data.GetType().GetMethod('CaptureSave', $instanceFlags).Invoke($data, $captureArgs)
$prepareArgs = [object[]]::new(2)
$prepareArgs[0] = $savedEquipment
$prepareArgs[1] = $owners
$restoredEquipment = $data.GetType().GetMethod('PrepareSave', $instanceFlags).Invoke($data, $prepareArgs)
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($restoredEquipment.GetWeapon($weapon.Id)) -eq 1) 'Existing equipment save roundtrip lost fixed quality.'
Write-Host 'PASS existing narrative and equipment serialization preserve issued site and fixed identity quality'

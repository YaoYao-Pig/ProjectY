param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path) | Out-Null
function Check([bool]$value,[string]$message){if(-not $value){throw $message}}
$adventure=[ProjectY.Data.AdventureData]::new()
$owner=$adventure.AddPartyActor(1,1)
$owner.Deploy(1,0,0)
$animal=[ProjectY.Data.CombatActorData]::new(101,101)
$animal.InitializeAnimal(1,17)
$owner.TameAndRide($animal,25)
$camp=[ProjectY.Data.CampData]::For($adventure)
$loadout=[ProjectY.Data.CampLoadoutData]::For($camp)
$bag=$adventure.Equipment
$bag.Grid.Configure(1,1)
$bag.Grid.Define(94,1,1)
$bag.Grid.Define(81,1,1)
$camp.Open()
$revision=$camp.Revision
Check ([ProjectY.Data.CampLoadoutData]::EquipAnimal($camp,$adventure,1,1,101,$revision)-eq '') 'Mount equip failed'
Check ([object]::ReferenceEquals($owner.MountedAnimal,$animal) -and $animal.AnimalBond-eq 25) 'Animal identity or bond changed'
Check ([ProjectY.Data.CampLoadoutData]::EquipAnimal($camp,$adventure,2,1,101,$camp.Revision)-eq 'CampLoadoutAnimalBusy') 'Animal occupied both slots'
Check ([ProjectY.Data.CampLoadoutData]::EquipAnimal($camp,$adventure,1,0,0,$revision)-eq 'UICampText5') 'Stale click accepted'
Check ([ProjectY.Data.CampLoadoutData]::EquipAnimal($camp,$adventure,2,1,102,$camp.Revision)-eq 'CampLoadoutAnimalMissing') 'Foreign animal accepted'
$bag.AddStack(94,1)
Check ([ProjectY.Data.CampLoadoutData]::EquipTorch($camp,$bag,94,$true,$camp.Revision)-eq '') 'Torch equip failed'
Check ($bag.CountItem(94)-eq 0 -and $loadout.TorchItemId-eq 94 -and $bag.Grid.Count-eq 0) 'Torch was copied instead of transferred'
$bag.AddStack(81,1)
$revision=$camp.Revision
Check ([ProjectY.Data.CampLoadoutData]::EquipTorch($camp,$bag,94,$false,$revision)-eq 'UICampText31') 'Full backpack accepted unequip'
Check ($loadout.TorchItemId-eq 94 -and $bag.CountItem(94)-eq 0 -and $camp.Revision-eq $revision) 'Failed unequip lost the torch or mutated revision'
$bag.ConsumeStack(81,1)
Check ([ProjectY.Data.CampLoadoutData]::EquipTorch($camp,$bag,94,$false,$revision)-eq '') 'Torch unequip failed'
Check ($bag.CountItem(94)-eq 1 -and $loadout.TorchItemId-eq 0) 'Unequip duplicated the torch'
Check ($camp.Deposit(94,1,80,$camp.Revision,$bag)-eq '') 'Warehouse fixture failed'
Check ([ProjectY.Data.CampLoadoutData]::EquipTorch($camp,$bag,94,$true,$camp.Revision)-eq '') 'Warehouse torch equip failed'
Check ($camp.Stored(94)-eq 0 -and $bag.CountItem(94)-eq 0 -and $loadout.TorchItemId-eq 94) 'Warehouse equip did not transfer one torch'
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$saved=$camp.GetType().GetMethod('Capture',$flags).Invoke($camp,@())
$prepare=$camp.GetType().GetMethod('Prepare',[Reflection.BindingFlags]'Static,NonPublic')
$restored=$prepare.Invoke($null,[object[]]@($saved))
$restoredLoadout=[ProjectY.Data.CampLoadoutData]::For($restored)
Check ($restoredLoadout.MountAnimalId-eq 101 -and $restoredLoadout.TorchItemId-eq 94) 'Camp save roundtrip lost equipment'
$restoredLoadout.GetType().GetMethod('ValidateAnimals',$flags).Invoke($restoredLoadout,[object[]]@(,[ProjectY.Data.CombatActorData[]]@($owner))) | Out-Null
$saved.loadout.petOwner=1
$saved.loadout.petAnimal=101
$rejected=$false
try{$prepare.Invoke($null,[object[]]@($saved))|Out-Null}catch{$rejected=$true}
Check $rejected 'Save with duplicate animal slots was accepted'
$saved.loadout=$null
$legacy=$prepare.Invoke($null,[object[]]@($saved))
Check ([ProjectY.Data.CampLoadoutData]::For($legacy).TorchItemId-eq 0) 'Legacy camp did not migrate to empty slots'
$animal.Damage($animal.HP) | Out-Null
[ProjectY.Data.CampLoadoutData]::Reconcile($adventure)
Check ($loadout.MountAnimalId-eq 0) 'Dead animal retained camp equipment bonus'
$travel=[ProjectY.Data.WorldTravelData]::new()
$travel.Reset(17,0,0,1)
$travel.Plan([int[]]@(1,2),[int[]]@(0,0),[double[]]@(10,10),0)
$spent=[ProjectY.Data.WorldTravelProgress]::Step($travel,4,1.25)
Check ([math]::Abs($spent-4)-lt 0.00001 -and [math]::Abs($travel.Progress-0.5)-lt 0.00001) 'Mounted travel did not advance 25 percent faster'
$spent=[ProjectY.Data.WorldTravelProgress]::Step($travel,10,1.25)
Check ([math]::Abs($spent-4)-lt 0.00001 -and $travel.Q-eq 1 -and $travel.Progress-eq 0) 'Mounted arrival used the wrong game time'
Check (-not $travel.CheckDue(9)) 'Encounter clock was accelerated with movement'
$spent=[ProjectY.Data.WorldTravelProgress]::Step($travel,5,1)
Check ($spent-eq 5 -and [math]::Abs($travel.Progress-0.5)-lt 0.00001) 'Unequipping changed route progress or baseline duration'
$camp.Clear()
Check ($loadout.TorchItemId-eq 0 -and $loadout.PetAnimalId-eq 0 -and $loadout.MountAnimalId-eq 0) 'New campaign retained loadout'
Write-Host 'PASS camp loadout: identity, duplicate/stale rejection, torch conservation/full bag, warehouse, save migration/corruption, death, travel time and reset'

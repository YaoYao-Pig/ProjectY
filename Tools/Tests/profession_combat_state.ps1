param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$actor=[ProjectY.Data.CombatActorData]::new(1,1)
$actor.SetMaxHP(100)
$actor.Restore()
$actor.Deploy(1,0,0)
$actor.BeginTurn(5)
Assert-True ([ProjectY.Data.ProfessionCombatState]::Once($actor,'reply',1)) 'First round stamp was rejected.'
Assert-True (-not [ProjectY.Data.ProfessionCombatState]::Once($actor,'reply',1)) 'Round stamp was repeatable.'
Assert-True ([ProjectY.Data.ProfessionCombatState]::Once($actor,'reply',2)) 'New round could not trigger.'
[ProjectY.Data.ProfessionCombatState]::Move($actor,1,0)
Assert-True ($actor.Q-eq 1 -and $actor.R-eq 0 -and $actor.Moved -and $actor.AP-eq 5) 'Skill relocation incorrectly charged or reopened ordinary movement.'
$actor.Deploy(1,0,0)
Assert-True ([ProjectY.Data.ProfessionCombatState]::Mark($actor,'reply')-eq 0) 'Encounter counters leaked through deployment.'
Write-Host 'PASS actor-owned round/encounter counters and skill relocation'

$source=[ProjectY.Data.GameEffectCollectionData]::new()
$target=[ProjectY.Data.GameEffectCollectionData]::new()
$status=$source.Add(12013,1,'source',0,2)
[ProjectY.Data.GameBuffState]::Configure($status,[int[]]@(20042),[int[]]@(-2),0,0)
$source.Refresh($status.Id,1,'source',0,2,3,$true)
$source.Advance($status.Id,2)
$existing=$target.Add(12013,2,'other',0,3)
[ProjectY.Data.GameBuffState]::Configure($existing,[int[]]@(20042),[int[]]@(-1),0,0)
$moved=[ProjectY.Data.ProfessionCombatState]::Transfer($source,$target,$status.Id,3)
Assert-True ($source.Count-eq 0 -and $target.Count-eq 1 -and $moved.Stacks-eq 3 -and $moved.Remaining-eq 1 -and $moved.Elapsed-eq 1) 'Transfer duplicated or refreshed the source lifetime.'
Assert-True ([ProjectY.Data.GameBuffState]::Amount($moved,20042)-eq -2) 'Transfer lost the captured component magnitude.'
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$captured=$target.GetType().GetMethod('Capture',$flags).Invoke($target,$null)
$restored=[ProjectY.Data.GameEffectCollectionData]::new()
$invokeArguments=[object[]]::new(1);$invokeArguments[0]=$captured
$restored.GetType().GetMethod('Restore',$flags).Invoke($restored,$invokeArguments)
Assert-True ($restored.Find(12013).Remaining-eq 1 -and $restored.Find(12013).Elapsed-eq 1 -and $restored.Find(12013).Stacks-eq 3) 'Transferred effect did not survive its ordinary save round trip.'
Write-Host 'PASS exact transfer snapshot, capped target stacking and effect save round trip'

$battle=[ProjectY.Data.BattleData]::new()
$battle.Reset(1,10)
[ProjectY.Data.ProfessionCombatState]::AddUnit($battle,$actor,1,0,0)
[ProjectY.Data.ProfessionCombatState]::PlaceTrap($battle,1,0,1,20016)
Assert-True ([ProjectY.Data.ProfessionCombatState]::TrapCount($battle)-eq 1) 'Trap was not stored on battle data.'
$rejected=$false
try{[ProjectY.Data.ProfessionCombatState]::PlaceTrap($battle,1,0,1,20016)}catch{$rejected=$true}
Assert-True ($rejected -and [ProjectY.Data.ProfessionCombatState]::TrapCount($battle)-eq 1) 'Duplicate trap placement mutated state.'
[ProjectY.Data.ProfessionCombatState]::RemoveTrap($battle,1,0)
Assert-True ([ProjectY.Data.ProfessionCombatState]::TrapCount($battle)-eq 0) 'Trap did not disappear after one trigger.'
[ProjectY.Data.ProfessionCombatState]::PlaceTrap($battle,2,0,1,20016)
$battle.Clear()
Assert-True ([ProjectY.Data.ProfessionCombatState]::TrapCount($battle)-eq 0) 'Trap state leaked into the next encounter.'
Write-Host 'PASS battle-owned traps, duplicate rejection, one-use consumption and encounter cleanup'

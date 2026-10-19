param([Parameter(Mandatory=$true)][string]$AssemblyPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$effects=[ProjectY.Data.GameEffectCollectionData]::new()
$legacy=$effects.Add(401,1,'caster',2,3)
$buff=$effects.Add(10007,1,'caster',0,-1)
$ids=[int[]]@(901);$amounts=[int[]]@(4)
[ProjectY.Data.GameBuffState]::Configure($buff,$ids,$amounts,600,550)
$ids[0]=999;$amounts[0]=99
Assert-True ([ProjectY.Data.GameBuffState]::Amount($buff,901)-eq 4 -and [ProjectY.Data.GameBuffState]::Count($buff)-eq 1) 'Caller arrays leaked into owned buff state.'
Assert-True ([ProjectY.Data.GameBuffState]::Count($legacy)-eq 0 -and [ProjectY.Data.GameBuffState]::ExpiresAt($legacy)-eq 0) 'Legacy effects did not keep empty snapshots.'
[ProjectY.Data.GameBuffState]::AdvanceTick($buff,10)
Assert-True ([ProjectY.Data.GameBuffState]::NextTickAt($buff)-eq 560) 'Game-minute timer did not advance.'
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$payload=[object[]]::new(1);$payload[0]=$effects.GetType().GetMethod('Capture',$flags).Invoke($effects,$null)
$restored=[ProjectY.Data.GameEffectCollectionData]::new()
$restored.GetType().GetMethod('Restore',$flags).Invoke($restored,$payload)
$copy=$restored.Find(10007)
Assert-True ($restored.Count-eq 2 -and [ProjectY.Data.GameBuffState]::Amount($copy,901)-eq 4 -and [ProjectY.Data.GameBuffState]::ExpiresAt($copy)-eq 600 -and [ProjectY.Data.GameBuffState]::NextTickAt($copy)-eq 560) 'Composite snapshot/timer save roundtrip failed.'
Assert-True ($restored.Find(401).Amount-eq 2 -and $restored.Find(401).Remaining-eq 3) 'Legacy effect fields changed during roundtrip.'
Write-Host 'PASS owned component snapshots, legacy compatibility and game-minute save roundtrip'

$rejected=$false
try{[ProjectY.Data.GameBuffState]::Configure($buff,[int[]]@(901,901),[int[]]@(4,5),600,550)}catch{$rejected=$true}
Assert-True ($rejected -and [ProjectY.Data.GameBuffState]::Amount($buff,901)-eq 4 -and [ProjectY.Data.GameBuffState]::NextTickAt($buff)-eq 560) 'Duplicate component rejection changed live state.'
$rejected=$false
try{[ProjectY.Data.GameBuffState]::AdvanceTick($buff,0)}catch{$rejected=$true}
Assert-True ($rejected -and [ProjectY.Data.GameBuffState]::NextTickAt($buff)-eq 560) 'Invalid period changed live timer.'
$payload[0].GetValue(1).snapshotIds=$null
$invalid=[ProjectY.Data.GameEffectCollectionData]::new();$rejected=$false
try{$invalid.GetType().GetMethod('Restore',$flags).Invoke($invalid,$payload)}catch{$rejected=$true}
Assert-True ($rejected -and $effects.Count-eq 2 -and [ProjectY.Data.GameBuffState]::Amount($buff,901)-eq 4) 'Malformed snapshot was accepted or mutated the current actor.'
Write-Host 'PASS duplicate/missing component and invalid timer rejection preserves the original state'

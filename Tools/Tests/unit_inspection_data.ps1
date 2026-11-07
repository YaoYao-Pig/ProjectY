param([Parameter(Mandatory = $true)][string]$AssemblyPath)

# Managed Data only. Uses an existing compiled assembly; never compiles, opens Unity or reads player saves.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[void][Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
$instanceFlags = [Reflection.BindingFlags]'Instance,NonPublic'
$staticFlags = [Reflection.BindingFlags]'Static,NonPublic'
$dataType = [ProjectY.Data.UnitInspectionData]
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Capture($Data) { return $dataType.GetMethod('Capture', $instanceFlags).Invoke($Data, [object[]]@()) }
function Prepare($Saved) {
    $arguments = [object[]]::new(1); $arguments[0] = $Saved
    return $dataType.GetMethod('Prepare', $staticFlags).Invoke($null, $arguments)
}
function Reject-Prepare($Saved, [string]$Message) {
    $rejected = $false
    try { [void](Prepare $Saved) } catch { $rejected = $true }
    Assert-True $rejected $Message
}

$adventure = [ProjectY.Data.AdventureData]::new()
$data = [ProjectY.Data.UnitInspections]::Get($adventure)
Assert-True ([object]::ReferenceEquals($data, [ProjectY.Data.UnitInspections]::Get($adventure))) 'Reflection bridge changed campaign state identity.'
$data.Clear(3127)
Assert-True ($null -eq $data.Find('actor:25') -and $data.Count -eq 0) 'Fresh campaign starts with knowledge.'
$fields = [string[]]@('health', 'actionPoints', 'guard', 'casting', 'attribute:scouting', 'trait:101')
$record = $data.Record('actor:25', 1, 18, 7, 13, $fields)
$fields[0] = 'trait:999'
Assert-True ($record.HasField('health') -and -not $record.HasField('trait:999') -and $record.FieldCount -eq 6) 'Caller mutated committed knowledge.'
Assert-True ($record.Key -eq 'actor:25' -and $record.ObserverId -eq 1 -and $record.ObserverRoll -eq 18 -and $record.TargetRoll -eq 7 -and $record.Margin -eq 13) 'Recorded check metadata changed.'
$revision = $data.Revision
$rejected = $false
try { [void]$data.Record('actor:25', 2, 20, 1, 99, [string[]]@('trait:999')) } catch { $rejected = $true }
Assert-True ($rejected -and $data.Count -eq 1 -and $data.Revision -eq $revision -and [object]::ReferenceEquals($record, $data.Find('actor:25'))) 'Retry replaced or modified the first check.'
[void]$data.Record('npc:8:100001', 1, 1, 20, -25, [string[]]@())
Assert-True ($data.Find('npc:8:100001').FieldCount -eq 0 -and $data.Find('npc:8:100001').Margin -eq -25) 'Failed observation was not retained.'
Write-Host 'PASS campaign ownership, immutable revealed fields, one attempt and retained failure'

$saved = Capture $data
$restored = Prepare $saved
Assert-True ($restored.Count -eq 2 -and $restored.Find('actor:25').HasField('attribute:scouting') -and $restored.Find('npc:8:100001').FieldCount -eq 0) 'Save preparation lost inspection knowledge.'
$saved.records[0].fields[0] = 'trait:888'
Assert-True ($record.HasField('health') -and $restored.Find('actor:25').HasField('health')) 'Save DTO mutated live or prepared state.'
for ($i = 0; $i -lt 100; $i++) {
    $expected = $data.Roll(20); $actual = $restored.Roll(20)
    Assert-True ($expected -eq $actual -and $actual -ge 1 -and $actual -le 20) 'Save roundtrip changed the separate d20 stream.'
}
$other = [ProjectY.Data.UnitInspectionData]::new(); $other.Clear(3127)
$same = [ProjectY.Data.UnitInspectionData]::new(); $same.Clear(3127)
for ($i = 0; $i -lt 30; $i++) { Assert-True ($other.Roll(20) -eq $same.Roll(20)) 'Same world seed produced different inspection rolls.' }
$revision = $other.Revision; $rejected = $false
try { [void]$other.Roll(0) } catch { $rejected = $true }
Assert-True ($rejected -and $other.Revision -eq $revision) 'Invalid dice mutated the random stream.'
Assert-True ($other.Roll(20) -eq $same.Roll(20)) 'Rejected dice consumed randomness.'
Write-Host 'PASS independent deterministic random stream, full state roundtrip and invalid-roll atomicity'

Reject-Prepare $null 'Missing inspection record was accepted.'
$bad = Capture $data; $bad.format = 3; Reject-Prepare $bad 'Unknown inspection save format was accepted.'
$bad = Capture $data; $bad.random = 0; Reject-Prepare $bad 'Zero random state was accepted.'
$bad = Capture $data; $bad.records = $null; Reject-Prepare $bad 'Missing result array was accepted.'
$bad = Capture $data; $bad.records[1].key = $bad.records[0].key; Reject-Prepare $bad 'Duplicate target key was accepted.'
$bad = Capture $data; $bad.records[0].fields = [string[]]@('health', 'health'); Reject-Prepare $bad 'Duplicate revealed field was accepted.'
$bad = Capture $data; $bad.records[0].fields = [string[]]@('trait:01'); Reject-Prepare $bad 'Noncanonical trait identity was accepted.'
$bad = Capture $data; $bad.records[0].fields = [string[]]@('attribute:'); Reject-Prepare $bad 'Empty attribute identity was accepted.'
$bad = Capture $data; $bad.records[0].observerId = 0; Reject-Prepare $bad 'Missing observer identity was accepted.'
$bad = Capture $data; $bad.records[0].observerRoll = 0; Reject-Prepare $bad 'Zero d20 result was accepted.'
Assert-True ($data.Count -eq 2 -and $data.Find('actor:25').HasField('health')) 'Rejected preparation changed live knowledge.'
Write-Host 'PASS malformed saves are rejected without changing current state'

$next = Prepare (Capture $data)
$expected = $data.Roll(20)
$arguments = [object[]]::new(1); $arguments[0] = $next
[void]$dataType.GetMethod('TakePrepared', $instanceFlags).Invoke($other, $arguments)
Assert-True ($other.Count -eq 2 -and $other.Find('actor:25').HasField('health') -and $other.Roll(20) -eq $expected -and $next.Count -eq 0) 'Prepared commit did not replace knowledge and random state together.'
$seedArguments = [object[]]::new(1); $seedArguments[0] = [uint32]3127
$legacy = $dataType.GetMethod('Empty', $staticFlags).Invoke($null, $seedArguments)
$other.Clear(3127)
Assert-True ($legacy.Count -eq 0 -and $other.Count -eq 0 -and $legacy.Roll(20) -eq $other.Roll(20)) 'Legacy migration or new-world reset inherited knowledge or lost seed identity.'
Write-Host 'PASS prepared commit, explicit empty legacy migration and new-world reset'

$passive = [ProjectY.Data.UnitInspectionData]::new(); $passive.Clear(3127)
$met = $passive.Reveal('actor:30', [string[]]@('health', 'actionPoints', 'guard', 'casting'))
Assert-True (-not $met.Observed -and $met.ObserverRoll -eq 0 -and $met.FieldCount -eq 4) 'Encounter consumed an inspection attempt.'
$revision = $passive.Revision
[void]$passive.Reveal('actor:30', [string[]]@('health', 'actionPoints'))
Assert-True ($passive.Revision -eq $revision) 'Repeated encounters changed the revision.'
[void]$passive.Reveal('actor:30', [string[]]@('skill:11'))
$passiveSave = Capture $passive
$passiveRestored = Prepare $passiveSave
Assert-True ($passiveSave.format -eq 2 -and $passiveRestored.Find('actor:30').HasField('skill:11') -and -not $passiveRestored.Find('actor:30').Observed) 'Passive discoveries failed save roundtrip.'
$same.Clear(3127)
Assert-True ($passive.Roll(20) -eq $same.Roll(20)) 'Passive discovery consumed the inspection RNG.'
$observed = $passive.Record('actor:30', 1, 1, 20, -19, [string[]]@())
Assert-True ($observed.Observed -and $observed.HasField('skill:11') -and $observed.FieldCount -eq 5) 'Scouting overwrote passive discoveries.'
[void]$passive.Reveal('actor:30', [string[]]@('skill:12'))
Assert-True ($passive.Find('actor:30').HasField('skill:12') -and $passive.Find('actor:30').Observed -and $passive.Find('actor:30').Margin -eq -19) 'A later skill erased the scouting result.'
Assert-True (-not $met.HasField('skill:11')) 'Revealing a skill mutated a previously returned snapshot.'
$arguments[0] = $passiveRestored
[void]$dataType.GetMethod('TakePrepared', $instanceFlags).Invoke($other, $arguments)
Assert-True ($other.Find('actor:30').HasField('skill:11') -and -not $other.Find('actor:30').Observed -and $passiveRestored.Count -eq 0) 'Prepared commit lost passive discoveries.'
$bad = Capture $passive; $bad.records[0].fields = [string[]]@('skill:01'); Reject-Prepare $bad 'Noncanonical skill ID was accepted.'
$bad = Capture $passive; $bad.records[0].fields = [string[]]@('skill:0'); Reject-Prepare $bad 'Zero skill ID was accepted.'
$bad = $passiveSave; $bad.records[0].fields = [string[]]@('trait:1'); Reject-Prepare $bad 'An unobserved trait was accepted.'
$legacySave = Capture $data; $legacySave.format = 1
$legacyRestored = Prepare $legacySave
Assert-True ($legacyRestored.Find('actor:25').Observed -and $legacyRestored.Find('actor:25').HasField('health')) 'Format 1 scouting records did not migrate.'
$passive.Clear(3127)
Assert-True ($passive.Count -eq 0 -and $null -eq $passive.Find('actor:30')) 'New-world reset retained discoveries.'
Write-Host 'PASS passive discovery, skill identities, scouting merge, old format migration and passive state commit/reset'

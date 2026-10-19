param([Parameter(Mandatory=$true)][string]$AssemblyPath)
# Uses only an already compiled assembly and managed state; no Editor, compilation or user saves.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
[void][Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
function Assert-True([bool]$Condition,[string]$Message) { if(-not $Condition){throw $Message} }
function New-Trip {
    $data=[ProjectY.Data.WorldTravelData]::new();$data.Reset(431,0,0,20)
    $data.Plan([int[]]@(1,2,3),[int[]]@(0,0,0),[double[]]@(10,10,10),7)
    return $data
}
$trip=New-Trip
Assert-True ($trip.Step(4)-eq 4 -and $trip.Q-eq 0 -and $trip.AnchorQ-eq 1 -and [Math]::Abs($trip.Progress-.4)-lt 1e-9) 'Partial travel position is incorrect.'
$trip.SetPaused($true)
Assert-True ($trip.Step(100)-eq 0 -and $trip.RemainingMinutes-eq 26) 'Paused travel consumed game time.'
$trip.SetSpeed(4)
Assert-True ($trip.Speed-eq 4 -and $trip.Paused) 'Changing speed unexpectedly resumed travel.'
$trip.Plan([int[]]@(1,2),[int[]]@(1,1),[double[]]@(8,8),9)
Assert-True ($trip.StepCount-eq 3 -and $trip.RemainingMinutes-eq 22 -and [Math]::Abs($trip.Progress-.4)-lt 1e-9 -and $trip.TargetSiteId-eq 9) 'Rerouting teleported the squad or reset the current edge.'
Assert-True ($trip.Paused -and $trip.Step(1)-eq 0) 'Planning a route resumed the paused world clock.'
$revision=$trip.Revision;$rejected=$false
try {$trip.Plan([int[]]@(99),[int[]]@(99),[double[]]@(1),10)} catch {$rejected=$true}
Assert-True ($rejected -and $trip.Revision-eq $revision -and $trip.TargetSiteId-eq 9 -and $trip.RemainingMinutes-eq 22) 'Invalid reroute changed the active trip.'
$trip.SetPaused($false)
Assert-True ($trip.Step(6)-eq 6 -and $trip.Q-eq 1 -and $trip.R-eq 0 -and $trip.Progress-eq 0) 'Current edge did not finish correctly.'
$stop=$trip.AddStop(0,1)
Assert-True ($stop.Id-eq 20 -and $stop.Q-eq 1 -and $trip.Paused -and $trip.TargetSiteId-eq 9 -and $trip.RemainingMinutes-eq 16) 'Encounter did not preserve the destination and remaining route.'
$trip.SetPaused($false)
while($trip.Active){[void]$trip.Step(100)}
Assert-True ($trip.Q-eq 2 -and $trip.R-eq 1 -and $trip.RemainingMinutes-eq 0) 'Resuming after an encounter missed the destination.'
$trip.Arrived()
Assert-True (-not $trip.Paused -and -not $trip.Active -and $trip.TargetSiteId-eq 0) 'Arrival should stop movement without pausing the world clock.'
Write-Host 'PASS partial position, pause, speed, transactional reroute, encounter interruption and route resumption'

function Run-FrameSequence([double]$Budget) {
    $data=[ProjectY.Data.WorldTravelData]::new();$data.Reset(9321,0,0,100)
    $qs=[int[]](1..40);$rs=[int[]]::new(40);$costs=[double[]]::new(40)
    for($i=0;$i-lt 40;$i++){$costs[$i]=8}
    $data.Plan($qs,$rs,$costs,0)
    $rolls=[Collections.Generic.List[int]]::new();$spent=0.0
    while($data.Active) {
        $left=$Budget
        while($left-gt 0 -and $data.Active) {
            $step=$data.Step($left);$left-=$step;$spent+=$step
            if($data.Active -and $data.Progress-eq 0) {while($data.CheckDue(30)){$rolls.Add($data.Roll(10000))}}
        }
    }
    Assert-True ($spent-eq 320 -and $data.Q-eq 40) 'Frame budget lost travel time or overshot the destination.'
    return ($rolls -join ',')
}
$slow=Run-FrameSequence 3
Assert-True ($slow-eq (Run-FrameSequence 48) -and $slow-eq (Run-FrameSequence 320)) 'Frame rate or acceleration changed the game-time encounter sequence.'
Write-Host 'PASS identical game-time checks and random stream across small, accelerated and one-frame budgets'

$adventure=[ProjectY.Data.AdventureData]::new();$data=[ProjectY.Data.WorldTravelData]::For($adventure)
$data.Reset(15,0,0,30);$data.Plan([int[]]@(1,2),[int[]]@(0,0),[double[]]@(8,8),5)
[void]$data.Step(8);$stop=$data.AddStop(0,204)
[ProjectY.Data.WorldTravelData]::BeginBattle($adventure,$stop.Id)
Assert-True ($adventure.Phase-eq 'resolving' -and $adventure.SiteId-eq 30 -and $adventure.EventId-eq 0 -and $data.TargetSiteId-eq 5 -and $data.Paused) 'Direct encounter did not enter the existing battlefield transition safely.'
Write-Host 'PASS direct encounter transition uses the real adventure state without inventing an event choice'

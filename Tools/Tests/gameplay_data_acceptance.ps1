param(
    [Parameter(Mandatory = $true)][string]$AssemblyPath,
    [string]$OutputPath
)

# Executes only the real, managed Data classes from an already compiled assembly.
# Does not compile, instantiate Unity objects, access user saves, or launch the Editor.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$assemblyFile = (Resolve-Path -LiteralPath $AssemblyPath).Path
$assembly = [Reflection.Assembly]::LoadFrom($assemblyFile)
$checks = [Collections.Generic.List[object]]::new()
$itemRows = (Get-Content -LiteralPath (Join-Path $projectRoot 'Config/Tables/Equipment/EquipmentItemTable.json') -Raw | ConvertFrom-Json).rows
$upgrade = (Get-Content -LiteralPath (Join-Path $projectRoot 'Config/Tables/Camp/CampUpgradeTable.json') -Raw | ConvertFrom-Json).rows | Where-Object id -EQ 101
$recipe = (Get-Content -LiteralPath (Join-Path $projectRoot 'Config/Tables/Camp/CampRecipeTable.json') -Raw | ConvertFrom-Json).rows | Where-Object id -EQ 1

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function New-Inventory([int]$Width, [int]$Height) {
    $inventory = [ProjectY.Data.EquipmentData]::new()
    $inventory.Grid.Configure($Width, $Height)
    foreach ($item in $itemRows) { $inventory.Grid.Define($item.id, $item.width, $item.height) }
    return $inventory
}
function Invoke-Case([string]$Name, [scriptblock]$Body) {
    & $Body
    $checks.Add([ordered]@{ name = $Name; status = 'passed' })
    Write-Host "PASS $Name"
}

$camp = [ProjectY.Data.CampData]::new()
$equipment = New-Inventory 3 1
$player = [ProjectY.Data.PlayerData]::new()
$camp.Open()
foreach ($id in $upgrade.itemIds) { $equipment.AddStack($id, 20) }
$player.AddCoins($upgrade.coins - 1)

try {
    Invoke-Case 'Camp rejected purchases preserve coins, materials, levels and revisions' {
        $revision = $camp.Revision
        $equipmentRevision = $equipment.Revision
        $reason = $camp.Upgrade(1, 0, $revision, $upgrade.coins, [int[]]$upgrade.itemIds, [int[]]$upgrade.itemCounts, $equipment, $player)
        Assert-True ($reason -ne '' -and $player.Coins -eq $upgrade.coins - 1) 'Insufficient coins were not rejected atomically.'
        Assert-True ($camp.GetLevel(1) -eq 0 -and $camp.Revision -eq $revision -and $equipment.Revision -eq $equipmentRevision) 'Rejected upgrade changed state.'
        foreach ($id in $upgrade.itemIds) { Assert-True ($equipment.CountItem($id) -eq 20) 'Rejected upgrade consumed materials.' }

        $player.AddCoins(100)
        $coins = $player.Coins
        $empty = New-Inventory 3 1
        $reason = $camp.Upgrade(1, 0, $revision, $upgrade.coins, [int[]]$upgrade.itemIds, [int[]]$upgrade.itemCounts, $empty, $player)
        Assert-True ($reason -ne '' -and $player.Coins -eq $coins -and $camp.Revision -eq $revision) 'Insufficient materials spent coins or changed the facility.'

        Assert-True ($camp.Deposit(81, 2, 80, $camp.Revision, $equipment) -eq '') 'Could not set up actual warehouse materials.'
        Assert-True ($camp.Upgrade(1, 0, $camp.Revision, $upgrade.coins, [int[]]$upgrade.itemIds, [int[]]$upgrade.itemCounts, $equipment, $player) -eq '') 'Valid upgrade failed.'
        Assert-True ($camp.GetLevel(1) -eq 1 -and $camp.Stored(81) -eq 0 -and $equipment.CountItem(81) -eq 14 -and $player.Coins -eq $coins - $upgrade.coins) 'Warehouse-first successful purchase has incorrect balances.'
        $coins = $player.Coins
        Assert-True ($camp.Upgrade(1, 1, $revision, 1, [int[]]@(), [int[]]@(), $equipment, $player) -ne '' -and $player.Coins -eq $coins) 'A stale camp click was not rejected.'
    }

    Invoke-Case 'Camp production preserves full-bag orders and grants once after space is freed' {
        Assert-True ($camp.Enqueue(1, $recipe.id, $recipe.requiredLevel, 0, $recipe.minutes, $camp.Revision,
            $recipe.coins, [int[]]$recipe.itemIds, [int[]]$recipe.itemCounts, $equipment, $player) -eq '') 'Valid production order failed.'
        $revision = $camp.Revision
        $equipmentRevision = $equipment.Revision
        $coins = $player.Coins
        $job = $camp.JobFor(1)
        $kinds = [string[]]@($recipe.outputIds | ForEach-Object { $id = $_; ($itemRows | Where-Object id -EQ $id).kind })
        Assert-True ($camp.Claim(1, $revision, $recipe.minutes - 1, [int[]]$recipe.outputIds, [int[]]$recipe.outputCounts, $kinds, $equipment) -ne '') 'An unfinished order was claimed.'
        Assert-True ($camp.Claim(1, $revision, $recipe.minutes, [int[]]$recipe.outputIds, [int[]]$recipe.outputCounts, $kinds, $equipment) -ne '') 'Full-bag claim unexpectedly succeeded.'
        Assert-True ([object]::ReferenceEquals($job, $camp.JobFor(1)) -and $camp.JobCount -eq 1 -and $camp.Revision -eq $revision) 'Full-bag claim removed or changed the order.'
        Assert-True ($equipment.Revision -eq $equipmentRevision -and $player.Coins -eq $coins -and $equipment.CountItem(31) -eq 0) 'Failed production claim changed inventory or coins.'

        Assert-True ($camp.Deposit(82, $equipment.CountItem(82), 80, $camp.Revision, $equipment) -eq '') 'Could not free a backpack cell.'
        Assert-True ($camp.Claim(1, $camp.Revision, $recipe.minutes, [int[]]$recipe.outputIds, [int[]]$recipe.outputCounts, $kinds, $equipment) -eq '') 'Completed production did not claim after space was freed.'
        Assert-True ($camp.JobCount -eq 0 -and $equipment.CountItem(31) -eq 12) 'Production output was not transferred exactly once.'
        $revision = $camp.Revision
        Assert-True ($camp.Claim(1, $revision, $recipe.minutes, [int[]]$recipe.outputIds, [int[]]$recipe.outputCounts, $kinds, $equipment) -ne '' -and $equipment.CountItem(31) -eq 12 -and $camp.Revision -eq $revision) 'Repeated claim duplicated output.'
    }

    Invoke-Case 'Equipment half-threshold wear, permanent maximum loss and atomic repair use real instances' {
        $inventory = New-Inventory 4 4
        $weapon = $inventory.AddWeapon(40)
        $inventory.AddStack(83, 20)
        $payer = [ProjectY.Data.PlayerData]::new()
        $condition = [ProjectY.Data.EquipmentConditionData]::Of($weapon)
        [void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($inventory, $weapon.Id, 50)
        Assert-True ($condition.Current -eq 50 -and $condition.Maximum -eq 100 -and $condition.ThresholdArmed) 'Exactly half durability incorrectly reduced the maximum.'
        [void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($inventory, $weapon.Id, 1)
        Assert-True ($condition.Current -eq 49 -and $condition.Maximum -eq 95 -and -not $condition.ThresholdArmed) 'Crossing half durability did not reduce the maximum once.'
        [void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($inventory, $weapon.Id, 5)
        Assert-True ($condition.Maximum -eq 95 -and $condition.Current -eq 44) 'Subsequent damage repeated the permanent penalty.'
        $revision = $inventory.Revision
        Assert-True (-not [ProjectY.Data.EquipmentCombatState]::Repair($inventory, $payer, ('w' + $weapon.Id), 83)) 'Repair without coins unexpectedly succeeded.'
        Assert-True ($inventory.CountItem(83) -eq 20 -and $inventory.Revision -eq $revision -and $condition.Current -eq 44) 'Failed repair consumed material or changed durability.'
        $payer.AddCoins(1000)
        Assert-True ([ProjectY.Data.EquipmentCombatState]::Repair($inventory, $payer, ('w' + $weapon.Id), 83)) 'Valid repair failed.'
        Assert-True ($condition.Current -eq 95 -and $condition.Maximum -eq 95 -and $condition.ThresholdArmed -and $inventory.CountItem(83) -eq 17 -and $payer.Coins -eq 949) 'Repair erased permanent damage or charged incorrect resources.'
        [void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($inventory, $weapon.Id, 48)
        Assert-True ($condition.Current -eq 47 -and $condition.Maximum -eq 90) 'Repair did not rearm the permanent-loss threshold.'
        [void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($inventory, $weapon.Id, 100)
        Assert-True ($condition.Broken -and $condition.Efficiency -eq 0 -and $condition.Maximum -eq 90) 'Broken equipment retained effectiveness or repeated maximum loss.'
    }

    Invoke-Case 'Disarm and recovery transfer original weapons between both owners with runes, ammo and durability intact' {
        $inventory = New-Inventory 12 10
        [ProjectY.Data.EquipmentCombatState]::Initialize($inventory, 901, 2, 0, [int[]]@(), [string[]]@())
        $gun = $inventory.Equipped(901)
        $magazine = $inventory.AddMagazine(21, 31, 12, 7)
        Assert-True ($inventory.AttachMagazine($gun.Id, $magazine.Id)) 'Could not attach the enemy gun magazine.'
        $inventory.SpendAmmo($gun.Id, 1)
        $sword = $inventory.AddWeapon(41)
        $inventory.AddStack(93, 1)
        Assert-True ($inventory.SetRune($sword.Id, 7, 93) -and $inventory.Equip(1, $sword.Id)) 'Could not equip the allied sword and its configured catalyst rune.'
        [void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($inventory, $gun.Id, 51)
        [void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($inventory, $sword.Id, 15)
        $gunCondition = [ProjectY.Data.EquipmentConditionData]::Of($gun)
        $swordCondition = [ProjectY.Data.EquipmentConditionData]::Of($sword)
        Assert-True ($inventory.Grid.Count -eq 0 -and $gunCondition.Current -eq 49 -and $gunCondition.Maximum -eq 95) 'Initial equipment state was not established.'

        $area = [ProjectY.Data.MapAreaStateData]::new(1, 7, 1)
        $session = [ProjectY.Data.LootSessionData]::new()
        $area.AddLoot(1, 102, 'Dropped firearm', [int[]]@(), [int[]]@(), $true)
        $area.AddLoot(2, 102, 'Dropped catalyst sword', [int[]]@(), [int[]]@(), $true)
        $gunDrop = $area.GetLootAt(0)
        $swordDrop = $area.GetLootAt(1)
        foreach ($container in @($gunDrop, $swordDrop)) { $session.Prepare($container, [string[]]@(), [int[]]@(), [int[]]@()) }
        [ProjectY.Data.EquipmentCombatState]::DropWeapon($inventory, $area, $gunDrop.Id, 901, $gun.Id)
        [ProjectY.Data.EquipmentCombatState]::DropWeapon($inventory, $area, $swordDrop.Id, 1, $sword.Id)
        Assert-True ($null -eq $inventory.Equipped(901) -and $null -eq $inventory.Equipped(1) -and $inventory.WeaponCount -eq 0 -and $inventory.MagazineCount -eq 0) 'Dropped equipment still belongs to an actor or inventory.'
        Assert-True ($gun.OwnerActorId -eq 0 -and $gun.Hand -eq '' -and $sword.OwnerActorId -eq 0 -and $sword.Hand -eq '') 'Disarm did not clear both original owners.'
        Assert-True ([object]::ReferenceEquals([ProjectY.Data.EquipmentCombatState]::GroundWeapon($gunDrop), $gun) -and [object]::ReferenceEquals([ProjectY.Data.EquipmentCombatState]::GroundWeapon($swordDrop), $sword)) 'Ground loot was copied instead of retaining the original physical weapons.'

        Assert-True ([ProjectY.Data.EquipmentCombatState]::RecoverWeapon($inventory, $area, $gunDrop.Id, 1, $gun.Id)) 'The allied owner could not pick up the enemy firearm.'
        Assert-True ([ProjectY.Data.EquipmentCombatState]::RecoverWeapon($inventory, $area, $swordDrop.Id, 901, $sword.Id)) 'The enemy owner could not pick up the allied sword.'
        Assert-True ([object]::ReferenceEquals($inventory.Equipped(1), $gun) -and [object]::ReferenceEquals($inventory.Equipped(901), $sword)) 'Recovered weapons did not preserve their original object identity.'
        Assert-True ($gun.OwnerActorId -eq 1 -and $sword.OwnerActorId -eq 901 -and $gun.Hand -eq 'weapon' -and $sword.Hand -eq 'weapon') 'Recovered ownership or equipped hand is incorrect.'
        Assert-True ($gun.MagazineId -eq $magazine.Id -and [object]::ReferenceEquals($inventory.GetMagazine($magazine.Id), $magazine) -and $magazine.Rounds -eq 6) 'The physical loaded magazine or its ammunition changed during transfer.'
        Assert-True ($sword.GetRune(7) -eq 93 -and $inventory.CountItem(93) -eq 0) 'The configured rune was lost or duplicated into the backpack.'
        Assert-True ([object]::ReferenceEquals([ProjectY.Data.EquipmentConditionData]::Of($gun), $gunCondition) -and $gunCondition.Current -eq 49 -and $gunCondition.Maximum -eq 95 -and -not $gunCondition.ThresholdArmed) 'The gun lost its current or permanent durability state.'
        Assert-True ([object]::ReferenceEquals([ProjectY.Data.EquipmentConditionData]::Of($sword), $swordCondition) -and $swordCondition.Current -eq 85 -and $swordCondition.Maximum -eq 100) 'The sword durability changed during transfer.'
        Assert-True ($gunDrop.Looted -and $swordDrop.Looted -and $null -eq [ProjectY.Data.EquipmentCombatState]::GroundWeapon($gunDrop) -and $null -eq [ProjectY.Data.EquipmentCombatState]::GroundWeapon($swordDrop)) 'Recovered ground containers still expose their original weapons.'
        $revision = $inventory.Revision
        Assert-True (-not [ProjectY.Data.EquipmentCombatState]::RecoverWeapon($inventory, $area, $gunDrop.Id, 2, $gun.Id) -and -not [ProjectY.Data.EquipmentCombatState]::RecoverWeapon($inventory, $area, $swordDrop.Id, 2, $sword.Id)) 'Repeated recovery succeeded from an empty ground container.'
        Assert-True ($inventory.Revision -eq $revision -and $inventory.WeaponCount -eq 2 -and $inventory.MagazineCount -eq 1 -and $inventory.Grid.Count -eq 0) 'Repeated recovery duplicated equipment or allocated backpack cells.'
    }

    Invoke-Case 'Party rescue and victory rewards deduplicate, reset per battle and exclude defeated participants' {
        $story = [ProjectY.Data.PartyStoryData]::new()
        $first = [ProjectY.Data.CombatActorData]::new(1, 1)
        $second = [ProjectY.Data.CombatActorData]::new(2, 2)
        $third = [ProjectY.Data.CombatActorData]::new(3, 3)
        foreach ($actor in @($first, $second, $third)) { $actor.SetMaxHP(40); $actor.Restore() }
        $story.BeginBattle()
        $story.AddParticipant($first); $story.AddParticipant($second)
        Assert-True ($story.TryRescue(1, 2, 25)) 'The first rescue was not recorded.'
        $revision = $story.Revision
        Assert-True (-not $story.TryRescue(1, 2, 25) -and -not $story.TryRescue(2, 1, 25)) 'The same unordered rescue pair was rewarded repeatedly.'
        Assert-True ($story.Score(1, 2) -eq 25 -and $story.RescueCount(1) -eq 1 -and $story.RescueCount(2) -eq 0 -and $story.Revision -eq $revision) 'Duplicate rescue changed counters.'
        Assert-True ($story.SettleBattle($true, 10)) 'The first victory settlement failed.'
        $revision = $story.Revision
        Assert-True (-not $story.SettleBattle($true, 10) -and $story.Revision -eq $revision) 'Repeated settlement changed state.'
        Assert-True ($story.Score(1, 2) -eq 35 -and $story.Find(1, 2).SharedBattles -eq 1 -and $story.Score(1, 3) -eq 0) 'Victory reward included a bystander or had the wrong amount.'
        $story.BeginBattle()
        foreach ($actor in @($first, $second, $third)) { $story.AddParticipant($actor) }
        Assert-True ($story.TryRescue(2, 1, 25)) 'A later battle did not reset rescue deduplication.'
        [void]$third.Damage(100)
        Assert-True ($story.SettleBattle($true, 10)) 'A later victory settlement failed.'
        Assert-True ($story.Score(1, 2) -eq 70 -and $story.Find(1, 2).SharedBattles -eq 2 -and $story.Find(1, 2).Rescues -eq 2 -and $story.RescueCount(2) -eq 1) 'The next battle had incorrect rescue or victory rewards.'
        Assert-True ($story.Score(1, 3) -eq 0 -and $story.Score(2, 3) -eq 0) 'Defeated participants received common-victory rewards.'
        $story.Clear()
        Assert-True ($story.ParticipantCount -eq 0 -and $story.BondCount -eq 0 -and $story.RescueCount(1) -eq 0 -and -not $story.SettleBattle($true, 10)) 'New-game cleanup retained relationship state.'
    }
} finally {
    if ($OutputPath) {
        $result = [ordered]@{
            checkedAt = [DateTime]::UtcNow.ToString('o')
            assembly = $assemblyFile
            assemblySha256 = (Get-FileHash -LiteralPath $assemblyFile -Algorithm SHA256).Hash
            host = 'PowerShell / real managed Data classes; no Unity native calls'
            checks = @($checks)
        }
        [IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), ($result | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    }
}
Write-Host ('Gameplay Data acceptance: {0} real-assembly checks passed' -f $checks.Count)

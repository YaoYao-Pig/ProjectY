param([Parameter(Mandatory = $true)][string]$AssemblyPath)

# Real managed Data only. Uses a compiled assembly, never compiles or opens Unity/user saves.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$assembly = [Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $AssemblyPath).Path)
$flags = [Reflection.BindingFlags]'Instance,NonPublic'
$items = (Get-Content -LiteralPath (Join-Path $projectRoot 'Config/Tables/Equipment/EquipmentItemTable.json') -Raw | ConvertFrom-Json).rows
$weapons = (Get-Content -LiteralPath (Join-Path $projectRoot 'Config/Tables/Equipment/EquipmentWeaponTable.json') -Raw | ConvertFrom-Json).rows
$wearables = (Get-Content -LiteralPath (Join-Path $projectRoot 'Config/Tables/Equipment/EquipmentWearableTable.json') -Raw | ConvertFrom-Json).rows
$affixes = (Get-Content -LiteralPath (Join-Path $projectRoot 'Config/Tables/Equipment/EquipmentAffixTable.json') -Raw | ConvertFrom-Json).rows
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function New-Inventory {
    $data = [ProjectY.Data.EquipmentData]::new()
    $data.Grid.Configure(12, 10)
    $data.GetType().GetField('AffixSeed', $flags).SetValue($data, [uint32]1979)
    foreach ($item in $items) {
        $data.Grid.Define($item.id, $item.width, $item.height)
        if ($item.kind -notin @('weapon', 'wearable')) { continue }
        if ($item.kind -eq 'weapon') { $kind = ($weapons | Where-Object id -EQ $item.id).kind }
        else {
            $slot = ($wearables | Where-Object id -EQ $item.id).slot
            $kind = if ($slot -eq 'ring') { 'ring' } elseif ($slot -eq 'offhand') { 'shield' } else { 'armor' }
        }
        $pool = @($affixes | Where-Object { $_.targetTypes -contains $kind })
        [ProjectY.Data.EquipmentAffixData]::Define($data, $item.id, [int[]]$pool.id, [int[]]$pool.weight)
    }
    return $data
}

$first = New-Inventory
$second = New-Inventory
$seen = [Collections.Generic.HashSet[int]]::new()
for ($i = 1; $i -le 256; $i++) {
    $a = $first.AddWeapon(40); $b = $second.AddWeapon(40)
    $id = [ProjectY.Data.EquipmentAffixData]::Of($a)
    Assert-True ($id -eq [ProjectY.Data.EquipmentAffixData]::Of($b)) 'Identical seed/instance sequence did not reproduce its affixes.'
    [void]$seen.Add($id)
    Assert-True ($first.Equip($i, $a.Id) -and $second.Equip($i, $b.Id)) 'Could not release the test backpack cell.'
}
Assert-True ($seen.Contains(1) -and $seen.Contains(6) -and $seen.Contains(12)) 'Deterministic sample lacks ordinary, legendary or damaged weapons.'
Write-Host 'PASS weighted generation is deterministic and includes ordinary, positive and negative affixes'

$data = New-Inventory
$area = [ProjectY.Data.MapAreaStateData]::new(1, 7, 1)
$session = [ProjectY.Data.LootSessionData]::new()
$area.AddLoot(1, 102, 'Affix test chest', [int[]]@(40, 51), [int[]]@(1, 1), $false)
$container = $area.GetLootAt(0)
$swordRow = $items | Where-Object id -EQ 40
$helmetRow = $items | Where-Object id -EQ 51
$session.Prepare($container, [string[]]@('weapon', 'wearable'), [int[]]@($swordRow.width, $helmetRow.width), [int[]]@($swordRow.height, $helmetRow.height))
[ProjectY.Data.EquipmentAffixData]::PrepareLoot($data, $container)
$session.Open($area, [int[]]@($container.Id), $false, 'Affix test', '')
$entry = $session.GetAt(0); $helmetEntry = $session.GetAt(1)
$original = [ProjectY.Data.EquipmentCombatState]::GroundWeapon($container)
$affix = [ProjectY.Data.EquipmentAffixData]::Of($entry)
$helmetAffix = [ProjectY.Data.EquipmentAffixData]::Of($helmetEntry)
[ProjectY.Data.EquipmentAffixData]::PrepareLoot($data, $container)
Assert-True ([object]::ReferenceEquals($original, [ProjectY.Data.EquipmentCombatState]::GroundWeapon($container))) 'Reopening rebuilt the physical weapon.'
[void]$session.Advance($entry.Key, 2, 1)
Assert-True (-not $session.Take($data, $entry.Key, 100, 100, $false, 0, 0, 0)) 'Out-of-bounds loot was accepted.'
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($entry) -eq $affix -and $entry.Count -eq 1) 'Rejected take changed the affix or consumed the loot.'
Assert-True ($session.Take($data, $entry.Key, 0, 0, $false, 0, 0, 0)) 'Could not take generated equipment.'
Assert-True ([object]::ReferenceEquals($data.GetWeapon($original.Id), $original) -and [ProjectY.Data.EquipmentAffixData]::Of($original) -eq $affix) 'Pickup changed the original instance or affix.'
Assert-True ($session.Put($data, ('w' + $original.Id), 0, 0, $false)) 'Could not deposit the generated weapon.'
$deposited = $session.GetAt($session.Count - 1)
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($deposited) -eq $affix) 'Deposit changed the affix.'
Assert-True ($session.Take($data, $deposited.Key, 0, 0, $false, 0, 0, 0)) 'Could not retake deposited equipment.'
[void]$session.Advance($helmetEntry.Key, 2, 1)
Assert-True ($session.Take($data, $helmetEntry.Key, 6, 0, $false, 0, 0, 0)) 'Could not take the generated helmet.'
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($data.GetWearableAt(0)) -eq $helmetAffix) 'Helmet pickup changed its affix.'
Write-Host 'PASS generated loot, repeated preparation, rejected pickup and two-way transfer preserve physical affixes'

[void][ProjectY.Data.EquipmentCombatState]::DamageWeapon($data, $original.Id, 51)
$payer = [ProjectY.Data.PlayerData]::new(); $payer.AddCoins(1000); $data.AddStack(83, 10)
Assert-True ([ProjectY.Data.EquipmentCombatState]::Repair($data, $payer, ('w' + $original.Id), 83)) 'Repair failed.'
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($original) -eq $affix) 'Repair rerolled the affix.'
Assert-True ($data.Equip(1, $original.Id)) 'Could not equip the weapon.'
$area.AddLoot(2, 102, 'Disarm test', [int[]]@(), [int[]]@(), $true)
$drop = $area.GetLootAt(1); $session.Prepare($drop, [string[]]@(), [int[]]@(), [int[]]@())
[ProjectY.Data.EquipmentCombatState]::DropWeapon($data, $area, $drop.Id, 1, $original.Id)
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of([ProjectY.Data.EquipmentCombatState]::GroundWeapon($drop)) -eq $affix) 'Disarm lost the affix.'
Assert-True ([ProjectY.Data.EquipmentCombatState]::RecoverWeapon($data, $area, $drop.Id, 2, $original.Id)) 'Recovery failed.'
Assert-True ([object]::ReferenceEquals($data.Equipped(2), $original) -and [ProjectY.Data.EquipmentAffixData]::Of($original) -eq $affix) 'Recovery changed the physical affix.'
Assert-True ($data.Equip(2, 0)) 'Could not return the recovered weapon to the backpack.'
Write-Host 'PASS repair, disarm, ownership changes and recovery preserve the affix'

$owners = [Collections.Generic.HashSet[int]]::new()
$captureArgs = [object[]]::new(1); $captureArgs[0] = $owners
$saved = $data.GetType().GetMethod('CaptureSave', $flags).Invoke($data, $captureArgs)
$prepareArgs = [object[]]::new(2); $prepareArgs[0] = $saved; $prepareArgs[1] = $owners
$prepare = $data.GetType().GetMethod('PrepareSave', $flags)
$restored = $prepare.Invoke($data, $prepareArgs)
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($restored.GetWeapon($original.Id)) -eq $affix) 'Weapon save roundtrip lost its affix.'
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($restored.GetWearableAt(0)) -eq $helmetAffix) 'Wearable save roundtrip lost its affix.'
$revision = $data.Revision
foreach ($invalid in @(0, 999999, 7)) {
    $saved.weapons[0].affixId = $invalid; $rejected = $false
    try { [void]$prepare.Invoke($data, $prepareArgs) } catch { $rejected = $true }
    Assert-True ($rejected -and $data.Revision -eq $revision -and [ProjectY.Data.EquipmentAffixData]::Of($original) -eq $affix) 'Invalid save was accepted or modified current equipment.'
}
Write-Host 'PASS weapon/wearable save roundtrip and atomic rejection of missing, unknown or incompatible affixes'

$shopData = New-Inventory
$shop = [ProjectY.Data.ShopData]::new()
$stock = $shop.Refresh(1, 1, 1, 1, 0, [int[]]@(1), [int[]]@(40), [int[]]@(1), [int[]]@(1))
$shop.Open($stock)
$payer = [ProjectY.Data.PlayerData]::new(); $payer.AddCoins(1)
Assert-True ($shop.Buy(1, 1, $shop.Revision, $shopData, $payer, 'weapon', 0, 0, 0) -eq '') 'Shop purchase failed.'
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($shopData.GetWeaponAt(0)) -gt 0) 'Purchased equipment lacks an affix.'
[ProjectY.Data.EquipmentCombatState]::Initialize($shopData, 901, 40, 0, [int[]]@(52), [string[]]@('body'))
Assert-True ([ProjectY.Data.EquipmentAffixData]::Of($shopData.Equipped(901)) -gt 0 -and [ProjectY.Data.EquipmentAffixData]::Of($shopData.Worn(901, 'body')) -gt 0) 'Enemy loadout lacks affixes.'
Write-Host 'PASS shop purchases and enemy initial equipment use the same generation path'

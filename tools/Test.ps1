param(
    [string]$Godot = 'godot'
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDirectory = Join-Path $projectPath '.tmp/tests'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
Push-Location $projectPath
try {
    function Invoke-Suite([string]$Scene, [string]$Marker, [string]$LogName) {
        # Check the exit code, the success marker and script errors: a GDScript runtime error does not stop a
        # suite (in the C# version it was an exception that failed it).
        $ErrorActionPreference = 'Continue'
        $logPath = Join-Path $logDirectory $LogName
        & $Godot --headless --path $projectPath --log-file $logPath $Scene --quit-after 1800 2>&1 | Out-Host
        $engineExit = $LASTEXITCODE
        $marked = Select-String -LiteralPath $logPath -SimpleMatch $Marker -Quiet
        $scriptErrors = Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|FAIL \(exception\)' -Quiet
        if ($engineExit -ne 0 -or -not $marked -or $scriptErrors) {
            throw "Suite failed: $Scene. See $logPath"
        }
    }

    Invoke-Suite 'tests/SoundCheck.tscn' 'SOUND ALL OK' 'sound.log'
    Invoke-Suite 'tests/RadioPanelCheck.tscn' 'RADIO PANEL ALL OK' 'radio-panel.log'
    Invoke-Suite 'tests/ChestPatrolCheck.tscn' 'CHEST PATROL ALL OK' 'chest-patrol.log'
    Invoke-Suite 'tests/GameplayRefineCheck.tscn' 'GAMEPLAY REFINE ALL OK' 'gameplay-refine.log'
    Invoke-Suite 'tests/EnemyCombatCheck.tscn' 'ENEMY COMBAT ALL OK' 'enemy-combat.log'
    Invoke-Suite 'tests/CombatReadabilityCheck.tscn' 'COMBAT READABILITY ALL OK' 'combat-readability.log'
    Invoke-Suite 'tools/EnemyDesignPreview.tscn' 'ENEMY DESIGN ASSETS OK' 'enemy-art.log'
    Invoke-Suite 'tests/GeometryCheck.tscn' 'GEOMETRY ALL OK' 'geometry.log'
    Invoke-Suite 'tests/LandmarkGroundCheck.tscn' 'LANDMARK GROUND ALL OK' 'landmark-ground.log'
    Invoke-Suite 'tests/HarvestCheck.tscn' 'HARVEST ALL OK' 'harvest.log'
    Invoke-Suite 'tests/HarvestAnimCheck.tscn' 'HARVEST ANIM ALL OK' 'harvest-anim.log'
    Invoke-Suite 'tests/SimCheck.tscn' 'ALL OK' 'simulation.log'
    Invoke-Suite 'tests/NightSpawnCheck.tscn' 'NIGHT SPAWN ALL OK' 'night-spawn.log'
    Invoke-Suite 'tests/TacticalCraftCheck.tscn' 'TACTICAL CRAFT ALL OK' 'tactical-craft.log'
    Invoke-Suite 'tests/SurvivalWorldCheck.tscn' 'SURVIVAL WORLD ALL OK' 'survival-world.log'
    Invoke-Suite 'tests/ExplorationChestCheck.tscn' 'EXPLORATION CHESTS ALL OK' 'exploration-chests.log'
    Invoke-Suite 'tests/ResourceLayoutCheck.tscn' 'RESOURCE LAYOUT ALL OK' 'resource-layout.log'

    # Multiplayer is removed for now; the network suite lives in git commit cf44b5f (tests/NetworkCheck.cs).
    Write-Output 'All checks passed.'
}
finally { Pop-Location }

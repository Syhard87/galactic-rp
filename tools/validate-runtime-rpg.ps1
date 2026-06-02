[CmdletBinding()]
param(
    [switch]$SkipMigrations,
    [switch]$SkipSeeds,
    [switch]$SkipQueries,
    [switch]$SkipPackageCopy,
    [switch]$IncludeDevSeed
)

$ErrorActionPreference = "Stop"

$RepoRoot = "C:\Users\Syhar\OneDrive - educ-valadon-limoges.fr\Bureau\galactic-rp\galactic-rp"
$ServerRoot = "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"
$PostgresContainer = "galactic-rp-postgres"
$PostgresUser = "galactic"
$PostgresDatabase = "galactic_rp"

$MigrationFiles = @(
    "001_init.sql",
    "002_factions_foundation.sql",
    "003_inventory_foundation.sql",
    "004_character_progression_foundation.sql",
    "005_character_skills_foundation.sql",
    "006_quests_foundation.sql",
    "007_quest_item_rewards.sql",
    "008_quest_objectives_foundation.sql",
    "009_quest_skill_rewards.sql",
    "010_crafting_foundation.sql",
    "011_crafting_stations.sql",
    "012_reputation_foundation.sql",
    "013_quest_reputation_rewards.sql",
    "014_quest_reputation_requirements.sql",
    "015_contracts_foundation.sql",
    "016_contracts_payment.sql"
)

$SeedFiles = @(
    "factions_mvp_seed.sql",
    "inventory_mvp_seed.sql",
    "reputation_mvp_seed.sql",
    "quests_mvp_seed.sql",
    "quest_objectives_mvp_seed.sql",
    "crafting_stations_mvp_seed.sql",
    "crafting_mvp_seed.sql"
)

$VerificationQueries = @(
    @{
        Title = "Characters money"
        Sql = "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
    },
    @{
        Title = "Inventory items"
        Sql = "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
    },
    @{
        Title = "Character progression"
        Sql = "SELECT character_id, level, current_xp, total_xp, class_key, unspent_talent_points FROM character_progression ORDER BY character_id;"
    },
    @{
        Title = "Character skills"
        Sql = "SELECT character_id, skill_key, level, current_xp, total_xp FROM character_skills ORDER BY character_id, skill_key;"
    },
    @{
        Title = "Quest definitions"
        Sql = "SELECT key, title, reward_xp, reward_item_key, reward_skill_key, reward_reputation_key, required_reputation_key FROM quests ORDER BY key;"
    },
    @{
        Title = "Character reputations"
        Sql = "SELECT character_id, reputation_key, value, rank FROM character_reputations ORDER BY character_id, reputation_key;"
    },
    @{
        Title = "Contracts"
        Sql = "SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;"
    },
    @{
        Title = "Crafting recipes"
        Sql = "SELECT key, result_item_key, station_key, is_active FROM crafting_recipes ORDER BY key;"
    },
    @{
        Title = "Crafting stations"
        Sql = "SELECT key, name, station_type, position_x, position_y, position_z, radius, is_active FROM crafting_stations ORDER BY key;"
    }
)

function Assert-CommandAvailable {
    param(
        [string]$CommandName
    )

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Commande introuvable dans le PATH : $CommandName"
    }
}

function Invoke-DockerPsqlFile {
    param(
        [string]$RelativeFilePath
    )

    $ContainerFilePath = "/workspace/$($RelativeFilePath.Replace('\', '/'))"
    Write-Host "Applying SQL file: $RelativeFilePath"
    & docker exec -i $PostgresContainer psql -v ON_ERROR_STOP=1 -U $PostgresUser -d $PostgresDatabase -f $ContainerFilePath
    if ($LASTEXITCODE -ne 0) {
        throw "SQL file execution failed: $RelativeFilePath"
    }
}

function Invoke-DockerPsqlQuery {
    param(
        [string]$Title,
        [string]$Sql
    )

    Write-Host ""
    Write-Host "Query: $Title"
    & docker exec -i $PostgresContainer psql -U $PostgresUser -d $PostgresDatabase -c $Sql
    if ($LASTEXITCODE -ne 0) {
        throw "SQL query failed: $Title"
    }
}

function Assert-ContainerRunning {
    $AllContainers = & docker ps -a --format "{{.Names}}"
    if ($LASTEXITCODE -ne 0) {
        throw "Impossible de lister les conteneurs Docker."
    }

    if ($AllContainers -notcontains $PostgresContainer) {
        throw "Conteneur PostgreSQL introuvable : $PostgresContainer. Lancez .\tools\start-dev.ps1 d'abord."
    }

    $RunningContainers = & docker ps --format "{{.Names}}"
    if ($LASTEXITCODE -ne 0) {
        throw "Impossible de verifier les conteneurs Docker actifs."
    }

    if ($RunningContainers -notcontains $PostgresContainer) {
        throw "Conteneur PostgreSQL present mais non demarre : $PostgresContainer"
    }
}

function Invoke-PackageCopy {
    $SourcePackages = Join-Path $RepoRoot "server\Packages"
    $TargetPackages = Join-Path $ServerRoot "Packages"

    if (-not (Test-Path -LiteralPath $SourcePackages -PathType Container)) {
        throw "Source Packages introuvable : $SourcePackages"
    }

    if (-not (Test-Path -LiteralPath $ServerRoot -PathType Container)) {
        throw "ServerRoot introuvable : $ServerRoot"
    }

    Write-Host ""
    Write-Host "Copying nanos world packages to: $TargetPackages"
    & robocopy $SourcePackages $TargetPackages /E /FFT /R:2 /W:2 /NP /XF ".gitkeep"
    $RobocopyExitCode = $LASTEXITCODE

    if ($RobocopyExitCode -gt 7) {
        throw "Robocopy failed with exit code $RobocopyExitCode"
    }
}

Write-Host "Galactic RP runtime RPG validation helper"
Write-Host "RepoRoot          : $RepoRoot"
Write-Host "ServerRoot        : $ServerRoot"
Write-Host "PostgresContainer : $PostgresContainer"
Write-Host "Database          : $PostgresDatabase"

Assert-CommandAvailable -CommandName "docker"
Assert-ContainerRunning

Write-Host ""
Write-Host "Docker container check OK: $PostgresContainer"

if (-not $SkipMigrations) {
    Write-Host ""
    Write-Host "Applying migrations..."

    foreach ($MigrationFile in $MigrationFiles) {
        $RelativePath = Join-Path "database\migrations" $MigrationFile
        $AbsolutePath = Join-Path $RepoRoot $RelativePath

        if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
            throw "Migration introuvable : $AbsolutePath"
        }

        Invoke-DockerPsqlFile -RelativeFilePath $RelativePath
    }
}
else {
    Write-Host ""
    Write-Host "Skipping migrations by request."
}

if (-not $SkipSeeds) {
    Write-Host ""
    Write-Host "Applying base RPG seeds..."

    foreach ($SeedFile in $SeedFiles) {
        $RelativePath = Join-Path "database\seeds" $SeedFile
        $AbsolutePath = Join-Path $RepoRoot $RelativePath

        if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
            throw "Seed introuvable : $AbsolutePath"
        }

        Invoke-DockerPsqlFile -RelativeFilePath $RelativePath
    }

    if ($IncludeDevSeed) {
        $RelativePath = "database\seeds\dev_seed.sql"
        $AbsolutePath = Join-Path $RepoRoot $RelativePath

        if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
            throw "Seed introuvable : $AbsolutePath"
        }

        Write-Host ""
        Write-Host "Applying optional dev seed..."
        Invoke-DockerPsqlFile -RelativeFilePath $RelativePath
    }
}
else {
    Write-Host ""
    Write-Host "Skipping seeds by request."
}

if (-not $SkipQueries) {
    Write-Host ""
    Write-Host "Running verification queries..."

    foreach ($Query in $VerificationQueries) {
        Invoke-DockerPsqlQuery -Title $Query.Title -Sql $Query.Sql
    }
}
else {
    Write-Host ""
    Write-Host "Skipping verification queries by request."
}

if (-not $SkipPackageCopy) {
    Invoke-PackageCopy
}
else {
    Write-Host ""
    Write-Host "Skipping package copy by request."
}

Write-Host ""
Write-Host "Manual nanos world launch command:"
Write-Host "cd `"$ServerRoot`""
Write-Host ".\NanosWorldServer.exe --playtest"

Write-Host ""
Write-Host "Reminder: do not commit your real Config.toml or local platform IDs."

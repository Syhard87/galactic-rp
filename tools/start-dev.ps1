[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-EnvValue {
    param(
        [hashtable]$Values,
        [string]$Key,
        [string]$DefaultValue
    )

    if ($Values.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace($Values[$Key])) {
        return $Values[$Key]
    }

    return $DefaultValue
}

function Read-EnvFile {
    param(
        [string]$Path
    )

    $result = @{}

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()

        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
            continue
        }

        $separatorIndex = $trimmed.IndexOf("=")
        if ($separatorIndex -lt 1) {
            continue
        }

        $key = $trimmed.Substring(0, $separatorIndex).Trim()
        $value = $trimmed.Substring($separatorIndex + 1).Trim()
        $result[$key] = $value
    }

    return $result
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDirectory
$composeFile = Join-Path $repoRoot "docker/docker-compose.yml"
$envFile = Join-Path $repoRoot "docker/.env.example"

Write-Host "Galactic RP local dev startup"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker n'est pas disponible dans le PATH. Installez Docker Desktop ou un moteur Docker compatible Compose."
}

try {
    docker compose version | Out-Null
}
catch {
    throw "Docker Compose n'est pas disponible. Verifiez votre installation Docker."
}

if (-not (Test-Path -LiteralPath $composeFile -PathType Leaf)) {
    throw "Fichier Compose introuvable : $composeFile"
}

if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
    throw "Fichier d'environnement exemple introuvable : $envFile"
}

$envValues = Read-EnvFile -Path $envFile

$postgresHost = "localhost"
$postgresPort = Get-EnvValue -Values $envValues -Key "POSTGRES_PORT" -DefaultValue "5432"
$postgresDb = Get-EnvValue -Values $envValues -Key "POSTGRES_DB" -DefaultValue "galactic_rp"
$postgresUser = Get-EnvValue -Values $envValues -Key "POSTGRES_USER" -DefaultValue "galactic"
$postgresPassword = Get-EnvValue -Values $envValues -Key "POSTGRES_PASSWORD" -DefaultValue "change-me-local-only"
$pgAdminPort = Get-EnvValue -Values $envValues -Key "PGADMIN_PORT" -DefaultValue "5050"
$pgAdminEmail = Get-EnvValue -Values $envValues -Key "PGADMIN_DEFAULT_EMAIL" -DefaultValue "admin@local.dev"
$pgAdminPassword = Get-EnvValue -Values $envValues -Key "PGADMIN_DEFAULT_PASSWORD" -DefaultValue "change-me-local-only"

Write-Host ""
Write-Host "Starting Docker Compose services..."
docker compose --env-file $envFile -f $composeFile up -d

Write-Host ""
Write-Host "Service status:"
docker compose --env-file $envFile -f $composeFile ps

Write-Host ""
Write-Host "Useful local URLs:"
Write-Host "  pgAdmin: http://localhost:$pgAdminPort"
Write-Host "  PostgreSQL: ${postgresHost}:${postgresPort}"

Write-Host ""
Write-Host "Local example credentials from docker/.env.example:"
Write-Host "  pgAdmin email: $pgAdminEmail"
Write-Host "  pgAdmin password: $pgAdminPassword"
Write-Host "  PostgreSQL database: $postgresDb"
Write-Host "  PostgreSQL user: $postgresUser"
Write-Host "  PostgreSQL password: $postgresPassword"

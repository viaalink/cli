# Viaalink CLI Installer for Windows — installs the CLI as via.exe and asd.exe
# Usage: irm https://raw.githubusercontent.com/viaalink/cli/main/install.ps1 | iex
# Or with custom install dir: $env:INSTALL_DIR = "C:\Program Files\asd"; irm ... | iex
#
# Options (via environment variables):
#   INSTALL_DIR  - Custom install directory (default: %LOCALAPPDATA%\asd\bin)
#   VERSION      - Install a specific version tag (e.g. the latest tag from releases)
#                  Set VERSION=list to show available releases
#   ASD_INSTALL_BASE_URL - Override download base URL (for CI testing with local files)
#                          Supports: file:///path, C:\path, or http://...
#
# Examples:
#   irm https://raw.githubusercontent.com/viaalink/cli/main/install.ps1 | iex                                          # Latest
#   $env:VERSION = "<tag>"; irm https://raw.githubusercontent.com/viaalink/cli/main/install.ps1 | iex                   # Specific version
#   $env:VERSION = "list"; irm https://raw.githubusercontent.com/viaalink/cli/main/install.ps1 | iex                   # List versions
#
# After installation, update with: via update
#
# NOTE: AVX baseline builds are currently Linux-only. Windows does not need
# a baseline build at this time (all supported Windows x64 CPUs have AVX).
# If this changes in the future, add AVX detection here.

$ErrorActionPreference = "Stop"

# Configuration — releases come only from the public viaalink/cli repo on GitHub.
$Repo = "viaalink/cli"
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { "$env:LOCALAPPDATA\asd\bin" }
$Platform = "windows-x64"
$ArchiveName = "asd-windows-x64.zip"
$Version = if ($env:VERSION) { $env:VERSION } else { "" }
$InstallBaseUrl = if ($env:ASD_INSTALL_BASE_URL) { $env:ASD_INSTALL_BASE_URL } else { "" }

function Write-Info($Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn($Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error($Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

# Replace the directory $Dest with a copy of $Source without removing $Dest in
# place. Remove-Item -Recurse on a tree that is still in use fails halfway and
# leaves neither the old nor the new one (release v3.0.0 hit the same with
# rm -rf in install.sh). Copy next to $Dest, rename $Dest aside, rename the
# copy into place, then remove the old tree best-effort; the next install
# removes a leftover.
function Install-Directory($Source, $Dest) {
    $parent = Split-Path -Parent $Dest
    $name = Split-Path -Leaf $Dest
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    # Trees an earlier install could not remove. Only ".old-" ones: a ".new-"
    # one may be another installer's copy in progress.
    Get-ChildItem -Path $parent -Directory -Force -Filter ".$name.old-*" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    $stage = Join-Path $parent ".$name.new-$(Get-Random)"
    Copy-Item -Path $Source -Destination $stage -Recurse
    $aside = $null
    if (Test-Path $Dest) {
        $aside = Join-Path $parent ".$name.old-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())-$PID"
        try {
            Rename-Item -Path $Dest -NewName (Split-Path -Leaf $aside)
        } catch {
            Remove-Item -Path $stage -Recurse -Force -ErrorAction SilentlyContinue
            Write-Error "Could not move the previous $Dest aside (still in use?): $_"
        }
    }
    try {
        Rename-Item -Path $stage -NewName $name
    } catch {
        if ($aside) { Rename-Item -Path $aside -NewName $name -ErrorAction SilentlyContinue }
        Remove-Item -Path $stage -Recurse -Force -ErrorAction SilentlyContinue
        Write-Error "Could not move the new $name into ${Dest}: $_"
    }
    if ($aside) {
        Remove-Item -Path $aside -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $aside) {
            Write-Warn "Could not remove the previous $name (still in use?): $aside - the next install removes it"
        }
    }
}

function Get-AuthHeaders {
    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "asd-cli-installer"
    }

    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    } elseif ($env:GH_TOKEN) {
        $headers["Authorization"] = "Bearer $env:GH_TOKEN"
    }

    return $headers
}

function Get-SpecificVersion($RequestedVersion) {
    # Ensure it starts with 'v'
    if (-not $RequestedVersion.StartsWith("v")) {
        $RequestedVersion = "v$RequestedVersion"
    }

    $repos = @($Repo)
    $headers = Get-AuthHeaders

    foreach ($repo in $repos) {
        $apiUrl = "https://api.github.com/repos/$repo/releases/tags/$RequestedVersion"

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
            if ($response.tag_name) {
                $script:ActiveRepo = $repo
                return $response.tag_name
            }
        } catch {
            continue
        }
    }

    Write-Error "Version $RequestedVersion not found. Use `$env:VERSION = 'list'` to see available versions."
}

function Get-LatestVersion {
    $repos = @($Repo)
    $headers = Get-AuthHeaders

    foreach ($repo in $repos) {
        $apiUrl = "https://api.github.com/repos/$repo/releases/latest"

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
            if ($response.tag_name) {
                $script:ActiveRepo = $repo
                return $response.tag_name
            }
        } catch {
            continue
        }
    }

    Write-Error "Failed to fetch latest release. Check your internet connection."
}

function Show-AvailableVersions {
    $repos = @($Repo)
    $headers = Get-AuthHeaders

    foreach ($repo in $repos) {
        $apiUrl = "https://api.github.com/repos/$repo/releases?per_page=20"

        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
            if ($response.Count -gt 0) {
                Write-Host ""
                Write-Info "Available versions (from $repo):"
                Write-Host ""

                $first = $true
                $exampleTag = ""
                foreach ($release in $response) {
                    $tag = $release.tag_name
                    if ($first) {
                        Write-Host "  $tag  (latest)"
                        $first = $false
                    } else {
                        Write-Host "  $tag"
                        if (-not $exampleTag) { $exampleTag = $tag }
                    }
                }

                Write-Host ""
                Write-Info "Install a specific version:"
                Write-Host "  `$env:VERSION = '$exampleTag'; irm https://raw.githubusercontent.com/viaalink/cli/main/install.ps1 | iex"
                Write-Host ""
                return
            }
        } catch {
            continue
        }
    }

    Write-Error "Failed to fetch releases. Check your internet connection."
}

function Install-Asd {
    # Handle VERSION=list
    if ($Version -eq "list") {
        Show-AvailableVersions
        return
    }

    Write-Info "Detected platform: $Platform"

    # Get version — specific or latest
    if ($InstallBaseUrl) {
        $resolvedVersion = if ($Version) { $Version } else { "local" }
        if ($resolvedVersion -ne "local" -and -not $resolvedVersion.StartsWith("v")) {
            $resolvedVersion = "v$resolvedVersion"
        }
        $script:ActiveRepo = "local"
        Write-Info "Using local install source: $InstallBaseUrl"
        Write-Info "Version: $resolvedVersion"
    } elseif ($Version) {
        $resolvedVersion = Get-SpecificVersion $Version
        Write-Info "Requested version: $resolvedVersion"
    } else {
        $resolvedVersion = Get-LatestVersion
        Write-Info "Latest version: $resolvedVersion"
    }

    if (-not $resolvedVersion) {
        Write-Error "Could not determine version"
    }

    if (-not $InstallBaseUrl) {
        Write-Info "Source: $ActiveRepo"
    }

    # Construct download URL
    if ($InstallBaseUrl) {
        $downloadUrl = "$($InstallBaseUrl.TrimEnd('\').TrimEnd('/'))/$ArchiveName"
    } else {
        $downloadUrl = "https://github.com/$ActiveRepo/releases/download/$resolvedVersion/$ArchiveName"
    }

    # Create install directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # Pre-install reap: stop any lingering asd-spawned processes that would
    # lock the target binaries we're about to overwrite. PR #279 hit:
    #   Copy-Item ... caddy.exe: The process cannot access the file because
    #   it is being used by another process.
    # The previous e2e run (or a leaked test) left caddy.exe (or asd/ttyd/
    # viaalink-relay, or the old asd-tunnel) holding the file. Win32 file handles block overwrite even
    # with -Force. Reap them here so install is always idempotent — matches
    # the orphan-reap pattern release.yml's e2e-windows uses post-test
    # (release.yml:~1990, "Reap asd-spawned orphans"). Best-effort: no error
    # if the process isn't there.
    foreach ($lockedExe in @('asd', 'via', 'caddy', 'ttyd', 'viaalink-relay', 'asd-tunnel', 'busybox')) {
        $procs = Get-Process -Name $lockedExe -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Info "Reaping $($procs.Count) lingering $lockedExe process(es) holding install-dir files"
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
    # Brief settle for the OS to release the file handles.
    Start-Sleep -Milliseconds 250

    # Create temp directory
    $tmpDir = Join-Path $env:TEMP "asd-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    try {
        $archivePath = Join-Path $tmpDir $ArchiveName
        $extractDir = Join-Path $tmpDir "extracted"

        Write-Info "Downloading $ArchiveName..."

        # Local file path or remote URL
        $isLocalPath = $false
        $localPath = ""
        if ($downloadUrl -match '^file://') {
            $localPath = $downloadUrl -replace '^file://', ''
            $isLocalPath = $true
        } elseif ($downloadUrl -match '^[A-Za-z]:\\' -or ($downloadUrl -match '^/' -and (Test-Path $downloadUrl -ErrorAction SilentlyContinue))) {
            $localPath = $downloadUrl
            $isLocalPath = $true
        }

        if ($isLocalPath) {
            if (-not (Test-Path $localPath)) {
                Write-Error "Local archive not found: $localPath"
            }
            Copy-Item -Path $localPath -Destination $archivePath -Force
        } else {
            $headers = @{
                "Accept" = "application/octet-stream"
                "User-Agent" = "asd-cli-installer"
            }

            if ($env:GITHUB_TOKEN) {
                $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
            } elseif ($env:GH_TOKEN) {
                $headers["Authorization"] = "Bearer $env:GH_TOKEN"
            }

            Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -Headers $headers
        }

        # Verify checksum against SHA256SUMS.txt
        $checksumsName = "SHA256SUMS.txt"
        $checksumsPath = Join-Path $tmpDir $checksumsName
        Write-Info "Verifying archive checksum..."

        if ($isLocalPath) {
            $localChecksumsPath = Join-Path (Split-Path -Parent $localPath) $checksumsName
            if (-not (Test-Path $localChecksumsPath)) {
                Write-Error "Checksums file not found: $localChecksumsPath. Refusing install."
            }
            Copy-Item -Path $localChecksumsPath -Destination $checksumsPath -Force
        } else {
            $checksumsUrl = if ($InstallBaseUrl) {
                "$($InstallBaseUrl.TrimEnd('\').TrimEnd('/'))/$checksumsName"
            } else {
                "https://github.com/$ActiveRepo/releases/download/$resolvedVersion/$checksumsName"
            }
            try {
                $checksumHeaders = @{
                    "Accept" = "text/plain"
                    "User-Agent" = "asd-cli-installer"
                }
                if ($env:GITHUB_TOKEN) {
                    $checksumHeaders["Authorization"] = "Bearer $env:GITHUB_TOKEN"
                } elseif ($env:GH_TOKEN) {
                    $checksumHeaders["Authorization"] = "Bearer $env:GH_TOKEN"
                }
                Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -Headers $checksumHeaders
            } catch {
                Write-Error "Failed to download checksums file ($checksumsName) for ${resolvedVersion}: $_. Refusing install."
            }
        }

        if (-not (Test-Path $checksumsPath)) {
            Write-Error "Checksums file ($checksumsName) is missing. Refusing install."
        }

        $expectedHash = $null
        $lines = Get-Content -Path $checksumsPath
        foreach ($line in $lines) {
            if ($line -match "^\s*([a-fA-F0-9]{64})\s+\*?$ArchiveName\s*$") {
                $expectedHash = $matches[1].ToLower()
                break
            }
        }

        if (-not $expectedHash) {
            Write-Error "No checksum found for $ArchiveName in $checksumsName. Refusing install."
        }

        $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLower()

        if ($actualHash -ne $expectedHash) {
            Write-Error "Checksum mismatch for $ArchiveName!`nExpected: $expectedHash`nActual:   $actualHash`nRefusing install."
        }

        Write-Info "Checksum verified: $actualHash"

        Write-Info "Extracting..."
        Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force

        # Copy binary to install directory (search subdirectory structure)
        $sourceBin = Get-ChildItem -Path $extractDir -Recurse -Filter "asd.exe" | Select-Object -First 1
        if (-not $sourceBin) {
            Write-Error "Binary not found in archive"
        }

        $destBin = Join-Path $InstallDir "asd.exe"
        Copy-Item -Path $sourceBin.FullName -Destination $destBin -Force
        # via.exe is the same program under the product name (ADR 0003). A
        # symlink needs admin rights or Developer Mode on Windows, so it is
        # a copy; `via update` / `asd update` replace both.
        $viaBin = Join-Path $InstallDir "via.exe"
        Copy-Item -Path $sourceBin.FullName -Destination $viaBin -Force

        # Also copy helper binaries if present (check subdirectory structure too)
        $binDir = Join-Path $extractDir "bin"
        if (-not (Test-Path $binDir)) {
            $binDir = Get-ChildItem -Path $extractDir -Directory | ForEach-Object {
                Join-Path $_.FullName "bin"
            } | Where-Object { Test-Path $_ } | Select-Object -First 1
        }
        if ($binDir -and (Test-Path $binDir)) {
            Get-ChildItem -Path $binDir -Filter "*.exe" | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $InstallDir -Force
            }
        }

        # The relay client was called asd-tunnel before v1.35.0. Remove the
        # old copy once viaalink-relay.exe is in place and runs.
        $relayBin = Join-Path $InstallDir "viaalink-relay.exe"
        $oldRelayBin = Join-Path $InstallDir "asd-tunnel.exe"
        if ((Test-Path $oldRelayBin) -and (Test-Path $relayBin)) {
            & $relayBin --version *> $null
            if ($LASTEXITCODE -eq 0) {
                Remove-Item -Path $oldRelayBin -Force -ErrorAction SilentlyContinue
                if (Test-Path $oldRelayBin) {
                    Write-Warn "Could not remove the old $oldRelayBin; remove it once its tunnels have stopped"
                } else {
                    Write-Info "Removed the old asd-tunnel.exe from $InstallDir"
                }
            }
            $global:LASTEXITCODE = 0
        }

        # Install assets to global ASD home
        $asdHome = if ($env:ASD_HOME) { $env:ASD_HOME } else { "$env:LOCALAPPDATA\asd" }

        # Find and install modules
        $modulesDir = Get-ChildItem -Path $extractDir -Directory -Recurse -Depth 2 |
            Where-Object { $_.Name -eq "modules" } | Select-Object -First 1
        if ($modulesDir) {
            $destModules = Join-Path $asdHome "modules"
            Install-Directory $modulesDir.FullName $destModules
            Write-Info "Modules installed to $destModules\"
        }

        # Find and install dashboard
        $dashboardDist = Get-ChildItem -Path $extractDir -Directory -Recurse -Depth 3 |
            Where-Object { $_.Name -eq "dist" -and $_.Parent.Name -eq "dashboard" } | Select-Object -First 1
        if ($dashboardDist) {
            $destDashboard = Join-Path $asdHome "dashboard\dist"
            Install-Directory $dashboardDist.FullName $destDashboard
            Write-Info "Dashboard installed to $destDashboard\"
        }

        # Verify installation
        if ((Test-Path $destBin) -and (Test-Path $viaBin)) {
            Write-Info "Viaalink CLI installed successfully!"
            Write-Info "   Commands: via, asd"
            Write-Info "   Location: $viaBin, $destBin"

            $installedVersion = & $viaBin --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $installedVersion) {
                Write-Info "   Version: $installedVersion"
            } else {
                Write-Info "   Version: $resolvedVersion"
            }
            # The version probe is informational; do not let a native exit code
            # from older/broken --version handling fail an otherwise valid install.
            $global:LASTEXITCODE = 0

            Write-Host ""
            Write-Info "To update in the future, run:"
            Write-Host "   via update"
            Write-Host ""

            # Check if in PATH
            $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            if ($currentPath -notlike "*$InstallDir*") {
                Write-Warn "$InstallDir is not in your PATH."
                Write-Host ""
                Write-Host "To add it permanently, run this in PowerShell (admin):"
                Write-Host ""
                Write-Host "   `$path = [Environment]::GetEnvironmentVariable('PATH', 'User')"
                Write-Host "   [Environment]::SetEnvironmentVariable('PATH', `"`$path;$InstallDir`", 'User')"
                Write-Host ""
                Write-Host "Or add it for this session only:"
                Write-Host "   `$env:PATH += `";$InstallDir`""
                Write-Host ""

                # Offer to add to PATH (only in interactive mode)
                if ([Environment]::UserInteractive -and -not $env:CI) {
                    $addToPath = Read-Host "Add to PATH now? (y/n)"
                    if ($addToPath -eq "y" -or $addToPath -eq "Y") {
                        $newPath = "$currentPath;$InstallDir"
                        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
                        $env:PATH = "$env:PATH;$InstallDir"
                        Write-Info "Added to PATH. Restart your terminal for changes to take effect."
                    }
                }
            }
        } else {
            Write-Error "Installation failed - binary not found"
        }
    } finally {
        # Cleanup
        if (Test-Path $tmpDir) {
            Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Run installer
Install-Asd

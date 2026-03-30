Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gitUrl = 'https://github.com/git-for-windows/git/releases/download/v2.53.0.windows.2/PortableGit-2.53.0.2-64-bit.7z.exe'
$portableGitSha256 = '5F4F76C7D5036EA3B29FBADEDCC510733B3A0EE8DA57A36796E2E57A466BE964'
$gitDir = Join-Path $PSScriptRoot '_git'
$gitExe = Join-Path $PSScriptRoot '_git\bin\git.exe'
$repoUrl = 'https://github.com/mothmind/clusterstrike-crew-game.git'

function Test-PortableGitInstaller {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedSha256
    )

    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $InstallerPath
    if ([string]::IsNullOrWhiteSpace($hash.Hash)) {
        throw 'PortableGit installer hash could not be computed.'
    }

    $actualHash = $hash.Hash.ToUpperInvariant()
    $expectedHash = $ExpectedSha256.Trim().ToUpperInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "PortableGit SHA256 mismatch. Expected $expectedHash but got $actualHash."
    }

    Write-Host "PortableGit installer SHA256 verified ($actualHash)."
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args,
        [switch]$IgnoreExitCode
    )

    & $script:gitExe @Args
    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "Git command failed ($exitCode): git $($Args -join ' ')"
    }

    return $exitCode
}

function Invoke-FastDownload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($null -ne $curl) {
        & $curl.Source --fail --location --retry 3 --retry-delay 2 --output $OutFile $Url
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $OutFile)) {
            return
        }

        Write-Host 'curl.exe download failed; falling back to Invoke-WebRequest...'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Url -OutFile $OutFile
}

function Assert-SafeTargetDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $megaMekJarPath = Join-Path $TargetPath 'MegaMek.jar'
    if (Test-Path -LiteralPath $megaMekJarPath -PathType Leaf) {
        return
    }

    $scriptName = Split-Path -Leaf $PSCommandPath
    $entries = @(Get-ChildItem -LiteralPath $TargetPath -Force | Where-Object { $_.Name -ne $scriptName })
    if ($entries.Count -eq 0) {
        return
    }

    Write-Warning "Safety check failed for '$TargetPath'."
    Write-Warning 'Folder is not empty and MegaMek.jar is missing.'
    Read-Host 'Aborting to avoid writing files into an unexpected location. Press Enter to continue'
    throw 'Aborted by safety check. Run from an empty folder or one containing MegaMek.jar.'
}

try {
    Assert-SafeTargetDirectory -TargetPath (Get-Location).Path

    if (-not (Test-Path -LiteralPath $gitExe)) {
        Write-Host "Bundled Git not found at '$gitExe'. Downloading PortableGit..."

        $tmpInstaller = Join-Path $env:TEMP ("PortableGit-" + [Guid]::NewGuid().ToString('N') + ".7z.exe")

        try {
            Invoke-FastDownload -Url $gitUrl -OutFile $tmpInstaller
            Test-PortableGitInstaller -InstallerPath $tmpInstaller -ExpectedSha256 $portableGitSha256

            if (Test-Path -LiteralPath $gitDir) {
                Remove-Item -LiteralPath $gitDir -Recurse -Force
            }

            New-Item -ItemType Directory -Path $gitDir -Force | Out-Null

            $extractArgs = @('-y', "-o$gitDir")
            $proc = Start-Process -FilePath $tmpInstaller -ArgumentList $extractArgs -Wait -PassThru -NoNewWindow

            if ($proc.ExitCode -ne 0) {
                throw "PortableGit extractor failed with exit code $($proc.ExitCode)."
            }
        }
        finally {
            Remove-Item -LiteralPath $tmpInstaller -Force -ErrorAction SilentlyContinue
        }

        if (-not (Test-Path -LiteralPath $gitExe)) {
            throw "Git bootstrap failed: '$gitExe' was not created."
        }

        Write-Host "PortableGit extracted successfully to '$gitDir'."
    }

    if (Test-Path -LiteralPath '.git/index.lock') {
        Write-Host 'Removing stale Git lock file...'
        Remove-Item -LiteralPath '.git/index.lock' -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path -LiteralPath '.git')) {
        Write-Host 'No Git repository found. Initializing repository in current folder...'
        Invoke-Git -Args @('init', '-q') | Out-Null
    }
    else {
        Write-Host 'Existing Git repository detected in current folder.'
    }

    $originUrl = $null
    try {
        $originUrl = (& $gitExe remote get-url origin 2>$null)
        if ($LASTEXITCODE -ne 0) {
            $originUrl = $null
        }
    }
    catch {
        $originUrl = $null
    }

    if ([string]::IsNullOrWhiteSpace($originUrl)) {
        Write-Host 'Adding origin remote...'
        Invoke-Git -Args @('remote', 'add', 'origin', $repoUrl) | Out-Null
    }
    elseif ($originUrl.Trim().ToLowerInvariant() -ne $repoUrl.ToLowerInvariant()) {
        Write-Warning "Origin currently points to '$($originUrl.Trim())'."
        $retargetConfirmation = Read-Host "Retarget origin to '$repoUrl'? Type YES to continue"
        if ($retargetConfirmation -cne 'YES') {
            throw 'Aborted by user. Origin was not retargeted.'
        }

        Write-Host 'Updating origin remote URL...'
        Invoke-Git -Args @('remote', 'set-url', 'origin', $repoUrl) | Out-Null
    }

    Invoke-Git -Args @('merge', '--abort') -IgnoreExitCode | Out-Null
    Invoke-Git -Args @('rebase', '--abort') -IgnoreExitCode | Out-Null

    Write-Host 'Fetching latest changes from origin...'
    Invoke-Git -Args @('fetch', 'origin', '--prune', '--quiet') | Out-Null

    Invoke-Git -Args @('remote', 'set-head', 'origin', '-a') -IgnoreExitCode | Out-Null

    $remoteHead = (& $gitExe rev-parse --verify origin/HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteHead)) {
        throw 'Error: Could not resolve origin/HEAD. Remote default branch may be unavailable.'
    }

    $originMaster = (& $gitExe rev-parse --verify origin/master 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($originMaster)) {
        Write-Host 'Checking out local master branch from origin/master...'
        Invoke-Git -Args @('checkout', '-B', 'master', 'origin/master') | Out-Null

        Write-Host 'Setting upstream for local master to origin/master...'
        Invoke-Git -Args @('branch', '--set-upstream-to=origin/master', 'master') | Out-Null

        Write-Host 'Forcing local master to match origin/master...'
        Invoke-Git -Args @('reset', '--hard', 'origin/master') | Out-Null
    }
    else {
        Write-Host 'origin/master not found. Forcing local repository to match remote default branch...'
        Invoke-Git -Args @('reset', '--hard', 'origin/HEAD') | Out-Null
    }

    Invoke-Git -Args @('submodule', 'update', '--init', '--recursive') -IgnoreExitCode | Out-Null

    Write-Host 'Repository is now synced to remote successfully.'
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

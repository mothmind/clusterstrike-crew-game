Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$javaUrl = 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jre_x64_windows_hotspot_21.0.12.1_1.zip'
$javaDir = Join-Path $PSScriptRoot '_java'
$requiredJavaMajor = 21

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

function Get-PortableJavaExePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath
  )

  if (-not (Test-Path -LiteralPath $BasePath)) {
    return $null
  }

  $javaExe = Get-ChildItem -LiteralPath $BasePath -Recurse -File -Filter 'java.exe' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\bin\\java\.exe$' } |
  Select-Object -First 1

  if ($null -eq $javaExe) {
    return $null
  }

  return $javaExe.FullName
}

function Get-PortableJavaMajorVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$JavaExePath
  )

  $releaseFile = Join-Path (Split-Path -Parent (Split-Path -Parent $JavaExePath)) 'release'
  if (Test-Path -LiteralPath $releaseFile) {
    $line = Get-Content -LiteralPath $releaseFile | Where-Object { $_ -match '^JAVA_VERSION="?(\d+)' } | Select-Object -First 1
    if ($null -ne $line -and $line -match '^JAVA_VERSION="?(\d+)') {
      return [int]$Matches[1]
    }
  }

  try {
    $versionOutput = (& $JavaExePath -version 2>&1 | Out-String)
    if ($versionOutput -match 'version "(\d+)') {
      return [int]$Matches[1]
    }
  }
  catch {
  }

  return 0
}

function Normalize-PortableJavaLayout {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath
  )

  if (-not (Test-Path -LiteralPath $BasePath)) {
    return
  }

  $entries = @(Get-ChildItem -LiteralPath $BasePath -Force)
  if ($entries.Count -ne 1 -or -not $entries[0].PSIsContainer) {
    return
  }

  $nestedRoot = $entries[0]
  $nestedEntries = @(Get-ChildItem -LiteralPath $nestedRoot.FullName -Force)
  foreach ($entry in $nestedEntries) {
    Move-Item -LiteralPath $entry.FullName -Destination $BasePath -Force
  }

  Remove-Item -LiteralPath $nestedRoot.FullName -Recurse -Force
}

function Ensure-PortableJava {
  Normalize-PortableJavaLayout -BasePath $javaDir

  $existingJavaExe = Get-PortableJavaExePath -BasePath $javaDir
  if (-not [string]::IsNullOrWhiteSpace($existingJavaExe)) {
    $existingMajor = Get-PortableJavaMajorVersion -JavaExePath $existingJavaExe
    if ($existingMajor -ge $requiredJavaMajor) {
      Write-Host "Portable Java $existingMajor already present at '$existingJavaExe'."
      return
    }

    Write-Host "Portable Java $existingMajor at '$existingJavaExe' is too old (need $requiredJavaMajor). Replacing it..."
  }
  else {
    Write-Host "Portable Java not found in '$javaDir'."
  }

  Write-Host "Downloading Java $requiredJavaMajor runtime..."
  $tmpJavaZip = Join-Path $env:TEMP ("PortableJava$requiredJavaMajor-" + [Guid]::NewGuid().ToString('N') + ".zip")
  $tmpJavaExtractDir = Join-Path $env:TEMP ("PortableJava$requiredJavaMajor-extract-" + [Guid]::NewGuid().ToString('N'))

  try {
    Invoke-FastDownload -Url $javaUrl -OutFile $tmpJavaZip

    try {
      Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
      $zip = [System.IO.Compression.ZipFile]::OpenRead($tmpJavaZip)
      $zip.Dispose()
    }
    catch {
      throw "Java download did not produce a valid ZIP archive at '$tmpJavaZip'."
    }

    if (Test-Path -LiteralPath $javaDir) {
      Remove-Item -LiteralPath $javaDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
    New-Item -ItemType Directory -Path $tmpJavaExtractDir -Force | Out-Null
    Expand-Archive -LiteralPath $tmpJavaZip -DestinationPath $tmpJavaExtractDir -Force

    $extractedEntries = @(Get-ChildItem -LiteralPath $tmpJavaExtractDir -Force)
    if ($extractedEntries.Count -eq 1 -and $extractedEntries[0].PSIsContainer) {
      $sourceEntries = @(Get-ChildItem -LiteralPath $extractedEntries[0].FullName -Force)
    }
    else {
      $sourceEntries = $extractedEntries
    }

    foreach ($entry in $sourceEntries) {
      Move-Item -LiteralPath $entry.FullName -Destination $javaDir -Force
    }

    Normalize-PortableJavaLayout -BasePath $javaDir
  }
  finally {
    Remove-Item -LiteralPath $tmpJavaExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpJavaZip -Force -ErrorAction SilentlyContinue
  }

  $installedJavaExe = Get-PortableJavaExePath -BasePath $javaDir
  if ([string]::IsNullOrWhiteSpace($installedJavaExe)) {
    throw "Java bootstrap failed: java.exe not found under '$javaDir' after extraction."
  }

  Write-Host "Portable Java extracted successfully to '$javaDir'."
}


try {
  Ensure-PortableJava
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}

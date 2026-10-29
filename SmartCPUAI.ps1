[CmdletBinding()]
param(
    [switch]$PagefileRepairElevated,
    [switch]$HardwareReportOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:AppRoot = Join-Path $env:LOCALAPPDATA 'SmartCPUAI'
$script:RuntimePath = Join-Path $script:AppRoot 'runtime'
$script:DownloadPath = Join-Path $script:AppRoot 'downloads'
$script:ConfigPath = Join-Path (Join-Path $script:AppRoot 'config') 'settings.json'
$script:LogPath = Join-Path $script:AppRoot 'logs'
$script:LogFile = Join-Path $script:LogPath ('smartcpuai-' + (Get-Date -Format 'yyyyMMdd') + '.log')
$script:Config = $null
$script:RepoCache = @{}

# Curated GGUF MoE catalog. Variant filenames are checked against live Hub metadata
# before they are considered. Model files are downloaded from a pinned repository SHA.
$script:Catalog = @(
    [pscustomobject]@{
        Id = 'qwen3-next-80b-a3b'; Name = 'Qwen3-Next 80B-A3B Instruct'; Repo = 'unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF'
        TotalB = 80; ActiveB = 3; License = 'Apache-2.0 (verify upstream model card)'; Source = 'Unsloth GGUF quantization of Qwen/Qwen3-Next-80B-A3B-Instruct'
        Variants = @(
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-UD-TQ1_0.gguf'; Quant = 'UD-TQ1_0'; Quality = 1; ExperimentalOnly = $true }
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-UD-IQ1_S.gguf'; Quant = 'UD-IQ1_S'; Quality = 1; ExperimentalOnly = $true }
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-UD-IQ1_M.gguf'; Quant = 'UD-IQ1_M'; Quality = 1; ExperimentalOnly = $true }
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-Q2_K.gguf'; Quant = 'Q2_K'; Quality = 2; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-Q3_K_M.gguf'; Quant = 'Q3_K_M'; Quality = 3; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf'; Quant = 'Q4_K_M'; Quality = 4; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-Q5_K_M.gguf'; Quant = 'Q5_K_M'; Quality = 5; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-Q6_K.gguf'; Quant = 'Q6_K'; Quality = 6; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Next-80B-A3B-Instruct-Q8_0.gguf'; Quant = 'Q8_0'; Quality = 8; ExperimentalOnly = $false }
        )
    },
    [pscustomobject]@{
        Id = 'qwen3-coder-30b-a3b'; Name = 'Qwen3-Coder 30B-A3B Instruct'; Repo = 'unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF'
        TotalB = 30; ActiveB = 3; License = 'Apache-2.0 (verify upstream model card)'; Source = 'GGUF conversion of Qwen/Qwen3-Coder-30B-A3B-Instruct; coding-oriented model'
        Variants = @(
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-UD-TQ1_0.gguf'; Quant = 'UD-TQ1_0'; Quality = 1; ExperimentalOnly = $true }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-UD-IQ1_S.gguf'; Quant = 'UD-IQ1_S'; Quality = 1; ExperimentalOnly = $true }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-UD-IQ1_M.gguf'; Quant = 'UD-IQ1_M'; Quality = 1; ExperimentalOnly = $true }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf'; Quant = 'Q2_K'; Quality = 2; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q3_K_S.gguf'; Quant = 'Q3_K_S'; Quality = 3; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q3_K_M.gguf'; Quant = 'Q3_K_M'; Quality = 3.5; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q4_K_S.gguf'; Quant = 'Q4_K_S'; Quality = 4; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf'; Quant = 'Q4_K_M'; Quality = 4.5; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q5_K_S.gguf'; Quant = 'Q5_K_S'; Quality = 5; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q5_K_M.gguf'; Quant = 'Q5_K_M'; Quality = 5.5; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q6_K.gguf'; Quant = 'Q6_K'; Quality = 6; ExperimentalOnly = $false }
            [pscustomobject]@{ File = 'Qwen3-Coder-30B-A3B-Instruct-Q8_0.gguf'; Quant = 'Q8_0'; Quality = 8; ExperimentalOnly = $false }
        )
    },
    [pscustomobject]@{
        Id = 'gpt-oss-20b'; Name = 'gpt-oss 20B'; Repo = 'ggml-org/gpt-oss-20b-GGUF'
        TotalB = 21; ActiveB = 3.6; License = 'Apache-2.0'; Source = 'GGUF/MXFP4 conversion of openai/gpt-oss-20b'
        Variants = @(
            [pscustomobject]@{ File = 'gpt-oss-20b-mxfp4.gguf'; Quant = 'MXFP4'; Quality = 4; ExperimentalOnly = $false }
        )
        UseJinja = $true
    }
)

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    try {
        if (-not (Test-Path $script:LogPath)) { New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null }
        $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
    } catch { }
}
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan; Write-Log $Message }
function Write-Ok { param([string]$Message) Write-Host $Message -ForegroundColor Green; Write-Log $Message }
function Write-Warn { param([string]$Message) Write-Host ('WARNING: ' + $Message) -ForegroundColor Yellow; Write-Log $Message 'WARN' }
function Write-Fail { param([string]$Message) Write-Host ('ERROR: ' + $Message) -ForegroundColor Red; Write-Log $Message 'ERROR' }
function Wait-Key { Write-Host ''; [void](Read-Host 'Press Enter to continue') }

function Get-DefaultConfig {
    return [pscustomobject]@{
        ReservePercent = 20
        Mode = 'Balanced'
        ContextTokens = 2048
        Threads = 0
        ModelPath = (Join-Path $script:AppRoot 'models')
        Port = 8080
        VerifySha256 = $true
        AutoOpenBrowser = $true
        SelectedModelId = ''
        SelectedModelFile = ''
        StartupTimeoutSeconds = 300
    }
}
function Save-Config {
    $parent = Split-Path -Parent $script:ConfigPath
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $script:Config | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
    Write-Log 'Settings saved.'
}
function Load-Config {
    $defaults = Get-DefaultConfig
    if (Test-Path $script:ConfigPath) {
        try {
            $old = Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $old.PSObject.Properties) {
                if ($defaults.PSObject.Properties.Name -contains $p.Name) {
                    $defaults.PSObject.Properties[$p.Name].Value = $p.Value
                }
            }
        } catch {
            Write-Warn 'Settings file was unreadable. A fresh configuration will be created; the old file is left in place.'
            try { Copy-Item -LiteralPath $script:ConfigPath -Destination ($script:ConfigPath + '.corrupt-' + (Get-Date -Format 'yyyyMMddHHmmss')) -ErrorAction SilentlyContinue } catch { }
        }
    }
    if ([int]$defaults.ReservePercent -lt 10 -or [int]$defaults.ReservePercent -gt 40) { $defaults.ReservePercent = 20 }
    if (@('Balanced','Experimental') -notcontains [string]$defaults.Mode) { $defaults.Mode = 'Balanced' }
    if (@(2048,4096,8192,16384) -notcontains [int]$defaults.ContextTokens) { $defaults.ContextTokens = 2048 }
    if ([int]$defaults.Port -lt 1024 -or [int]$defaults.Port -gt 65535) { $defaults.Port = 8080 }
    if ([string]::IsNullOrWhiteSpace([string]$defaults.ModelPath)) { $defaults.ModelPath = Join-Path $script:AppRoot 'models' }
    $script:Config = $defaults
}
function Initialize-Folders {
    foreach ($path in @($script:AppRoot, $script:RuntimePath, $script:DownloadPath, $script:LogPath, (Split-Path -Parent $script:ConfigPath), [string]$script:Config.ModelPath)) {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    }
    if (-not (Test-Path $script:ConfigPath)) { Save-Config }
}
function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}
function Get-Architecture {
    param($Cpu)
    try {
        switch ([int]$Cpu.Architecture) {
            9 { return 'x64' }
            12 { return 'ARM64' }
            0 { return 'x86' }
            5 { return 'ARM' }
        }
    } catch { }
    $envArch = [string]$env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $envArch = [string]$env:PROCESSOR_ARCHITEW6432 }
    if ($envArch -match 'ARM64') { return 'ARM64' }
    if ($envArch -match 'AMD64') { return 'x64' }
    if ($envArch -match '86') { return 'x86' }
    return 'Unknown'
}
function Get-DriveMediaType {
    param([string]$Path)
    try {
        $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
        if ($root -match '^([A-Za-z]):\\$') {
            $letter = $Matches[1]
            $partition = Get-Partition -DriveLetter $letter -ErrorAction Stop | Select-Object -First 1
            $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
            $media = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.FriendlyName -eq $disk.FriendlyName } | Select-Object -First 1
            if ($media -and [string]$media.MediaType -ne 'Unspecified') { return [string]$media.MediaType }
            if ($disk.BusType -eq 'NVMe' -or $disk.BusType -eq 'SSD') { return 'SSD/NVMe (inferred)' }
            if ($disk.BusType -eq 'USB') { return 'USB (media type unknown)' }
        }
    } catch { }
    return 'Unknown (not exposed by Windows or access denied)'
}
function Get-HardwareReport {
    Write-Info 'Inspecting Windows and hardware...'
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $processors = @(Get-CimInstance -ClassName Win32_Processor)
    $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue)
    $cpu = $processors | Select-Object -First 1
    $physicalCores = 0; $logicalProcessors = 0; $clock = 0
    foreach ($p in $processors) {
        $physicalCores += [int]$p.NumberOfCores
        $logicalProcessors += [int]$p.NumberOfLogicalProcessors
        if ([int]$p.MaxClockSpeed -gt $clock) { $clock = [int]$p.MaxClockSpeed }
    }
    $totalGB = [math]::Round(([double]$cs.TotalPhysicalMemory / 1GB), 2)
    $freeGB = [math]::Round(([double]$os.FreePhysicalMemory * 1KB / 1GB), 2)
    $arch = Get-Architecture -Cpu $cpu
    $isWindows11 = ([string]$os.Caption -match 'Windows 11') -or ([int]$os.BuildNumber -ge 22000)
    $pageAuto = 'Unknown'
    try { $pageAuto = [string](Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile } catch { }
    $pageUsage = @()
    try { $pageUsage = @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{ Name=$_.Name; AllocatedMB=$_.AllocatedBaseSize; CurrentUsageMB=$_.CurrentUsage; PeakUsageMB=$_.PeakUsage } }) } catch { }
    $modelDriveFree = $null; $mediaType = Get-DriveMediaType -Path ([string]$script:Config.ModelPath)
    try { $rootPath = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath([string]$script:Config.ModelPath)); $di = [System.IO.DriveInfo]::new($rootPath); $modelDriveFree = [math]::Round(($di.AvailableFreeSpace / 1GB), 2) } catch { }
    $gpuNames = @($gpus | ForEach-Object { [string]$_.Name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $report = [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        Manufacturer = [string]$cs.Manufacturer
        SystemModel = [string]$cs.Model
        WindowsCaption = [string]$os.Caption
        WindowsVersion = [string]$os.Version
        WindowsBuild = [string]$os.BuildNumber
        Architecture = $arch
        CPUName = [string]$cpu.Name
        CPUManufacturer = [string]$cpu.Manufacturer
        CPUMaxClockMHz = $clock
        PhysicalCores = $physicalCores
        LogicalProcessors = $logicalProcessors
        InstalledRAM_GB = $totalGB
        AvailableRAM_GB = $freeGB
        GPUs = $gpuNames
        PageFileAutomaticManaged = $pageAuto
        PageFiles = $pageUsage
        ModelStoragePath = [string]$script:Config.ModelPath
        ModelDriveFreeGB = $modelDriveFree
        ModelDriveType = $mediaType
        ReservePercent = [int]$script:Config.ReservePercent
        Mode = [string]$script:Config.Mode
    }
    $reportFile = Join-Path $script:LogPath 'hardware-report.json'
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportFile -Encoding UTF8
    Write-Host ''
    Write-Host '================ SMART CPU AI: HARDWARE REPORT ================' -ForegroundColor White
    Write-Host ('Computer:       {0} / {1}' -f $report.Manufacturer, $report.SystemModel)
    Write-Host ('Windows:        {0}, version {1}, build {2}' -f $report.WindowsCaption, $report.WindowsVersion, $report.WindowsBuild)
    Write-Host ('Architecture:   {0}' -f $report.Architecture)
    Write-Host ('CPU:            {0}' -f $report.CPUName)
    Write-Host ('CPU max clock:  {0} MHz (reported nominal max)' -f $report.CPUMaxClockMHz)
    Write-Host ('Cores/threads:  {0} physical / {1} logical' -f $report.PhysicalCores, $report.LogicalProcessors)
    Write-Host ('RAM:            {0} GB installed / {1} GB currently available' -f $report.InstalledRAM_GB, $report.AvailableRAM_GB)
    Write-Host ('GPU(s):         {0}' -f ($(if ($gpuNames.Count) { $gpuNames -join '; ' } else { 'None detected / not reported' })))
    Write-Host ('Page file auto: {0}' -f $report.PageFileAutomaticManaged)
    if ($null -ne $modelDriveFree) { Write-Host ('Model drive:    {0} GB free / {1}' -f $modelDriveFree, $mediaType) }
    else { Write-Host ('Model drive:    Free space unavailable / {0}' -f $mediaType) }
    Write-Host ('RAM reserve:    {0}% | Mode: {1} | Context: {2} tokens' -f $script:Config.ReservePercent, $script:Config.Mode, $script:Config.ContextTokens)
    Write-Host ('Report saved:   {0}' -f $reportFile)
    Write-Host '==============================================================='
    Write-Log ('Hardware report generated. Architecture={0}; RAM={1} GB; available={2} GB.' -f $arch, $totalGB, $freeGB)
    if ($arch -notin @('x64','ARM64')) { Write-Warn "Architecture '$arch' is not in the supported runtime targets for this build." }
    if ([string]$os.Caption -match 'Windows 10') { Write-Warn 'Windows 10 standard support ended on October 14, 2025. Check whether the PC is enrolled in an applicable extended security updates program.' }
    return $report
}
function Get-GitHubCpuAssetFromWebPage {
    param(
        [Parameter(Mandatory=$true)][string]$Architecture,
        [string]$ApiError = ''
    )
    # This is intentionally a fallback: the public HTML release pages do not expose
    # the same structured integrity metadata as the REST API. When used, we still
    # validate the download size when HEAD exposes it, ZIP structure, and --version.
    $assetPattern = if ($Architecture -eq 'ARM64') { 'win-cpu-arm64.*\.zip$' } else { 'win-cpu-x64.*\.zip$' }
    $headers = @{ 'User-Agent'='SmartCPUAI/0.2'; 'Accept'='text/html,application/xhtml+xml' }
    try {
        Write-Info 'Trying GitHub public releases webpage fallback (no REST API token needed)...'
        $releasePage = Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/ggml-org/llama.cpp/releases' -Headers $headers -TimeoutSec 30
        $tagMatches = [regex]::Matches([string]$releasePage.Content, 'href=["''][/]?ggml-org/llama\.cpp/releases/tag/(?<tag>[^"''/?#]+)')
        $tags = New-Object System.Collections.Generic.List[string]
        $seenTags = @{}
        foreach ($match in $tagMatches) {
            $tag = [System.Uri]::UnescapeDataString([string]$match.Groups['tag'].Value)
            if (-not [string]::IsNullOrWhiteSpace($tag) -and -not $seenTags.ContainsKey($tag)) {
                $seenTags[$tag] = $true
                $tags.Add($tag)
            }
        }
        if ($tags.Count -eq 0) { throw 'Could not identify release tags on GitHub public releases page.' }

        foreach ($tag in $tags) {
            $assetsUrl = 'https://github.com/ggml-org/llama.cpp/releases/expanded_assets/' + [uri]::EscapeDataString($tag)
            try {
                $assetPage = Invoke-WebRequest -UseBasicParsing -Uri $assetsUrl -Headers $headers -TimeoutSec 30
            } catch { continue }
            $assetMatches = [regex]::Matches([string]$assetPage.Content, 'href=["''](?<href>/ggml-org/llama\.cpp/releases/download/(?<tag>[^/"'']+)/(?<name>[^/"''?]+\.zip))["'']')
            foreach ($assetMatch in $assetMatches) {
                $name = [System.Uri]::UnescapeDataString([string]$assetMatch.Groups['name'].Value)
                if ($name -notmatch $assetPattern) { continue }
                $downloadTag = [System.Uri]::UnescapeDataString([string]$assetMatch.Groups['tag'].Value)
                if ($downloadTag -ne $tag) { continue }
                $url = 'https://github.com' + [string]$assetMatch.Groups['href'].Value
                $sizeBytes = 0L
                try {
                    $head = Invoke-WebRequest -UseBasicParsing -Method Head -Uri $url -Headers @{ 'User-Agent'='SmartCPUAI/0.2'; 'Accept'='application/octet-stream' } -MaximumRedirection 10 -TimeoutSec 30
                    $lengthHeader = [string]$head.Headers['Content-Length']
                    $parsedLength = 0L
                    if ([long]::TryParse($lengthHeader, [ref]$parsedLength) -and $parsedLength -gt 0) { $sizeBytes = $parsedLength }
                } catch { }
                if ($sizeBytes -le 0) {
                    Write-Warn 'GitHub REST API is unavailable and the webpage did not expose the runtime size. The archive will still be checked as a ZIP and must pass llama-server --version, but exact byte-count/SHA-256 verification is unavailable for this fallback download.'
                }
                return [pscustomobject]@{
                    Version=$tag; Name=$name; Url=$url; SizeBytes=[long]$sizeBytes; Digest=''; Source='web-fallback'
                }
            }
        }
        throw "No Windows CPU ZIP asset was found in the public release pages for architecture $Architecture."
    } catch {
        $webError = $_.Exception.Message
        $apiDetail = if ($ApiError) { " REST API error: $ApiError" } else { '' }
        throw "Could not locate the llama.cpp Windows CPU runtime. GitHub REST API and webpage fallback failed. This is a GitHub/network access issue, not an AMD CPU or Windows 10 compatibility error. Check https://github.com/ggml-org/llama.cpp/releases and retry later.$apiDetail Web fallback error: $webError"
    }
}
function Get-GitHubCpuAsset {
    param([string]$Architecture)
    $assetPattern = if ($Architecture -eq 'ARM64') { 'win-cpu-arm64.*\.zip$' } else { 'win-cpu-x64.*\.zip$' }
    Write-Info "Checking latest llama.cpp CPU release for Windows $Architecture..."
    $apiError = ''
    try {
        $releaseList = Invoke-RestMethod -Uri 'https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=20' -Headers @{ 'User-Agent'='SmartCPUAI/0.2'; 'Accept'='application/vnd.github+json' } -TimeoutSec 30 -ErrorAction Stop
        foreach ($release in @($releaseList)) {
            $assets = @($release.assets | Where-Object { $_.name -match $assetPattern })
            if ($assets.Count -gt 0) {
                $asset = $assets | Sort-Object size -Descending | Select-Object -First 1
                return [pscustomobject]@{ Version=[string]$release.tag_name; Name=[string]$asset.name; Url=[string]$asset.browser_download_url; SizeBytes=[long]$asset.size; Digest=[string]$asset.digest; Source='api' }
            }
        }
        $apiError = 'The API returned no matching CPU ZIP asset among the latest 20 releases.'
    } catch {
        $apiError = $_.Exception.Message
    }
    Write-Warn "GitHub REST API lookup failed ($apiError). Using webpage fallback. A 403 can mean the unauthenticated API rate limit has been reached; the AMD processor and Windows 10 warning are not the cause."
    return Get-GitHubCpuAssetFromWebPage -Architecture $Architecture -ApiError $apiError
}
function Ensure-Runtime {
    param([string]$Architecture)
    $server = Get-ChildItem -LiteralPath $script:RuntimePath -Filter 'llama-server.exe' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($server) {
        try {
            Remove-Item -LiteralPath (Join-Path $script:LogPath 'runtime-version.txt') -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath (Join-Path $script:LogPath 'runtime-version-error.txt') -Force -ErrorAction SilentlyContinue
            $test = Start-Process -FilePath $server.FullName -ArgumentList '--version' -WorkingDirectory $server.DirectoryName -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput (Join-Path $script:LogPath 'runtime-version.txt') -RedirectStandardError (Join-Path $script:LogPath 'runtime-version-error.txt')
            if ($test.ExitCode -eq 0) { Write-Ok ('Runtime already installed: ' + $server.FullName); return $server.FullName }
        } catch { Write-Warn 'Existing runtime did not pass the version check; it will be replaced.' }
    }
    $arch = $Architecture
    if ($arch -notin @('x64','ARM64')) { throw "Unsupported OS/CPU architecture '$arch'. Supported targets are Windows x64 and Windows ARM64 with matching CPU builds." }
    $asset = Get-GitHubCpuAsset -Architecture $arch
    if ([long]$asset.SizeBytes -gt 0) { Write-Info ('Selected runtime {0} ({1:N0} MB; source: {2}).' -f $asset.Version, ($asset.SizeBytes / 1MB), $asset.Source) }
    else { Write-Info ('Selected runtime {0} (size unavailable from GitHub fallback; source: {1}).' -f $asset.Version, $asset.Source) }
    $zipPath = Join-Path $script:DownloadPath $asset.Name
    $extractPath = Join-Path $script:DownloadPath ('runtime-extract-' + [guid]::NewGuid().ToString('N'))
    try {
        $downloadRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($script:DownloadPath))
        $downloadDrive = [System.IO.DriveInfo]::new($downloadRoot)
        if (-not (Test-Path $zipPath) -and $downloadDrive.AvailableFreeSpace -lt ($asset.SizeBytes + 1GB)) { throw 'Not enough free space to download and extract the CPU runtime. Free at least 1 GB more space on the Windows user profile drive.' }
    } catch { if ($_.Exception.Message -like 'Not enough free space*') { throw } }

    if (Test-Path $zipPath) {
        if ([long]$asset.SizeBytes -gt 0 -and (Get-Item -LiteralPath $zipPath).Length -ne [long]$asset.SizeBytes) { Remove-Item -LiteralPath $zipPath -Force }
        elseif ([long]$asset.SizeBytes -le 0) { Write-Warn 'Cached runtime archive size cannot be compared to GitHub metadata; archive extraction and llama-server --version will validate it.' }
        elseif ([string]$asset.Digest -match '^sha256:([a-fA-F0-9]{64})$') {
            $existingRuntimeHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
            if ($existingRuntimeHash -ine $Matches[1]) { Write-Warn 'Cached runtime archive checksum is incorrect; redownloading.'; Remove-Item -LiteralPath $zipPath -Force }
        }
    }
    if (-not (Test-Path $zipPath)) { Download-File -Url $asset.Url -Destination $zipPath -ExpectedBytes $asset.SizeBytes -Sha256 (($asset.Digest -replace '^sha256:','')) -VerifyHash $true }
    if (Test-Path $script:RuntimePath) { Get-ChildItem -LiteralPath $script:RuntimePath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
        $found = Get-ChildItem -LiteralPath $extractPath -Filter 'llama-server.exe' -Recurse -File | Select-Object -First 1
        if (-not $found) { throw 'The downloaded archive did not contain llama-server.exe.' }
        Copy-Item -Path (Join-Path $found.DirectoryName '*') -Destination $script:RuntimePath -Recurse -Force
        $finalServer = Join-Path $script:RuntimePath 'llama-server.exe'
        if (-not (Test-Path $finalServer)) {
            $moved = Get-ChildItem -LiteralPath $script:RuntimePath -Filter 'llama-server.exe' -Recurse -File | Select-Object -First 1
            if (-not $moved) { throw 'Runtime extraction completed, but llama-server.exe could not be found.' }
            $finalServer = $moved.FullName
        }
        Remove-Item -LiteralPath (Join-Path $script:LogPath 'runtime-version.txt') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $script:LogPath 'runtime-version-error.txt') -Force -ErrorAction SilentlyContinue
        $version = Start-Process -FilePath $finalServer -ArgumentList '--version' -WorkingDirectory (Split-Path -Parent $finalServer) -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput (Join-Path $script:LogPath 'runtime-version.txt') -RedirectStandardError (Join-Path $script:LogPath 'runtime-version-error.txt')
        if ($version.ExitCode -ne 0) { throw "llama-server.exe version check failed with exit code $($version.ExitCode). See $script:LogPath." }
        $script:RuntimeVersion = $asset.Version
        Write-Ok ('CPU runtime installed: ' + $asset.Version)
        Write-Log ('Installed runtime ' + $asset.Version + ' from ' + $asset.Url)
        return $finalServer
    } finally {
        Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
function Download-File {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination,
        [long]$ExpectedBytes = 0,
        [string]$Sha256 = '',
        [bool]$VerifyHash = $false
    )
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $partial = $Destination + '.partial'
    $partialComplete = $false
    if ((Test-Path $partial) -and $ExpectedBytes -gt 0) {
        $partialBytes = (Get-Item -LiteralPath $partial).Length
        if ($partialBytes -gt $ExpectedBytes) { Remove-Item -LiteralPath $partial -Force }
        elseif ($partialBytes -eq $ExpectedBytes) { $partialComplete = $true }
    }
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $partialComplete) {
        if ($curl) {
            $curlArgs = @('--fail','--location','--retry','3','--retry-delay','2','--connect-timeout','30','--continue-at','-','--output',$partial,$Url)
            Write-Info ('Downloading: ' + [IO.Path]::GetFileName($Destination))
            & $curl.Source @curlArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "curl.exe returned exit code $LASTEXITCODE. The partial file is retained so a later attempt may resume it."
                throw "Download failed for $Url (curl exit $LASTEXITCODE). Check internet access and the logs, then retry."
            }
        } else {
            Write-Warn 'curl.exe was not found. Using Windows PowerShell web download (resume is unavailable in this fallback).'
            Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $partial -TimeoutSec 0
        }
    } else { Write-Info 'The partial file already has the expected length; validating it without redownloading.' }
    if (-not (Test-Path $partial)) { throw 'Download ended without creating a file.' }
    $actualBytes = (Get-Item -LiteralPath $partial).Length
    if ($ExpectedBytes -gt 0 -and $actualBytes -ne $ExpectedBytes) {
        throw "Downloaded file size mismatch: expected $ExpectedBytes bytes but received $actualBytes bytes. The partial file is retained for diagnosis/retry."
    }
    if ($VerifyHash -and $Sha256 -match '^[a-fA-F0-9]{64}$') {
        Write-Info 'Verifying SHA-256 checksum (reading the entire file; this can take a while for large models)...'
        $computed = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($computed -ne $Sha256.ToLowerInvariant()) { Remove-Item -LiteralPath $partial -Force; throw 'SHA-256 verification failed. The downloaded file was deleted; please retry.' }
        Write-Ok 'SHA-256 checksum verified.'
    } elseif ($VerifyHash) {
        Write-Warn 'No SHA-256 digest was published for this asset; HTTPS and exact file-size validation were used, but cryptographic file verification was unavailable.'
    }
    Move-Item -LiteralPath $partial -Destination $Destination -Force
    Write-Ok ('Download validated: ' + [IO.Path]::GetFileName($Destination))
}
function Get-RepoMetadata {
    param([string]$Repo)
    if ($script:RepoCache.ContainsKey($Repo)) { return $script:RepoCache[$Repo] }
    $uri = 'https://huggingface.co/api/models/' + $Repo + '?blobs=true'
    $metadata = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent'='SmartCPUAI/0.1' } -TimeoutSec 45
    if (-not $metadata.sha -or -not $metadata.siblings) { throw "Hub metadata for '$Repo' was incomplete." }
    $script:RepoCache[$Repo] = $metadata
    return $metadata
}
function Get-LiveCatalog {
    Write-Info 'Checking the curated MoE catalog against Hugging Face metadata...'
    $all = New-Object System.Collections.Generic.List[object]
    foreach ($model in $script:Catalog) {
        try {
            $metadata = Get-RepoMetadata -Repo $model.Repo
            foreach ($variant in $model.Variants) {
                $sibling = @($metadata.siblings | Where-Object { [string]$_.rfilename -eq [string]$variant.File } | Select-Object -First 1)
                if ($sibling.Count -eq 0) { continue }
                $fileInfo = $sibling[0]
                $bytes = 0L
                if ($fileInfo.lfs -and $null -ne $fileInfo.lfs.size -and [long]$fileInfo.lfs.size -gt 0) { $bytes = [long]$fileInfo.lfs.size }
                elseif ($null -ne $fileInfo.size -and [long]$fileInfo.size -gt 0) { $bytes = [long]$fileInfo.size }
                if ($bytes -le 0) { continue }
                $sha = ''
                if ($fileInfo.lfs -and $fileInfo.lfs.oid) { $sha = [string]$fileInfo.lfs.oid -replace '^sha256:','' }
                elseif ($fileInfo.lfs -and $fileInfo.lfs.sha256) { $sha = [string]$fileInfo.lfs.sha256 }
                $license = [string]$model.License
                if ($metadata.cardData -and $metadata.cardData.license) { $license = [string]$metadata.cardData.license }
                $url = 'https://huggingface.co/{0}/resolve/{1}/{2}?download=true' -f $model.Repo, [string]$metadata.sha, [string]$variant.File
                $sizeGB = [double]$bytes / 1GB
                $overhead = [math]::Max(2.0, $sizeGB * 0.04) + (([int]$script:Config.ContextTokens / 4096.0) * 0.70)
                $neededGB = $sizeGB + $overhead
                $all.Add([pscustomobject]@{
                    Id = [string]$model.Id; Name = [string]$model.Name; Repo = [string]$model.Repo; File = [string]$variant.File
                    Quant = [string]$variant.Quant; Quality = [double]$variant.Quality; ExperimentalOnly = [bool]$variant.ExperimentalOnly
                    TotalB = [double]$model.TotalB; ActiveB = [double]$model.ActiveB; License = $license; Source = [string]$model.Source
                    SizeBytes = [long]$bytes; SizeGB = $sizeGB; EstimatedWorkingGB = $neededGB; Sha256 = $sha; Url = $url
                    UseJinja = [bool]$model.UseJinja; Revision = [string]$metadata.sha
                })
            }
        } catch { Write-Warn ("Skipping catalog entry '{0}': {1}" -f $model.Name, $_.Exception.Message); Write-Log ('Hub metadata failed for ' + $model.Repo + ': ' + $_.Exception.Message) 'WARN' }
    }
    if ($all.Count -eq 0) { throw 'No catalog files could be verified with Hugging Face. Check internet access or try again later.' }
    # Avoid PowerShell 5.1/7 array-subexpression bug with New-Object List[object].
    # @($all) can throw "Argument types do not match"; ToArray() is safe.
    return $all.ToArray()
}
function Get-MemoryBudget {
    param($Hardware)
    $reserveGB = [double]$Hardware.InstalledRAM_GB * ([int]$script:Config.ReservePercent / 100.0)
    $capacityBudget = [math]::Max(0, [double]$Hardware.InstalledRAM_GB - $reserveGB)
    # Use current available RAM as a lower ceiling, and retain ~1.5 GB for Windows and transient allocations.
    $availableBudget = [math]::Max(0, [double]$Hardware.AvailableRAM_GB - 1.5)
    return [math]::Min($capacityBudget, $availableBudget)
}
function Get-ModelCandidates {
    param([object[]]$Catalog, $Hardware)
    $memoryBudget = Get-MemoryBudget -Hardware $Hardware
    $freeDisk = $null
    try { $rootPath = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath([string]$script:Config.ModelPath)); $di = [System.IO.DriveInfo]::new($rootPath); $freeDisk = [double]$di.AvailableFreeSpace / 1GB } catch { }
    $chosen = New-Object System.Collections.Generic.List[object]
    $maxExperimentalFileGB = [math]::Max(12.0, [double]$Hardware.InstalledRAM_GB * 2.0)
    foreach ($family in @($Catalog | Group-Object -Property Id)) {
        $variants = @($family.Group)
        if ($script:Config.Mode -eq 'Balanced') { $variants = @($variants | Where-Object { -not $_.ExperimentalOnly }) }
        else {
            # Avoid absurd overcommit ratios on very low-memory PCs. Experimental mode can overrun RAM, but caps
            # the initial model file at roughly 2x installed RAM (minimum 12 GB) to avoid selecting a 30+ GB model on 8 GB systems.
            $variants = @($variants | Where-Object { $_.SizeGB -le $maxExperimentalFileGB })
        }
        if ($null -ne $freeDisk) {
            $variants = @($variants | Where-Object {
                $existingPath = Join-Path (Join-Path ([string]$script:Config.ModelPath) ([string]$_.Id)) ([string]$_.File)
                $existingValid = $false
                if (Test-Path -LiteralPath $existingPath) { try { $existingValid = ((Get-Item -LiteralPath $existingPath).Length -eq [long]$_.SizeBytes) } catch { } }
                $existingValid -or (($_.SizeGB + 3.0) -le $freeDisk)
            })
        }
        if ($variants.Count -eq 0) { continue }
        $fits = @($variants | Where-Object { $_.EstimatedWorkingGB -le $memoryBudget } | Sort-Object Quality -Descending)
        if ($fits.Count -gt 0) {
            $pick = $fits[0]
        } elseif ($script:Config.Mode -eq 'Experimental') {
            # If no quant fits the conservative RAM budget, choose the smallest file for this model family.
            $pick = $variants | Sort-Object SizeBytes | Select-Object -First 1
        } else {
            continue
        }
        $pick | Add-Member -NotePropertyName MemoryBudgetGB -NotePropertyValue $memoryBudget -Force
        $pick | Add-Member -NotePropertyName FreeDiskGB -NotePropertyValue $freeDisk -Force
        $chosen.Add($pick)
    }
    return @($chosen | Sort-Object -Property @{ Expression = 'TotalB'; Descending = $true }, @{ Expression = 'Quality'; Descending = $true })
}
function Show-Candidate {
    param($Candidate, [int]$Number)
    $flag = if ($Candidate.EstimatedWorkingGB -le $Candidate.MemoryBudgetGB) { 'estimated to fit reserved RAM budget' } else { 'SSD/page-file experiment; exceeds current RAM budget' }
    Write-Host ('{0}. {1} | {2} | {3:N1} GB | {4} total / {5} active parameters' -f $Number, $Candidate.Name, $Candidate.Quant, $Candidate.SizeGB, $Candidate.TotalB, $Candidate.ActiveB)
    Write-Host ('   Estimate: ~{0:N1} GB working memory; {1}. License metadata: {2}' -f $Candidate.EstimatedWorkingGB, $flag, $Candidate.License) -ForegroundColor DarkGray
}
function Test-ModelSpace {
    param($Candidate)
    try {
        $existing = Join-Path (Join-Path ([string]$script:Config.ModelPath) ([string]$Candidate.Id)) ([string]$Candidate.File)
        if (Test-Path -LiteralPath $existing) { if ((Get-Item -LiteralPath $existing).Length -eq [long]$Candidate.SizeBytes) { return $true } }
        $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath([string]$script:Config.ModelPath))
        $di = [System.IO.DriveInfo]::new($root)
        return ($di.AvailableFreeSpace -ge ($Candidate.SizeBytes + 3GB))
    } catch { return $false }
}
function Get-SelectedCandidate {
    param([object[]]$Candidates)
    if ($Candidates.Count -eq 0) { return $null }
    Write-Host ''
    Write-Host ('Mode: {0}. RAM reserve: {1}%. Context: {2}.' -f $script:Config.Mode, $script:Config.ReservePercent, $script:Config.ContextTokens) -ForegroundColor White
    Write-Host 'Best candidate per model family (ranked by total model size):'
    $i = 1
    foreach ($c in $Candidates) { Show-Candidate -Candidate $c -Number $i; $i++ }
    $best = $Candidates[0]
    Write-Host ''
    Write-Host ('Automatic selection: {0} ({1}).' -f $best.Name, $best.Quant) -ForegroundColor Green
    if ($script:Config.Mode -eq 'Experimental' -and $best.EstimatedWorkingGB -gt $best.MemoryBudgetGB) {
        Write-Warn 'This model is larger than the current conservative RAM budget. Memory mapping is not a guarantee of usable speed or successful startup.'
        Write-Warn 'Generation may be extremely slow, and Windows may become unresponsive if paging becomes excessive.'
        $confirm = Read-Host 'Type EXPERIMENT to download this oversized model, or press Enter to cancel'
        if ($confirm -cne 'EXPERIMENT') { return $null }
    }
    $choice = Read-Host 'Press Enter to use automatic selection, or enter a listed number to choose another'
    if ([string]::IsNullOrWhiteSpace($choice)) { return $best }
    $num = 0
    if ([int]::TryParse($choice, [ref]$num) -and $num -ge 1 -and $num -le $Candidates.Count) { return $Candidates[$num - 1] }
    Write-Warn 'Invalid choice; using automatic selection.'
    return $best
}
function Get-CPUThreads {
    param($Hardware)
    if ([int]$script:Config.Threads -gt 0) { return [int]$script:Config.Threads }
    $cores = [int]$Hardware.PhysicalCores
    if ($cores -le 0) { $cores = [int]$Hardware.LogicalProcessors }
    if ($cores -le 0) { $cores = 2 }
    if ($cores -gt 1) { return ($cores - 1) }
    return 1
}
function Test-PortAvailable {
    param([int]$Port)
    $listener = $null
    try { $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, [int]$Port); $listener.Start(); return $true }
    catch { return $false }
    finally { if ($listener) { try { $listener.Stop() } catch { } } }
}
function Find-FreePort {
    $base = [int]$script:Config.Port
    for ($i = 0; $i -lt 30; $i++) {
        $candidate = $base + $i
        if ($candidate -gt 65535) { break }
        if (Test-PortAvailable -Port $candidate) { return $candidate }
    }
    throw 'Could not find a free localhost port in the configured port range.'
}
function Quote-ProcessArgument {
    param([string]$Value)
    if ($Value -match '[\s"]') { return '"' + ($Value -replace '"','\"') + '"' }
    return $Value
}
function Start-LocalModelServer {
    param([string]$ServerExe, $Candidate, [string]$ModelFile, $Hardware)
    $port = Find-FreePort
    $threads = Get-CPUThreads -Hardware $Hardware
    $argsList = @('-m', $ModelFile, '--host', '127.0.0.1', '--port', [string]$port, '-ngl', '0', '-c', [string]$script:Config.ContextTokens, '-t', [string]$threads, '-tb', [string]$threads)
    if ($Candidate.UseJinja) { $argsList += '--jinja' }
    # No GPU backend/driver is requested. -ngl 0 explicitly disables GPU layer offload.
    $argString = (@($argsList | ForEach-Object { Quote-ProcessArgument -Value ([string]$_) }) -join ' ')
    $outLog = Join-Path $script:LogPath ('server-out-' + $port + '.log')
    $errLog = Join-Path $script:LogPath ('server-err-' + $port + '.log')
    Write-Info ('Launching CPU-only server on http://127.0.0.1:{0} | CPU threads: {1} | context: {2} | GPU layers: 0' -f $port, $threads, $script:Config.ContextTokens)
    Write-Log ('Starting model=' + $Candidate.Name + '; file=' + $ModelFile + '; port=' + $port + '; threads=' + $threads + '; GPU layers=0')
    try {
        $process = Start-Process -FilePath $ServerExe -ArgumentList $argString -WorkingDirectory (Split-Path -Parent $ServerExe) -PassThru -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    } catch {
        Write-Fail ('Could not start llama-server.exe: ' + $_.Exception.Message)
        return [pscustomobject]@{ Success=$false; TimedOut=$false; Process=$null; Url=$null }
    }
    $deadline = (Get-Date).AddSeconds([int]$script:Config.StartupTimeoutSeconds)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri ('http://127.0.0.1:{0}/health' -f $port) -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) { $ready = $true; break }
        } catch { }
        try { $process.Refresh() } catch { }
        if ($process.HasExited) { break }
    }
    $url = 'http://127.0.0.1:' + $port
    if ($ready) {
        Write-Ok ('Model server is responding at ' + $url)
        if ($script:Config.AutoOpenBrowser) { Start-Process $url }
        $script:Config.SelectedModelId = $Candidate.Id
        $script:Config.SelectedModelFile = $Candidate.File
        Save-Config
        return [pscustomobject]@{ Success=$true; TimedOut=$false; Process=$process; Url=$url }
    }
    try { $process.Refresh() } catch { }
    if (-not $process.HasExited) {
        Write-Warn "The server is still running but did not become ready before the timeout. It may be loading a large model. The process was left running; check $outLog and $errLog."
        if ($script:Config.AutoOpenBrowser) { Start-Process $url }
        $script:Config.SelectedModelId = $Candidate.Id
        $script:Config.SelectedModelFile = $Candidate.File
        Save-Config
        return [pscustomobject]@{ Success=$true; TimedOut=$true; Process=$process; Url=$url }
    }
    Write-Fail ('The server exited during startup with code ' + $process.ExitCode)
    Write-Host ('Last server error log lines: ' + $errLog) -ForegroundColor Yellow
    try { Get-Content -LiteralPath $errLog -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ } } catch { }
    Write-Log ('Server exited early. See ' + $errLog) 'ERROR'
    return [pscustomobject]@{ Success=$false; TimedOut=$false; Process=$process; Url=$url }
}
function Install-And-Run {
    $hardware = Get-HardwareReport
    if ($hardware.Architecture -notin @('x64','ARM64')) { throw "Unsupported architecture '$($hardware.Architecture)'. This release supports native Windows x64 and ARM64 runtime builds." }
    $serverExe = Ensure-Runtime -Architecture $hardware.Architecture
    $catalog = Get-LiveCatalog
    $candidates = Get-ModelCandidates -Catalog $catalog -Hardware $hardware
    if ($candidates.Count -eq 0) {
        Write-Warn 'No curated MoE model passed the current Balanced RAM budget and free-storage checks.'
        if ($script:Config.Mode -eq 'Balanced') {
            $answer = Read-Host 'Switch to Experimental mode to consider disk-streamed, oversized models? Type YES to switch'
            if ($answer -ceq 'YES') { $script:Config.Mode = 'Experimental'; Save-Config; $candidates = Get-ModelCandidates -Catalog $catalog -Hardware $hardware }
        }
    }
    if ($candidates.Count -eq 0) { Write-Fail 'No validated model variant can be selected. Increase free disk space, change model storage, or use a supported PC with more RAM.'; return }
    $selected = Get-SelectedCandidate -Candidates $candidates
    if ($null -eq $selected) { Write-Info 'Cancelled before downloading the model.'; return }
    if (-not (Test-ModelSpace -Candidate $selected)) { throw ('Insufficient free storage for {0}; at least {1:N1} GB of free space is required on the model drive.' -f $selected.Name, ($selected.SizeGB + 3.0)) }
    if ($script:Config.Mode -eq 'Experimental') {
        $media = Get-DriveMediaType -Path ([string]$script:Config.ModelPath)
        if ($media -notmatch 'SSD|NVMe') { Write-Warn ('Model drive type is ' + $media + '. Disk streaming is typically much slower on HDD/unknown media.') }
    }
    $candidateQueue = @($selected) + @($candidates | Where-Object { $_.Id -ne $selected.Id })
    $triedIds = @{}
    foreach ($candidate in $candidateQueue) {
        if ($triedIds.ContainsKey([string]$candidate.Id)) { continue }
        $triedIds[[string]$candidate.Id] = $true
        if (-not (Test-ModelSpace -Candidate $candidate)) { Write-Warn ('Skipping fallback ' + $candidate.Name + ': not enough free disk space.'); continue }
        $modelDir = Join-Path ([string]$script:Config.ModelPath) ([string]$candidate.Id)
        if (-not (Test-Path $modelDir)) { New-Item -ItemType Directory -Path $modelDir -Force | Out-Null }
        $modelFile = Join-Path $modelDir ([string]$candidate.File)
        $validExisting = $false
        if (Test-Path $modelFile) {
            $existingBytes = (Get-Item -LiteralPath $modelFile).Length
            if ($existingBytes -eq [long]$candidate.SizeBytes) {
                if ($script:Config.VerifySha256 -and $candidate.Sha256 -match '^[a-fA-F0-9]{64}$') {
                    Write-Info ('Verifying existing model: ' + [IO.Path]::GetFileName($modelFile))
                    if ((Get-FileHash -LiteralPath $modelFile -Algorithm SHA256).Hash.ToLowerInvariant() -eq $candidate.Sha256.ToLowerInvariant()) { $validExisting = $true }
                    else { Write-Warn 'Existing model checksum did not match; it will be replaced.'; Remove-Item -LiteralPath $modelFile -Force }
                } else { $validExisting = $true }
            } else { Write-Warn 'Existing model has an incorrect file size; it will be replaced.'; Remove-Item -LiteralPath $modelFile -Force }
        }
        try {
            if (-not $validExisting) {
                Write-Info ('Preparing {0} ({1}, {2:N1} GB). Repository revision: {3}' -f $candidate.Name, $candidate.Quant, $candidate.SizeGB, $candidate.Revision)
                Download-File -Url $candidate.Url -Destination $modelFile -ExpectedBytes $candidate.SizeBytes -Sha256 $candidate.Sha256 -VerifyHash ([bool]$script:Config.VerifySha256)
            } else { Write-Ok ('Reusing verified model: ' + $modelFile) }
            $start = Start-LocalModelServer -ServerExe $serverExe -Candidate $candidate -ModelFile $modelFile -Hardware $hardware
            if ($start.Success) {
                Write-Host ''
                Write-Ok ('Local AI is running. Open: ' + $start.Url)
                Write-Host ('Model: ' + $candidate.Name + ' | Quantization: ' + $candidate.Quant)
                Write-Host 'The server listens on localhost only and is not exposed to your local network.'
                Write-Host ('Logs: ' + $script:LogPath)
                return
            }
            Write-Warn ('Model family failed at startup; trying the next smaller candidate if available.')
        } catch {
            Write-Fail $_.Exception.Message
            Write-Log ('Candidate failure ' + $candidate.Id + '/' + $candidate.File + ': ' + $_.Exception.Message) 'ERROR'
            Write-Warn 'Stopping this installation attempt to avoid downloading additional large models after a download or integrity failure.'
            return
        }
    }
    Write-Fail 'No model started successfully. Review the server error logs and hardware report. The installer has not disabled security features or made unapproved system changes.'
}
function Show-Settings {
    while ($true) {
        Clear-Host
        Write-Host '================ SMART CPU AI SETTINGS ================' -ForegroundColor White
        Write-Host ('1. RAM reserve percentage: {0} (10–40)' -f $script:Config.ReservePercent)
        Write-Host ('2. Operating mode: {0} (Balanced / Experimental)' -f $script:Config.Mode)
        Write-Host ('3. Context length: {0} tokens (2048 / 4096 / 8192 / 16384)' -f $script:Config.ContextTokens)
        Write-Host ('4. CPU threads: {0} (0 = auto; otherwise 1–256)' -f $script:Config.Threads)
        Write-Host ('5. Model storage directory: {0}' -f $script:Config.ModelPath)
        Write-Host ('6. SHA-256 verification: {0}' -f $script:Config.VerifySha256)
        Write-Host ('7. Automatically open browser: {0}' -f $script:Config.AutoOpenBrowser)
        Write-Host '8. Return'
        $choice = Read-Host 'Choose a setting'
        switch ($choice) {
            '1' {
                $v = Read-Host 'RAM reserve percent (10–40)'
                $n = 0
                if ([int]::TryParse($v,[ref]$n) -and $n -ge 10 -and $n -le 40) { $script:Config.ReservePercent = $n; Save-Config } else { Write-Warn 'Enter a whole number from 10 to 40.'; Wait-Key }
            }
            '2' {
                Write-Host '1. Balanced (recommended)'; Write-Host '2. Experimental (may use heavy SSD paging and make Windows very slow)'
                $v = Read-Host 'Choose 1 or 2'
                if ($v -eq '1') { $script:Config.Mode='Balanced'; Save-Config }
                elseif ($v -eq '2') { $script:Config.Mode='Experimental'; Save-Config }
                else { Write-Warn 'No change made.'; Wait-Key }
            }
            '3' {
                $v = Read-Host 'Context tokens: 2048, 4096, 8192, or 16384'
                $n = 0
                if ([int]::TryParse($v,[ref]$n) -and @(2048,4096,8192,16384) -contains $n) { $script:Config.ContextTokens = $n; Save-Config } else { Write-Warn 'Unsupported context value.'; Wait-Key }
            }
            '4' {
                $v = Read-Host 'CPU thread count (0 for auto)'
                $n = -1
                if ([int]::TryParse($v,[ref]$n) -and $n -ge 0 -and $n -le 256) { $script:Config.Threads = $n; Save-Config } else { Write-Warn 'Enter a number from 0 to 256.'; Wait-Key }
            }
            '5' {
                $v = Read-Host 'Full model directory path (example: D:\AI\Models)'
                if (-not [string]::IsNullOrWhiteSpace($v)) {
                    try {
                        $fullPath = [IO.Path]::GetFullPath($v.Trim().Trim('"'))
                        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                        $testFile = Join-Path $fullPath ('.write-test-' + [guid]::NewGuid().ToString('N'))
                        [IO.File]::WriteAllText($testFile,'ok'); Remove-Item -LiteralPath $testFile -Force
                        $script:Config.ModelPath = $fullPath; Save-Config
                        Write-Ok 'Model storage path updated.'; Wait-Key
                    } catch { Write-Warn ('Could not use that path: ' + $_.Exception.Message); Wait-Key }
                }
            }
            '6' { $script:Config.VerifySha256 = -not [bool]$script:Config.VerifySha256; Save-Config }
            '7' { $script:Config.AutoOpenBrowser = -not [bool]$script:Config.AutoOpenBrowser; Save-Config }
            '8' { return }
            default { Write-Warn 'Choose one of the listed options.'; Wait-Key }
        }
    }
}
function Show-PagefileStatus {
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        $settings = @(Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue)
        $usage = @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue)
        Write-Host ('AutomaticManagedPagefile: ' + $cs.AutomaticManagedPagefile)
        if ($settings.Count -gt 0) { Write-Host 'Configured page-file settings:'; $settings | ForEach-Object { Write-Host ('  {0} | Initial MB={1} | Maximum MB={2}' -f $_.Name,$_.InitialSize,$_.MaximumSize) } }
        if ($usage.Count -gt 0) { Write-Host 'Current page-file usage:'; $usage | ForEach-Object { Write-Host ('  {0} | Allocated MB={1} | In use MB={2} | Peak MB={3}' -f $_.Name,$_.AllocatedBaseSize,$_.CurrentUsage,$_.PeakUsage) } }
        if (-not $cs.AutomaticManagedPagefile) { Write-Warn 'Windows is not currently configured for an automatically managed page file. A system-managed page file is the recommended baseline for this tool.' }
        else { Write-Ok 'Windows reports automatic page-file management enabled.' }
    } catch { Write-Warn ('Could not read page-file settings: ' + $_.Exception.Message) }
}
function Invoke-PagefileRepair {
    if (-not (Test-IsAdministrator)) { throw 'Page-file repair requires Administrator permissions.' }
    $cs = Get-CimInstance Win32_ComputerSystem
    $backup = [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        AutomaticManagedPagefile = [bool]$cs.AutomaticManagedPagefile
        PageFileSettings = @(Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{Name=$_.Name; InitialSizeMB=$_.InitialSize; MaximumSizeMB=$_.MaximumSize} })
    }
    $backupPath = Join-Path $script:LogPath ('pagefile-backup-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.json')
    $backup | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupPath -Encoding UTF8
    Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $true } | Out-Null
    $check = Get-CimInstance Win32_ComputerSystem
    if (-not $check.AutomaticManagedPagefile) { throw 'Windows did not confirm automatic page-file management after the change.' }
    Write-Ok 'Automatic page-file management is enabled. Windows may require a restart before the change fully takes effect.'
    Write-Host ('Previous settings saved to: ' + $backupPath)
    Write-Log ('Enabled automatic pagefile management. Backup: ' + $backupPath)
}
function Configure-Pagefile {
    Clear-Host
    Write-Host '=============== PAGE FILE CHECK / REPAIR ===============' -ForegroundColor White
    Show-PagefileStatus
    Write-Host ''
    Write-Host 'Recommendation: use Windows system-managed paging. This script does not set a blindly enormous custom page file.'
    Write-Host 'The page file is disk-backed virtual memory, not equivalent to physical RAM; heavy paging can make inference extremely slow.'
    $answer = Read-Host 'Enable Windows system-managed page-file setting? This is a system-level change. Type YES to proceed'
    if ($answer -cne 'YES') { Write-Info 'No page-file settings were changed.'; Wait-Key; return }
    if (Test-IsAdministrator) {
        try { Invoke-PagefileRepair } catch { Write-Fail $_.Exception.Message }
    } else {
        Write-Info 'Requesting Administrator approval through the Windows UAC prompt...'
        $argList = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -PagefileRepairElevated' -f $PSCommandPath
        try { Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -Wait } catch { Write-Warn ('Elevation was cancelled or failed: ' + $_.Exception.Message) }
    }
    Wait-Key
}
function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host '========================================================' -ForegroundColor DarkCyan
        Write-Host '          SMART CPU AI - LOCAL MOE MODEL RUNNER' -ForegroundColor Cyan
        Write-Host '========================================================' -ForegroundColor DarkCyan
        Write-Host ('Mode: {0} | RAM reserve: {1}% | Context: {2} | Storage: {3}' -f $script:Config.Mode, $script:Config.ReservePercent, $script:Config.ContextTokens, $script:Config.ModelPath)
        Write-Host ''
        Write-Host '1. Install / select the largest suitable MoE model and launch it'
        Write-Host '2. Start the saved model again (if already downloaded)'
        Write-Host '3. Hardware report'
        Write-Host '4. Settings'
        Write-Host '5. Check / optionally repair Windows page-file configuration'
        Write-Host '6. Open logs and report folder'
        Write-Host '7. Exit'
        $choice = Read-Host 'Choose an option'
        switch ($choice) {
            '1' { try { Install-And-Run } catch { Write-Fail $_.Exception.Message; Write-Log $_.Exception.ToString() 'ERROR' }; Wait-Key }
            '2' { try { Start-SavedModel } catch { Write-Fail $_.Exception.Message }; Wait-Key }
            '3' { try { Get-HardwareReport | Out-Null } catch { Write-Fail $_.Exception.Message }; Wait-Key }
            '4' { Show-Settings }
            '5' { Configure-Pagefile }
            '6' { Start-Process explorer.exe -ArgumentList ('"' + $script:LogPath + '"') }
            '7' { return }
            default { Write-Warn 'Choose a number from 1 to 7.'; Wait-Key }
        }
    }
}
function Start-SavedModel {
    if ([string]::IsNullOrWhiteSpace([string]$script:Config.SelectedModelId) -or [string]::IsNullOrWhiteSpace([string]$script:Config.SelectedModelFile)) {
        Write-Warn 'No saved model is configured yet. Use option 1 first.'; return
    }
    $match = $null
    foreach ($m in $script:Catalog) {
        if ($m.Id -eq $script:Config.SelectedModelId) {
            foreach ($v in $m.Variants) { if ($v.File -eq $script:Config.SelectedModelFile) { $match = [pscustomobject]@{Id=$m.Id;Name=$m.Name;Repo=$m.Repo;File=$v.File;Quant=$v.Quant;TotalB=$m.TotalB;ActiveB=$m.ActiveB;UseJinja=[bool]$m.UseJinja}; break } }
        }
    }
    if (-not $match) { Write-Warn 'The saved model no longer exists in the curated catalog. Use option 1 to choose again.'; return }
    $modelFile = Join-Path (Join-Path ([string]$script:Config.ModelPath) $match.Id) $match.File
    if (-not (Test-Path $modelFile)) { Write-Warn 'The saved model file is missing. Use option 1 to download it again.'; return }
    $server = Get-ChildItem -LiteralPath $script:RuntimePath -Filter 'llama-server.exe' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $server) { Write-Warn 'The CPU runtime is missing. Use option 1 to install it again.'; return }
    $hardware = Get-HardwareReport
    $result = Start-LocalModelServer -ServerExe $server.FullName -Candidate $match -ModelFile $modelFile -Hardware $hardware
    if ($result.Success) { Write-Ok ('Local AI: ' + $result.Url) }
}

try {
    Load-Config
    Initialize-Folders
    Write-Log 'Smart CPU AI started.'
    if ($PagefileRepairElevated) {
        try { Invoke-PagefileRepair; exit 0 } catch { Write-Fail $_.Exception.Message; exit 1 }
    }
    if ($HardwareReportOnly) { Get-HardwareReport | Out-Null; exit 0 }
    Show-MainMenu
    Write-Log 'Smart CPU AI closed.'
    exit 0
} catch {
    Write-Fail $_.Exception.Message
    Write-Log $_.Exception.ToString() 'FATAL'
    Write-Host ('Detailed log: ' + $script:LogFile)
    exit 1
}

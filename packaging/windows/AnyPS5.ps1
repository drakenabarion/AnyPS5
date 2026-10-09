# AnyPS5 launcher for Windows: run Quake (PPSA01881) from the user's own PS5 dump.
#   AnyPS5.cmd [-DataDir DIR] [-Reconvert] [DUMP_DIR]
# Without DUMP_DIR, a game next to this folder (this folder itself, or the single game folder beside it)
# starts directly, then the game chosen last time; only when neither exists does a folder picker ask.
# Nothing is written into the dump. Per-game files live in <data dir>\<title ID>\.
param(
    [string]$DataDir = "",
    [switch]$Reconvert,
    [switch]$Version,
    [Parameter(Position = 0)][string]$Dump = ""
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

$Root = $PSScriptRoot
$Relinker = Join-Path $Root "bin\relinker.exe"
$Libs = Join-Path $Root "libs"
$Beside = Split-Path $Root -Parent
$Portable = Join-Path $Root "AnyPS5 data"
$DefaultData = Join-Path $env:LOCALAPPDATA "AnyPS5"
$ConfigDir = if (Test-Path $Portable) { $Portable } else { $DefaultData }
$SupportedId = "PPSA01881"

function Fail([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show($Message, "AnyPS5", "OK", "Error") | Out-Null
    exit 1
}
function Ask([string]$Message, [string]$Buttons = "YesNo") {
    $answer = [System.Windows.Forms.MessageBox]::Show($Message, "AnyPS5", $Buttons, "Question")
    return $answer -eq "Yes" -or $answer -eq "OK"
}
function Setting([string]$Name) {
    $file = Join-Path $ConfigDir "settings.conf"
    if (-not (Test-Path $file)) { return "" }
    $line = Get-Content $file | Where-Object { $_ -like "$Name=*" } | Select-Object -Last 1
    if ($line) { return $line.Substring($Name.Length + 1) } else { return "" }
}
function SaveSetting([string]$Name, [string]$Value) {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    $file = Join-Path $ConfigDir "settings.conf"
    $lines = @(if (Test-Path $file) { Get-Content $file | Where-Object { $_ -notlike "$Name=*" } })
    Set-Content -Path $file -Value ($lines + "$Name=$Value") -Encoding UTF8
}
function IsDump([string]$Folder) {
    return $Folder -and (Test-Path (Join-Path $Folder "eboot.bin")) -and (Test-Path (Join-Path $Folder "sce_sys\param.json"))
}
function ParamValue([string]$Folder, [string]$Key) {
    $json = Get-Content (Join-Path $Folder "sce_sys\param.json") -Raw
    if ($json -match ('"' + $Key + '"\s*:\s*"([^"]*)"')) { return $Matches[1] } else { return "" }
}
function PickDump([string]$Start) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose your game folder (the one containing eboot.bin)"
    $dialog.ShowNewFolderButton = $false
    if ($Start -and (Test-Path $Start)) { $dialog.SelectedPath = $Start }
    while ($true) {
        if ($dialog.ShowDialog() -ne "OK") { return "" }
        if (IsDump $dialog.SelectedPath) { return $dialog.SelectedPath }
        [System.Windows.Forms.MessageBox]::Show("That folder is not a PS5 game dump: it needs eboot.bin and sce_sys\param.json. Choose the game's top folder.", "AnyPS5", "OK", "Warning") | Out-Null
    }
}

try {
    if ($Version) { Write-Output ("AnyPS5 " + (Get-Content (Join-Path $Root "VERSION") -ErrorAction SilentlyContinue)); exit 0 }

    if ($Dump) {
        if (-not (IsDump $Dump)) { Fail "Not a PS5 game dump (needs eboot.bin and sce_sys\param.json): $Dump" }
        $Dump = (Resolve-Path $Dump).Path
    } else {
        $found = @()
        if (IsDump $Root) { $found = @($Root) }
        elseif (IsDump $Beside) { $found = @($Beside) }
        else { $found = @(Get-ChildItem -Directory $Beside | Where-Object { IsDump $_.FullName } | ForEach-Object { $_.FullName }) }
        $last = Setting "last_dump"
        if ($found.Count -eq 1) { $Dump = $found[0] }
        elseif (IsDump $last) { $Dump = $last }
        else {
            if (-not (Ask "Please select the game folder (the folder containing eboot.bin)." "OKCancel")) { exit 0 }
            $Dump = PickDump $(if ($last) { Split-Path $last -Parent } else { $Beside })
            if (-not $Dump) { exit 0 }
            $pickedId = ParamValue $Dump "titleId"
            if ($pickedId -ne $SupportedId) {
                $pickedName = ParamValue $Dump "titleName"
                if (-not (Ask "This AnyPS5 release is made and tested for Quake ($SupportedId) only.`n`n$pickedName ($pickedId) will probably not work. Start it anyway?" "OKCancel")) { exit 0 }
            }
            if (-not $DataDir -and -not (Test-Path $Portable) -and -not (Setting "data_dir")) {
                if (Ask "Store converted games and saves next to AnyPS5 instead of in your user folder?`n`nUser folder (default): $DefaultData`nNext to AnyPS5: $Portable") {
                    New-Item -ItemType Directory -Force -Path $Portable | Out-Null
                    $ConfigDir = $Portable
                } else {
                    SaveSetting "data_dir" $DefaultData
                }
            }
            SaveSetting "last_dump" $Dump
        }
    }

    if (-not (Test-Path $Relinker)) { Fail "relinker.exe not found at $Relinker" }
    if (-not (Test-Path (Join-Path $Libs "libc.prx"))) { Fail "System libraries not found in $Libs" }
    $TitleId = ParamValue $Dump "titleId"
    if (-not $TitleId) { Fail "No titleId in sce_sys\param.json" }
    $TitleName = ParamValue $Dump "titleName"

    if (-not $DataDir) { $DataDir = if (Test-Path $Portable) { $Portable } elseif (Setting "data_dir") { Setting "data_dir" } else { $DefaultData } }
    $Game = Join-Path $DataDir $TitleId
    $App0 = Join-Path $Game "app0"
    New-Item -ItemType Directory -Force -Path $App0 | Out-Null
    Write-Output "AnyPS5: $TitleName ($TitleId), files in $Game"

    # libs\ beside the game executable: a directory junction to this package's libraries (no administrator rights needed).
    $GameLibs = Join-Path $Game "libs"
    if (Test-Path $GameLibs) { (Get-Item $GameLibs).Delete() }
    New-Item -ItemType Junction -Path $GameLibs -Target $Libs | Out-Null

    # The conversion stamp covers file contents only, so moving the dump or this folder does not reconvert.
    $intel = (Get-CimInstance Win32_Processor | Select-Object -First 1).Manufacturer -eq "GenuineIntel"
    $moduleDirs = @("sce_module", "sce_modules", "prx")
    $hashes = @((Get-FileHash (Join-Path $Dump "eboot.bin")).Hash)
    foreach ($dir in $moduleDirs) {
        $path = Join-Path $Dump $dir
        if (Test-Path $path) { Get-ChildItem -File $path | Sort-Object Name | ForEach-Object { $hashes += "$dir/$($_.Name) $((Get-FileHash $_.FullName).Hash)" } }
    }
    $hashes += (Get-FileHash $Relinker).Hash
    $hashes += $(if ($intel) { "intel" } else { "other" })
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($hashes -join "`n"))
    $stamp = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace("-", "")
    $Exe = Join-Path $Game "$TitleId.exe"
    $stampFile = Join-Path $Game ".conversion"
    if ($Reconvert -or -not (Test-Path $Exe) -or -not (Test-Path $stampFile) -or (Get-Content $stampFile) -ne $stamp) {
        Write-Output "AnyPS5: converting (only needed once per game and AnyPS5 version)..."
        foreach ($dir in $moduleDirs) { $path = Join-Path $App0 $dir; if (Test-Path $path) { Remove-Item -Recurse -Force $path } }
        $arguments = @("--windows", "--rpath", '$ORIGIN/libs', (Join-Path $Dump "eboot.bin"), $Exe)
        if ($intel) { $arguments = @("--to-intel") + $arguments }
        $log = Join-Path $Game "conversion.log"
        $process = Start-Process -FilePath $Relinker -ArgumentList ($arguments | ForEach-Object { '"' + $_ + '"' }) -WorkingDirectory $Game -NoNewWindow -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
        if ($process.ExitCode -ne 0) { Fail "Conversion failed, see $log and $log.err" }
        Set-Content -Path $stampFile -Value $stamp
    }

    # Game resources: directories as junctions, files as hard links (or copies on another drive).
    # The original modules and eboot.bin stay out: app0 holds their converted versions.
    $dumpFile = Join-Path $Game ".dump"
    if (-not (Test-Path $dumpFile) -or (Get-Content $dumpFile) -ne $Dump) {
        Get-ChildItem $App0 -Force | Where-Object { $moduleDirs -notcontains $_.Name } | ForEach-Object {
            if ($_.LinkType) { $_.Delete() } else { Remove-Item -Recurse -Force $_.FullName }
        }
        Set-Content -Path $dumpFile -Value $Dump
    }
    foreach ($item in Get-ChildItem $Dump -Force) {
        if ($moduleDirs -contains $item.Name -or $item.Name -eq "eboot.bin" -or $item.Name -eq "stderr.txt") { continue }
        $link = Join-Path $App0 $item.Name
        if (Test-Path $link) { continue }
        if ($item.PSIsContainer) { New-Item -ItemType Junction -Path $link -Target $item.FullName | Out-Null }
        else {
            try { New-Item -ItemType HardLink -Path $link -Target $item.FullName -ErrorAction Stop | Out-Null }
            catch { Copy-Item $item.FullName $link }
        }
    }

    $fullscreen = $env:ANYPS5_FULLSCREEN
    if (-not $fullscreen) {
        $fullscreen = Setting "fullscreen"
        if (-not $fullscreen) {
            $fullscreen = if (Ask "Play in fullscreen?`n`nYou can switch at any time with F11, or LB+RB+L3+R3 on a controller.") { "1" } else { "0" }
            SaveSetting "fullscreen" $fullscreen
        }
    }
    $env:ANYPS5_FULLSCREEN = $fullscreen

    Write-Output "AnyPS5: starting, log in $Game\run.log"
    Start-Process -FilePath $Exe -WorkingDirectory $Game -WindowStyle Hidden -RedirectStandardOutput (Join-Path $Game "run.log") -RedirectStandardError (Join-Path $Game "run.err.log") | Out-Null
} catch {
    Fail "Unexpected error in the launcher: $($_.Exception.Message)`n`nPlease report this together with the files in the game data folder."
}

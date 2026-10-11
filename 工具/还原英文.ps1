#Requires -Version 5.1
<#
  一键还原 Proteus 英文界面（还原英文.ps1）
  ------------------------------------------------------------------
  作用：把 Proteus 恢复成英文界面。
        · 若存在备份（proteus_zh_CN.qm.bak-*），恢复最新备份
        · 否则直接删除 proteus_zh_CN.qm
        · 自动定位 Proteus 安装目录；找不到时可手动粘贴路径
        · 自动请求管理员权限（UAC），无需手动右键

  用法：
      双击仓库根目录的「一键还原英文.bat」（推荐，自动提权）
      或：powershell -ExecutionPolicy Bypass -File 还原英文.ps1
      指定目录：powershell -ExecutionPolicy Bypass -File 还原英文.ps1 -InstallDir "D:\...\Proteus 8 Professional"
#>
[CmdletBinding()]
param(
    [string]$InstallDir = "",
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

# ---------- 1. 自动请求管理员权限 ----------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $isAdmin) {
    Write-Host '[i] 修改 Proteus 安装目录需要管理员权限，正在弹出授权窗口……' -ForegroundColor Yellow
    $psExe = (Get-Process -Id $PID).Path
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($InstallDir) { $argList += @('-InstallDir', "`"$InstallDir`"") }
    if ($NoPause)    { $argList += '-NoPause' }
    try {
        $proc = Start-Process -FilePath $psExe -ArgumentList $argList -Verb RunAs -PassThru -Wait
        exit $proc.ExitCode
    }
    catch {
        Write-Host '[×] 未获得管理员权限（授权被取消）。' -ForegroundColor Red
        Write-Host '    可右键本脚本 / 「一键还原英文.bat」→「以管理员身份运行」。' -ForegroundColor Yellow
        if (-not $NoPause) { Read-Host '按回车键关闭窗口' | Out-Null }
        exit 1
    }
}

# ---------- 2. 定位 Proteus 安装目录 ----------
function Test-ProteusRoot {
    param([string]$Path)
    if (-not $Path) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Path 'Translations') -PathType Container)
}

function Resolve-ProteusDir {
    param([string]$Hint)

    if ($Hint) {
        $Hint = $Hint.Trim().Trim('"')
        if (Test-ProteusRoot $Hint) { return (Resolve-Path -LiteralPath $Hint).Path }
        $sub = Get-ChildItem -LiteralPath $Hint -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-ProteusRoot $_.FullName }
        if ($sub) { return $sub[0].FullName }
        Write-Host "[×] 指定目录里找不到 Proteus 主目录（应包含 Translations 文件夹）：$Hint" -ForegroundColor Red
        return $null
    }

    $cands = New-Object System.Collections.Generic.List[string]

    foreach ($base in @('HKLM:\SOFTWARE\WOW6432Node\Labcenter Electronics',
                        'HKLM:\SOFTWARE\Labcenter Electronics')) {
        if (-not (Test-Path $base)) { continue }
        foreach ($sub in (Get-ChildItem -Path $base -ErrorAction SilentlyContinue)) {
            try {
                $v = Get-ItemProperty -Path $sub.PSPath -ErrorAction Stop
                foreach ($p in @('InstallPath', 'InstallLocation', 'Path', 'HomeDir', 'Location')) {
                    if ($v.$p) { [void]$cands.Add("$($v.$p)".TrimEnd('\')) }
                }
            } catch { }
        }
    }

    foreach ($pn in @('PDS', 'PDS64', 'Proteus', 'ISIS', 'ARES')) {
        try {
            $p = Get-Process -Name $pn -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($p -and $p.Path) { [void]$cands.Add((Split-Path -Parent $p.Path)) }
        } catch { }
    }

    foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        foreach ($pf in @('Program Files (x86)', 'Program Files')) {
            $lab = Join-Path $drive.Root (Join-Path $pf 'Labcenter Electronics')
            if (Test-Path -LiteralPath $lab) {
                foreach ($sub in (Get-ChildItem -LiteralPath $lab -Directory -ErrorAction SilentlyContinue)) {
                    [void]$cands.Add($sub.FullName)
                }
            }
        }
    }

    foreach ($c in $cands) {
        if (Test-ProteusRoot $c) { return (Resolve-Path -LiteralPath $c).Path }
    }

    Write-Host ''
    Write-Host '[i] 未能自动找到 Proteus 安装目录。' -ForegroundColor Yellow
    Write-Host '    请粘贴 Proteus 安装目录（其中应包含 Translations 和 BIN 文件夹），例如：' -ForegroundColor Yellow
    Write-Host '    C:\Program Files (x86)\Labcenter Electronics\Proteus 8 Professional' -ForegroundColor Gray
    for ($i = 0; $i -lt 3; $i++) {
        try { $in = Read-Host 'Proteus 安装目录（直接回车则退出）' } catch { break }
        if ([string]::IsNullOrWhiteSpace($in)) { break }
        $in = $in.Trim().Trim('"')
        if (Test-ProteusRoot $in) { return (Resolve-Path -LiteralPath $in).Path }
        Write-Host '[×] 该路径下没有 Translations 文件夹，请检查后重试。' -ForegroundColor Red
    }
    return $null
}

$dir = Resolve-ProteusDir -Hint $InstallDir
if (-not $dir) {
    Write-Host '[×] 未能定位 Proteus 安装目录，还原中止。' -ForegroundColor Red
    if (-not $NoPause) { Read-Host '按回车键关闭窗口' | Out-Null }
    exit 1
}

# ---------- 3. 还原 ----------
$translations = Join-Path $dir 'Translations'
$dst = Join-Path $translations 'proteus_zh_CN.qm'

if (-not (Test-Path -LiteralPath $dst)) {
    Write-Host '[i] 未发现 proteus_zh_CN.qm，当前已是英文界面，无需处理。'
    if (-not $NoPause) { Read-Host '按回车键关闭窗口' | Out-Null }
    exit 0
}

$baks = @(Get-ChildItem -Path (Join-Path $translations 'proteus_zh_CN.qm.bak-*') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending)
Remove-Item -LiteralPath $dst -Force
if ($baks.Count -gt 0) {
    Copy-Item -LiteralPath $baks[0].FullName -Destination $dst -Force
    Write-Host ("[√] 已恢复备份：{0}" -f $baks[0].Name) -ForegroundColor Green
}
else {
    Write-Host '[√] 已删除汉化文件，重启 Proteus 即回到英文界面。' -ForegroundColor Green
}
Write-Host ''
Write-Host '请完全关闭并重新打开 Proteus 生效。' -ForegroundColor Cyan

if (-not $NoPause) {
    Write-Host ''
    Read-Host '还原完成，按回车键关闭窗口' | Out-Null
}

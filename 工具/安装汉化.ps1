#Requires -Version 5.1
<#
  一键安装 Proteus 汉化语言包（安装汉化.ps1）
  ------------------------------------------------------------------
  作用：把「成品\proteus_zh_CN.qm」安装到 Proteus 安装目录的 Translations 文件夹。
        · 自动定位 Proteus 安装目录（注册表 / 运行中的程序 / 常见路径全盘扫描）
        · 找不到时可手动粘贴安装目录路径
        · 自动请求管理员权限（UAC），无需手动右键
        · 原文件（若存在）自动备份为 proteus_zh_CN.qm.bak-<时间戳>
        · 不改动任何程序文件（EXE/DLL），可随时一键还原

  用法：
      双击仓库根目录的「一键安装汉化.bat」（推荐，自动提权）
      或：powershell -ExecutionPolicy Bypass -File 安装汉化.ps1
      指定目录：powershell -ExecutionPolicy Bypass -File 安装汉化.ps1 -InstallDir "D:\...\Proteus 8 Professional"
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
    Write-Host '[i] 写入 Proteus 安装目录需要管理员权限，正在弹出授权窗口……' -ForegroundColor Yellow
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
        Write-Host '    可右键本脚本 / 「一键安装汉化.bat」→「以管理员身份运行」。' -ForegroundColor Yellow
        if (-not $NoPause) { Read-Host '按回车键关闭窗口' | Out-Null }
        exit 1
    }
}

# ---------- 2. 定位源文件与 Proteus 安装目录 ----------
$root = Split-Path -Parent $PSScriptRoot          # 仓库根目录（本脚本位于 工具\ 下）
$src  = Join-Path $root '成品\proteus_zh_CN.qm'

if (-not (Test-Path -LiteralPath $src)) {
    Write-Host "[×] 找不到汉化文件：$src" -ForegroundColor Red
    Write-Host '    请确认已完整解压整个压缩包，且没有单独移动「成品」文件夹。' -ForegroundColor Yellow
    if (-not $NoPause) { Read-Host '按回车键关闭窗口' | Out-Null }
    exit 1
}

function Test-ProteusRoot {
    param([string]$Path)
    if (-not $Path) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Path 'Translations') -PathType Container)
}

function Resolve-ProteusDir {
    param([string]$Hint)

    # (1) 用户显式指定
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

    # (2) 注册表（8.x / 9.x，32/64 位均查）
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

    # (3) 正在运行的 Proteus 主程序所在目录
    foreach ($pn in @('PDS', 'PDS64', 'Proteus', 'ISIS', 'ARES')) {
        try {
            $p = Get-Process -Name $pn -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($p -and $p.Path) { [void]$cands.Add((Split-Path -Parent $p.Path)) }
        } catch { }
    }

    # (4) 各磁盘的常见安装位置（自动识别 8.x / 9.x 版本子目录）
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

    # (5) 仍然找不到：交互式让用户粘贴路径
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
    Write-Host '[×] 未能定位 Proteus 安装目录，安装中止。' -ForegroundColor Red
    Write-Host '    可用 -InstallDir 参数手动指定，例如：' -ForegroundColor Yellow
    Write-Host '    powershell -ExecutionPolicy Bypass -File 工具\安装汉化.ps1 -InstallDir "D:\...\Proteus 8 Professional"' -ForegroundColor Gray
    if (-not $NoPause) { Read-Host '按回车键关闭窗口' | Out-Null }
    exit 1
}

# ---------- 3. 备份并安装 ----------
$dstDir = Join-Path $dir 'Translations'
$dst    = Join-Path $dstDir 'proteus_zh_CN.qm'

Write-Host ''
Write-Host "Proteus 目录：$dir"
if (Test-Path -LiteralPath $dst) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = "$dst.bak-$stamp"
    Copy-Item -LiteralPath $dst -Destination $bak -Force
    Write-Host "[√] 已备份原文件：$bak"
}
else {
    Write-Host '[i] 当前没有 proteus_zh_CN.qm（英文界面），无需备份。'
}

Copy-Item -LiteralPath $src -Destination $dst -Force
$f    = Get-Item -LiteralPath $dst
$hash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.Substring(0, 16)
Write-Host ('[√] 汉化已安装：{0}（{1} 字节, SHA256:{2}...）' -f $dst, $f.Length, $hash) -ForegroundColor Green
Write-Host ''
Write-Host '请完全关闭并重新打开 Proteus，界面即为中文。' -ForegroundColor Cyan
Write-Host '如需还原英文，双击仓库根目录的「一键还原英文.bat」。'

if (-not $NoPause) {
    Write-Host ''
    Read-Host '安装完成，按回车键关闭窗口' | Out-Null
}

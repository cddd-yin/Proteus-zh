#Requires -Version 5.1
<#
  一键安装 Proteus 汉化语言包
  -----------------------------------------------------------------
  将「成品\proteus_zh_CN.qm」安装到 Proteus 安装目录的 Translations 文件夹。
  - 原文件（若存在）自动备份为 proteus_zh_CN.qm.bak-<时间戳>
  - 不改动任何程序文件（EXE/DLL），可随时一键还原

  用法：
      powershell -ExecutionPolicy Bypass -File 安装汉化.ps1
      powershell -ExecutionPolicy Bypass -File 安装汉化.ps1 -InstallDir "D:\...\Proteus 8 Professional"

  提示：若提示“拒绝访问”，请右键“以管理员身份运行”。
#>
param([string]$InstallDir = "")

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
$src = Join-Path $root '成品\proteus_zh_CN.qm'

if (-not (Test-Path $src)) {
    Write-Host "[×] 找不到汉化文件：$src" -ForegroundColor Red
    exit 1
}

function Resolve-ProteusDir {
    param([string]$Hint)
    if ($Hint) {
        if (Test-Path (Join-Path $Hint 'Translations')) { return (Resolve-Path $Hint).Path }
        Write-Host "[×] 指定目录中找不到 Translations 文件夹：$Hint" -ForegroundColor Red
        exit 1
    }
    $cands = @()
    foreach ($k in @(
            'HKLM:\SOFTWARE\WOW6432Node\Labcenter Electronics\Proteus 8 Professional',
            'HKLM:\SOFTWARE\Labcenter Electronics\Proteus 8 Professional')) {
        try {
            $v = Get-ItemProperty -Path $k -ErrorAction Stop
            foreach ($prop in @('InstallPath', 'InstallLocation', 'Path', 'HomeDir')) {
                if ($v.$prop) { $cands += $v.$prop }
            }
        }
        catch { }
    }
    $cands += @(
        'C:\Program Files (x86)\Labcenter Electronics\Proteus 8 Professional',
        'C:\Program Files\Labcenter Electronics\Proteus 8 Professional',
        'D:\Program Files (x86)\Labcenter Electronics\Proteus 8 Professional',
        'D:\Program Files\Labcenter Electronics\Proteus 8 Professional')
    foreach ($c in $cands) {
        if ($c -and (Test-Path (Join-Path $c 'Translations'))) { return (Resolve-Path $c).Path }
    }
    return $null
}

$dir = Resolve-ProteusDir -Hint $InstallDir
if (-not $dir) {
    Write-Host "[×] 未找到 Proteus 安装目录，请用 -InstallDir 参数指定。" -ForegroundColor Red
    exit 1
}

$dstDir = Join-Path $dir 'Translations'
$dst = Join-Path $dstDir 'proteus_zh_CN.qm'

Write-Host "安装目录：$dir"
if (Test-Path $dst) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = "$dst.bak-$stamp"
    Copy-Item -LiteralPath $dst -Destination $bak -Force
    Write-Host "[√] 已备份原文件：$bak"
}
else {
    Write-Host "[i] 系统当前没有 proteus_zh_CN.qm（英文界面），无需备份。"
}

Copy-Item -LiteralPath $src -Destination $dst -Force
$f = Get-Item -LiteralPath $dst
$hash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.Substring(0, 16)
Write-Host ("[√] 汉化已安装：{0}（{1} 字节, SHA256:{2}...）" -f $dst, $f.Length, $hash) -ForegroundColor Green
Write-Host ""
Write-Host "重启 Proteus 后即为中文界面。如需还原英文，运行「还原英文.ps1」。"

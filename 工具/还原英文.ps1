#Requires -Version 5.1
<#
  一键还原 Proteus 英文界面
  -----------------------------------------------------------------
  - 若存在备份（proteus_zh_CN.qm.bak-*），恢复最新备份
  - 否则直接删除 proteus_zh_CN.qm

  用法：
      powershell -ExecutionPolicy Bypass -File 还原英文.ps1
      powershell -ExecutionPolicy Bypass -File 还原英文.ps1 -InstallDir "D:\...\Proteus 8 Professional"
#>
param([string]$InstallDir = "")

$ErrorActionPreference = 'Stop'

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
        'C:\Program Files\Labcenter Electronics\Proteus 8 Professional')
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

$dst = Join-Path $dir 'Translations\proteus_zh_CN.qm'

if (-not (Test-Path $dst)) {
    Write-Host "[i] 未发现 proteus_zh_CN.qm，当前已是英文界面，无需处理。"
    exit 0
}

$baks = @(Get-ChildItem -Path ((Split-Path $dst -Parent) + '\proteus_zh_CN.qm.bak-*') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending)
Remove-Item -LiteralPath $dst -Force
if ($baks.Count -gt 0) {
    Copy-Item -LiteralPath $baks[0].FullName -Destination $dst -Force
    Write-Host ("[√] 已恢复备份：{0}" -f $baks[0].Name) -ForegroundColor Green
}
else {
    Write-Host "[√] 已删除汉化文件，重启 Proteus 即回到英文界面。" -ForegroundColor Green
}

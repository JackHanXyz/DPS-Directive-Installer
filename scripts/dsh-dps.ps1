param(
    [ValidateSet('install', 'update', 'uninstall', 'status')]
    [string]$Action = 'install',
    [string]$DpsRoot = '',
    [string]$Profile = 'desktop',
    [string]$Source = 'github:liucaimao2026/dsh-personal-directive',
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'
$PackageName = 'dsh-personal-directive'

function Write-Step($msg) { Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[! ] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "[X] $msg" -ForegroundColor Red }

function Find-DpsRoot {
    param([string]$Hint)

    if ($Hint -and (Test-Path $Hint)) { return (Resolve-Path $Hint).Path }

    # 1) 注册表卸载项（DPS 桌面版 = DeepSeek Harness）
    $uninstallKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($key in $uninstallKeys) {
        $items = Get-ItemProperty $key -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match 'DeepSeek Harness|DSH Desktop' -and $_.InstallLocation }
        foreach ($item in $items) {
            if (Test-Path $item.InstallLocation) { return $item.InstallLocation }
        }
    }

    # 2) 常见安装位置
    $candidates = @(
        'D:\DPS', 'C:\DPS',
        "$env:ProgramFiles\DeepSeek Harness",
        "${env:ProgramFiles(x86)}\DeepSeek Harness",
        "$env:LOCALAPPDATA\Programs\DeepSeek Harness",
        "$env:LOCALAPPDATA\DeepSeek Harness"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path (Join-Path $c 'resources\runtime\cli\bin\dsh.cmd'))) { return $c }
    }
    return $null
}

function Get-DshHome {
    if ($env:DSH_HOME) { return $env:DSH_HOME.Trim() }
    return (Join-Path $env:USERPROFILE '.dsh')
}

function Get-ProfileDir {
    param([string]$HomeDir, [string]$Name)
    return (Join-Path (Join-Path $HomeDir 'profiles') $Name)
}

function Get-DshCmd {
    param([string]$Root)
    return (Join-Path $Root 'resources\runtime\cli\bin\dsh.cmd')
}

function Backup-Profile {
    param([string]$ProfileDir)
    if ($NoBackup) { Write-Warn '已跳过备份（-NoBackup）'; return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest = Join-Path $PSScriptRoot "backup\$stamp"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($f in @('package.json', 'cordis.patch.yml')) {
        $src = Join-Path $ProfileDir $f
        if (Test-Path $src) { Copy-Item $src (Join-Path $dest "$f.bak") -Force }
    }
    Write-Ok "已备份 profile 配置到: $dest"
}

function Test-PackageInstalled {
    param([string]$ProfileDir)
    $pkgFile = Join-Path $ProfileDir 'package.json'
    if (-not (Test-Path $pkgFile)) { return $false }
    try {
        $pkg = Get-Content $pkgFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $hasDep = $pkg.dependencies.PSObject.Properties.Name -contains $PackageName
        $hasBundle = @($pkg.dsh.profile.bundles) -contains $PackageName
        $hasDir = Test-Path (Join-Path $ProfileDir "node_modules\$PackageName")
        return ($hasDep -and $hasBundle -and $hasDir)
    } catch {
        return $false
    }
}

function Repair-PluginCompat {
    # 上游插件是按更早的 DSH 写的，在 0.2.2-rc.5 上有两处不兼容：
    #   1) typert 要求 strict codec 带 create() 工厂。缺失时 host 侧 apply 抛错、
    #      effect 回滚，插件停在 fiberPhase: failed，提示词根本没注入。
    #   2) client 侧图标导出名从 IconXxxOutline16 改成 IconXxxOutlineRegular。
    #      解构到 undefined 后整个 slot 渲染抛 React #130，按钮不显示（host 侧却显示正常）。
    param([string]$ProfileDir)
    $pluginDir = Join-Path $ProfileDir "node_modules\$PackageName"
    if (-not (Test-Path $pluginDir)) { return 0 }

    $iconImportOld = @'
    const {
      Button,
      IconCheckOutline16,
      IconCloseOutline16,
      IconLoadingOutline16,
    } = require("@deepseek-ai/dsh-client-ui-primitives");
'@

    $iconImportNew = @'
    const primitives = require("@deepseek-ai/dsh-client-ui-primitives");
    const Button = primitives.Button;
    const resolveIcon = (...names) => {
      for (const name of names) {
        const candidate = primitives[name];
        if (candidate !== undefined && candidate !== null) return candidate;
      }
      return null;
    };
    const IconCheck = resolveIcon("IconCheckOutline16", "IconCheckOutlineRegular", "IconCheck16");
    const IconClose = resolveIcon("IconCloseOutline16", "IconCloseOutlineRegular", "IconClose16");
    const IconLoading = resolveIcon("IconLoadingOutline16", "IconLoadingOutlineRegular", "IconLoading16");
'@

    $iconUsageOld = @'
      const icon = state.busy
        ? h(IconLoadingOutline16, { size: 14 })
        : state.enabled
          ? h(IconCheckOutline16, { size: 14 })
          : h(IconCloseOutline16, { size: 14 });
'@

    $iconUsageNew = @'
      const iconGlyph = state.busy ? IconLoading : state.enabled ? IconCheck : IconClose;
      const icon = iconGlyph ? h(iconGlyph, { size: 14 }) : undefined;
'@

    $patches = @(
        @{
            File   = 'index.js'
            Marker = 'create: () => schema'
            Old    = 'return { mode: "strict", typeSymbol, schema };'
            New    = 'return { mode: "strict", typeSymbol, schema, create: () => schema };'
        },
        @{
            File   = 'lib\client.js'
            Marker = 'create: () =>'
            Old    = '      schema: { parse: identity },'
            New    = "      schema: { parse: identity },`n      create: () => ({ parse: identity }),"
        },
        @{
            File   = 'lib\client.js'
            Marker = 'resolveIcon'
            Old    = $iconImportOld
            New    = $iconImportNew
        },
        @{
            File   = 'lib\client.js'
            Marker = 'iconGlyph'
            Old    = $iconUsageOld
            New    = $iconUsageNew
        }
    )

    $fixed = 0
    foreach ($patch in $patches) {
        $file = Join-Path $pluginDir $patch.File
        if (-not (Test-Path $file)) { continue }
        $text = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
        # 上游文件可能是 CRLF，多行匹配统一成 LF 再比对
        $text = $text.Replace("`r`n", "`n")
        if ($text.Contains($patch.Marker)) { continue }
        if (-not $text.Contains($patch.Old)) { continue }
        $text = $text.Replace($patch.Old, $patch.New)
        $tmp = "$file.new"
        [System.IO.File]::WriteAllText($tmp, $text, [System.Text.UTF8Encoding]::new($false))
        # 先删再替换，断开 pnpm 硬链接，避免污染全局 store
        Remove-Item $file -Force
        Move-Item $tmp $file
        $fixed++
    }
    return $fixed
}

function Invoke-Dsh {
    param([string]$DshCmd, [string[]]$DshArgs)
    & $DshCmd @DshArgs
    if ($LASTEXITCODE -ne 0) {
        throw "dsh 命令失败 (exit=$LASTEXITCODE): $($DshArgs -join ' ')"
    }
}

function Show-Status {
    param([string]$DshHome, [string]$ProfileDir, [string]$DshCmd, [string]$Root)
    Write-Host ''
    Write-Host '=== DPS 桌面版破甲插件状态 ===' -ForegroundColor White
    Write-Host ("  安装根目录   : {0}" -f $Root)
    Write-Host ("  内置 dsh 命令: {0}" -f $DshCmd)
    Write-Host ("  DSH_HOME     : {0}" -f $DshHome)
    Write-Host ("  profile      : {0} ({1})" -f $Profile, $ProfileDir)
    $installed = Test-PackageInstalled $ProfileDir
    if ($installed) {
        $pkgFile = Join-Path $ProfileDir 'package.json'
        $pkg = Get-Content $pkgFile -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host ("  插件依赖     : {0}" -f $pkg.dependencies.$PackageName) -ForegroundColor Green
        Write-Host ("  bundle 注册  : 已包含 {0}" -f $PackageName) -ForegroundColor Green
        Write-Ok '安装完整'
    } else {
        Write-Warn '未安装或安装不完整'
    }
    $procs = @(Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue)
    if ($procs.Count -gt 0) {
        Write-Warn "桌面版正在运行（PID: $(($procs | ForEach-Object Id) -join ', ')），改动需重启后生效"
    } else {
        Write-Host '  桌面版进程   : 未运行' -ForegroundColor Gray
    }
    Write-Host ''
}

# ---------- 主流程 ----------
Write-Host ''
Write-Host 'DPS 桌面版 (DeepSeek Harness) 破甲插件一键脚本' -ForegroundColor White
Write-Host '----------------------------------------------' -ForegroundColor DarkGray

$root = Find-DpsRoot $DpsRoot
if (-not $root) {
    Write-Fail '找不到 DPS 桌面版安装目录。请用 -DpsRoot "D:\DPS" 指定。'
    exit 2
}
$dshCmd = Get-DshCmd $root
if (-not (Test-Path $dshCmd)) {
    Write-Fail "找不到内置 dsh 命令: $dshCmd"
    exit 3
}
$dshHome = Get-DshHome
$profileDir = Get-ProfileDir $dshHome $Profile
if (-not (Test-Path $profileDir)) {
    Write-Warn "profile 目录不存在，dsh plugin 会自动创建: $profileDir"
}

switch ($Action) {
    'status' {
        Show-Status $dshHome $profileDir $dshCmd $root
    }
    'install' {
        if (Test-PackageInstalled $profileDir) {
            $patched = Repair-PluginCompat $profileDir
            if ($patched -gt 0) { Write-Ok "已修正插件兼容问题（$patched 处），重启后生效。" }
            Write-Ok "插件已安装且配置完整（$PackageName），无需重复安装。"
            Show-Status $dshHome $profileDir $dshCmd $root
            exit 0
        }
        Write-Step "安装目录: $root"
        Write-Step "profile  : $profileDir"
        Backup-Profile $profileDir
        Write-Step '正在安装插件（首次需要联网下载依赖，约 1 分钟）...'
        Invoke-Dsh $dshCmd @('plugin', '--profile', $Profile, 'add', $Source)
        if (Test-PackageInstalled $profileDir) {
            Write-Ok '安装完成，依赖与 bundle 均已写入。'
            $patched = Repair-PluginCompat $profileDir
            if ($patched -gt 0) { Write-Ok "已应用插件兼容补丁（$patched 处）。" }
        } else {
            Write-Warn '依赖已安装，但 profile 配置校验未通过，请检查 package.json。'
        }
        Show-Status $dshHome $profileDir $dshCmd $root
        Write-Warn '请完全退出并重新打开 DPS 桌面版，然后在会话顶部查看「破甲：开启/关闭」按钮。'
    }
    'update' {
        Write-Step "更新插件: $PackageName"
        Invoke-Dsh $dshCmd @('plugin', '--profile', $Profile, 'update', $PackageName)
        $patched = Repair-PluginCompat $profileDir
        if ($patched -gt 0) { Write-Ok "更新后重新应用插件兼容补丁（$patched 处）。" }
        Write-Ok '更新完成，重启桌面版后生效。'
        Show-Status $dshHome $profileDir $dshCmd $root
    }
    'uninstall' {
        Write-Step "卸载插件: $PackageName"
        Backup-Profile $profileDir
        Invoke-Dsh $dshCmd @('plugin', '--profile', $Profile, 'remove', $PackageName)
        Write-Ok '卸载完成，重启桌面版后生效。'
        Show-Status $dshHome $profileDir $dshCmd $root
    }
}

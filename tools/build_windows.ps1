# 文件用途：验证工程并生成Windows便携测试包，构建产物放在仓库外且保留已有存档。
param([string]$Engine = "", [switch]$SkipTests, [string]$BuildRoot = "")
$ErrorActionPreference = 'Stop'
# 路径模块：从脚本位置推导工程、引擎和导出目录，避免硬编码开发机盘符。
$repo = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repo 'game'
$base = Split-Path -Parent $repo
if (-not $BuildRoot) { $BuildRoot = Join-Path $base "builds\FrontierGuardian" }
if (-not $Engine) { $Engine = Join-Path $base 'tools\Godot\4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $Engine)) { throw "找不到Godot：$Engine" }
# 执行模块：任何导入、测试或导出失败都停止，不把失败构建当成成功。
function Invoke-GodotStep([string[]]$Arguments) {
    & $Engine @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Godot步骤失败：$($Arguments -join ' ')" }
}
# 验证模块：先导入新资源，再执行独立数据库与场景回归。
Invoke-GodotStep @('--headless', '--editor', '--path', $project, '--import')
if (-not $SkipTests) {
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/sqlite_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/smoke_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/strategic_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/world_scene_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/town_map_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/placement_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/construction_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/construction_progress_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/labor_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/food_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/storage_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/material_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/inspection_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/removal_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/civic_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/army_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/army_disband_test.gd')
    Invoke-GodotStep @('--headless', '--path', $project, '--script', 'res://tests/legion_test.gd')
}
# 许可模块：从本次使用的引擎提取声明，避免遗漏内置第三方许可证。
$notice = Join-Path $repo 'docs\licenses\Godot-ThirdPartyNotices.txt'
Invoke-GodotStep @('--headless', '--path', $project, '--script', (Join-Path $PSScriptRoot 'write_engine_notices.gd'), '--', $notice)
# 导出模块：debug和release分目录，禁止删除local_data中的用户存档。
foreach ($variant in @('debug', 'release')) {
    $directory = Join-Path $BuildRoot $variant
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $output = Join-Path $directory 'FrontierGuardian.exe'
    $flag = if ($variant -eq 'debug') { '--export-debug' } else { '--export-release' }
    Invoke-GodotStep @('--headless', '--path', $project, $flag, 'Windows Portable', $output)
    if (-not (Test-Path -LiteralPath $output)) { throw "未生成程序：$output" }
    Copy-Item -LiteralPath (Join-Path $repo 'game\addons\godot-sqlite\LICENSE.md') -Destination (Join-Path $directory 'SQLite-LICENSE.md') -Force
    Copy-Item -LiteralPath $notice -Destination (Join-Path $directory 'Godot-ThirdPartyNotices.txt') -Force
    Write-Output "BUILD_READY: $output"
}

# 回归模块：对实际导出包执行独立进程存档测试。
& (Join-Path $PSScriptRoot 'verify_windows.ps1') -BuildRoot $BuildRoot

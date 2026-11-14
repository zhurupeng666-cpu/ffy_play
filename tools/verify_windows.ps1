# 文件用途：对已导出的debug与release程序进行跨进程存档验收，不修改用户手动存档。
param([string]$BuildRoot = "")
$ErrorActionPreference = 'Stop'
# 路径模块：默认定位E盘项目根目录旁的构建产物。
if (-not $BuildRoot) { $BuildRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'builds\FrontierGuardian' }
# 验收模块：每种构建启动两个独立进程，必须返回成功标记和零退出码。
foreach ($variant in @('debug', 'release')) {
    $directory = Join-Path $BuildRoot $variant
    $executable = Join-Path $directory 'FrontierGuardian.exe'
    if (-not (Test-Path -LiteralPath $executable)) { throw "缺少构建：$executable" }
    $testDirectory = Join-Path $directory 'local_data\tests'
    New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null
    foreach ($check in @('export=write', 'export=read', 'world=write', 'world=read')) {
        $kind, $mode = $check.Split('=')
        $marker = if ($kind -eq 'world') { 'EXPORT_WORLD_PASS' } else { 'EXPORT_SQLITE_PASS' }
        $out = Join-Path $testDirectory "$kind-$mode.stdout.log"
        $err = Join-Path $testDirectory "$kind-$mode.stderr.log"
        $process = Start-Process -FilePath $executable -ArgumentList @('--headless','--',"--verify-$kind=$mode") -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        if (-not $process.WaitForExit(20000)) {
            Stop-Process -Id $process.Id
            throw '导出程序测试超时'
        }
        $process.Refresh()
        $output = Get-Content -LiteralPath $out -Raw
        if ($process.ExitCode -ne 0 -or $output -notmatch ($marker + ': ' + $mode)) {
            throw "导出程序验收失败：$variant / $mode，请检查 $testDirectory"
        }
        Write-Output "EXPORT_CHECK_PASS: $variant / $kind / $mode"
    }
}

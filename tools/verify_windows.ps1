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
    foreach ($check in @('export=write', 'export=read', 'world=write', 'world=read', 'build=write', 'build=read', 'food=write', 'food=read', 'storage=write', 'storage=read', 'material=write', 'material=read', 'inspect=write', 'inspect=read', 'removal=write', 'removal=read', 'civic=write', 'civic=read', 'army=write', 'army=read')) {
        $kind, $mode = $check.Split('=')
        $marker = if ($kind -eq 'world') { 'EXPORT_WORLD_PASS' } elseif ($kind -eq 'army') { 'EXPORT_ARMY_PASS' } elseif ($kind -eq 'civic') { 'EXPORT_CIVIC_PASS' } elseif ($kind -eq 'removal') { 'EXPORT_REMOVAL_PASS' } elseif ($kind -eq 'inspect') { 'EXPORT_INSPECT_PASS' } elseif ($kind -eq 'material') { 'EXPORT_MATERIAL_PASS' } elseif ($kind -eq 'storage') { 'EXPORT_STORAGE_PASS' } elseif ($kind -eq 'food') { 'EXPORT_FOOD_PASS' } elseif ($kind -eq 'build') { 'EXPORT_BUILD_PASS' } else { 'EXPORT_SQLITE_PASS' }
        $out = Join-Path $testDirectory "$kind-$mode.stdout.log"
        $err = Join-Path $testDirectory "$kind-$mode.stderr.log"
        # 进程模块：自行持有进程句柄，避免Windows PowerShell丢失快速退出进程的退出码。
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $executable
        $process.StartInfo.Arguments = "--headless -- --verify-$kind=$mode"
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $null = $process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(20000)) {
            Stop-Process -Id $process.Id
            throw '导出程序测试超时'
        }
        $process.WaitForExit()
        [IO.File]::WriteAllText($out, $stdoutTask.Result, [Text.UTF8Encoding]::new($true))
        [IO.File]::WriteAllText($err, $stderrTask.Result, [Text.UTF8Encoding]::new($true))
        $output = Get-Content -LiteralPath $out -Raw
        if ($process.ExitCode -ne 0 -or $output -notmatch ($marker + ': ' + $mode)) {
            throw "导出程序验收失败：$variant / $mode，请检查 $testDirectory"
        }
        $process.Dispose()
        Write-Output "EXPORT_CHECK_PASS: $variant / $kind / $mode"
    }
}

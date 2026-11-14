# Windows独立测试包验收

## 构建范围

Godot 4.7.2标准版，Windows x86_64，Compatibility渲染。已生成debug与release两个独立测试包，不需要编辑器运行。当前仍是金币存取验证场景，非正式游戏版本。

## 模板与依赖

从Godot官网下载4.7.2官方模板包中的windows_debug_x86_64.exe、windows_release_x86_64.exe与version.txt。为减少占用，未安装其他平台模板。HTTP范围下载通过标准ZIP读取器执行CRC校验，模板版本文件为4.7.2.stable。

模板安装位置：E:\playproject\tools\Godot\4.7.2-stable\editor_data\export_templates\4.7.2.stable。

来源：https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.7.2 。

SQLite由导出器自动复制对应的debug或release原生DLL。每个文件夹包含exe、pck、SQLite DLL、SQLite许可证和Godot及内置第三方许可声明，必须保留整个目录，不能只拿exe。

## 产物与路径

- release：E:\playproject\builds\FrontierGuardian\release\FrontierGuardian.exe。
- debug：E:\playproject\builds\FrontierGuardian\debug\FrontierGuardian.exe。
- 手动存档：每个程序旁local_data/saves/frontier_test.db。
- 自动验收库：每个程序旁local_data/tests/export_probe.db，与手动槽隔离。

便携测试包使用portable_test特性，将存档放在可执行文件旁。它与开发态game/local_data中的存档分开，首次启动不自动导入开发存档。目录必须可写；不要放到受保护的安装目录。此规则适用于当前便携测试包，正式安装版的存档政策以后另行确定。

导出包关闭默认文件日志，避免沿用开发机硬编码日志路径；命令行验收日志由测试脚本重定向到包内local_data/tests。未启用自动保存，仍需手动点击保存。

## 构建与复测

PowerShell执行 tools/build_windows.ps1：导入工程 → SQLite与场景回归 → 提取引擎许可 → 导出debug与release → 自动验证实际导出包。路径基于脚本位置计算，输出到仓库旁builds目录；不删除已有local_data。

单独执行 tools/verify_windows.ps1 可复测现有导出包。命令行验收只识别 --verify-export=write 或read，使用隔离测试库。

## 已执行验收

- 编辑器SQLite、独立子进程持久化与暂停恢复回归通过。
- Windows debug导出成功，独立进程写170、退出、第二进程读170，退出码均0。
- Windows release导出成功，相同测试通过，退出码均0。
- 输出EXPORT_CHECK_PASS: debug/write、debug/read、release/write、release/read。
- 从release目录直接运行exe，窗口、中文、金币初始100与数据库就绪提示正常，Esc关闭。此图形运行不是通过编辑器启动。
- 自动验收未写入手动槽，用户可从初始100开始测试。
- local_data、导出构建和模板均不提交Git，保留源码、导出预设与复测脚本。

当前仅在本机验证；尚未做另一台干净Windows电脑的兼容性测试，也未制作安装器和商业签名。

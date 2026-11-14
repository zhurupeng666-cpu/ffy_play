# 最小工程与VS Code环境验收

日期：2026年11月14日。

## 打开方式

用VS Code打开仓库根目录的 FrontierGuardian.code-workspace，或直接打开 game 文件夹。不要只打开仓库根目录，否则game内的调试设置不会成为当前文件夹配置。

VS Code中的受限模式会禁用开发插件。请用户自行确认本地工作区可信后，再使用补全和F5调试；自动化不更改此安全设置。

## 已完成与证据

- 安装VS Code插件 geequlim.godot-tools 2.7.1。
- 引擎锁定4.7.2.stable.official.ed1daf0bf，位于E盘。
- 创建game/project.godot、scenes/main.tscn、带类型的scripts/main.gd。
- 渲染方式为Compatibility；实际图形运行识别为OpenGL 3.3、NVIDIA GeForce RTX 3060 Laptop GPU。
- 图形窗口正常显示标题、运行秒数、暂停按钮与操作说明；已通过实际空格操作验证暂停，Esc退出。
- 无窗口测试运行、暂停、恢复，输出 SMOKE_PASS: scene, time, pause, resume，退出码0。
- 本地语言服务在127.0.0.1:6008初始化成功，completion请求返回666项。此为语言服务协议测试，不等同于VS Code界面已显示补全。
- 已配置Godot外部编辑器为现有VS Code，并启用脚本外部修改自动重载。
- VS Code已配置语言服务自动启动、F5调试和自动测试任务；调试端口6007。

## 待用户信任工作区后的验收

观察到VS Code顶部显示受限模式，插件未启用。为避免更改用户安全设置，尚未在VS Code中验证补全弹窗与断点命中。

1. 用户确认该本地工作区可信。
2. 打开scripts/main.gd，检查右下角语言模式为GDScript，验证补全。
3. 在_process中elapsed_seconds += delta处设置断点（当前第17行），按F5。
4. 验证程序停在断点，能查看delta和elapsed_seconds变量；取消断点后继续运行。
5. 验证暂停按钮或空格切换状态；Esc退出游戏，Shift+F5停止调试。

若6008端口被其他工程占用，先关闭其他工程语言服务，不让多个项目抢同一端口。

## 自动复测

VS Code运行任务 Godot: smoke test，或PowerShell执行：

```powershell
& 'E:\playproject\tools\Godot\4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\playproject\ffy_play\game' --script res://tests/smoke_test.gd
```

## 数据与范围

测试界面仅为环境占位，英文用于避免现阶段引入字体资源，不代表正式语言或美术选择。elapsed_seconds只是环境验证计时器，不是设计文档中的战略时钟。

开发日志显式写到E:/playproject/ffy_play/game/local_data/logs/godot.log，local_data与.godot缓存已被Git忽略。Godot的user://仍解析到Windows用户目录，本阶段不使用其保存业务数据；首次测试曾生成默认日志。后续SQLite开发存档应明确使用E盘local_data目录，正式发布时另配玩家可写目录，不沿用开发机绝对路径。当前日志绝对路径同样只适用于本机开发，发布前需要替换。

引擎便携模式管理编辑器数据，不保证游戏user://也随之移到E盘。本记录更正此前对便携数据范围可能产生的误解。

本阶段未安装SQLite扩展、未下载导出模板、未实现实际经营或战斗系统。

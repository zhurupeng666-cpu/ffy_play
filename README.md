# Frontier Guardian

Windows PC 单人 2D 等距像素经营战争游戏。

## 已确认的技术方案

- 引擎：Godot 4.x 稳定标准版，环境验证后锁定完整版本。
- 主语言：带类型的 GDScript。
- C++：仅在性能分析确认瓶颈后，以 GDExtension 接入。
- 静态配置：Godot Resource。
- 运行状态：内存中的统一 WorldState。
- 本地存档：SQLite，不使用 MySQL 服务。
- 编辑器：VS Code 配合 Godot 编辑器。
- 项目目录：E:\playproject\ffy_play。

技术决策及下一步验收见 docs/技术选型与环境准备.md。
历史设计见 docs/archive；历史文档中的 JSON 主存档方案已被 SQLite 方案替代。

## 同步规则

每完成一个可验收步骤，检查差异，提交本地 Git，再推送 origin。
推送失败必须明确报告，禁止强制推送或覆盖远程历史。

## 初始阶段记录（历史）

已确认架构并整理文档。Godot 4.7.2 标准版已安装并通过签名、版本和无窗口脚本启动检查。图形编辑器、导出模板、VS Code联调及SQLite插件尚待验证。详见 docs/Godot安装验收记录.md。

## 最小工程

打开 FrontierGuardian.code-workspace 使用VS Code开发。game已包含可运行占位场景与运行暂停测试；详细操作和待验收项见 docs/最小工程与VSCode环境验收.md。工作区已解除受限模式；Godot语言服务连接与VS Code断点命中、变量检查已实际验证。每步测试方法见 docs/开发测试指南.md。

## SQLite开发态进度

已接入godot-sqlite v4.9，实现测试金币加值、保存和读取；跨连接与独立进程持久化、回滚和版本保护测试通过。操作方法见docs/开发测试指南.md，范围及未验收项见docs/SQLite开发态接入验收.md。此前SQLite尚未验证的记录为历史状态。Windows导出后加载验证仍待完成。

## Windows导出进度

Windows debug与release独立测试包已导出，两个构建均通过独立进程SQLite保存读取。入口为仓库旁 builds/FrontierGuardian/release/FrontierGuardian.exe。构建脚本为 tools/build_windows.ps1，复测脚本为 tools/verify_windows.ps1，手动测试步骤见docs/开发测试指南.md。具体范围见docs/Windows独立测试包验收.md；此前导出待验收的描述为历史状态。

## 当前战略原型入口

默认运行已切换为战略日期与资源面板，支持暂停、1/2/4倍速、每日扣粮收税及完整快照存档。全部参数待平衡。旧金币测试与旧档保留但不再默认启动。最新测试方法见docs/开发测试指南.md步骤四，架构与范围见docs/战略时钟与资源原型验收.md。

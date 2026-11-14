# Godot 安装验收记录

日期：2026年11月14日。

## 已完成

- 引擎：Godot 4.7.2 stable 标准版，Windows x86_64。
- 实际版本输出：4.7.2.stable.official.ed1daf0bf。
- 安装目录：E:\playproject\tools\Godot\4.7.2-stable。
- 图形程序：Godot_v4.7.2-stable_win64.exe。
- 控制台程序：Godot_v4.7.2-stable_win64_console.exe。
- 使用 _sc_ 标记启用便携模式，编辑器数据保存在引擎目录下的 editor_data。
- 来源：https://godotengine.org/download/windows/ 。下载Windows标准版，未安装.NET版。
- Windows Authenticode数字签名检查：Valid，Signature verified。
- 下载包SHA256：731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953。此值用于本地文件识别；来源验证依据为官方链接与数字签名。
- 命令行 --headless --version 成功。
- 无窗口模式执行最小带类型GDScript成功，输出 GDSCRIPT_SMOKE_OK，退出码0。
- 引擎和下载包均位于仓库外，不上传GitHub。

## 下一步

1. 验证Godot图形编辑器与本机显卡兼容性。
2. 安装并验证同版本4.7.2导出模板。
3. 配置VS Code插件、代码补全与断点调试。
4. 创建最小工程并验证SQLite扩展的兼容性、事务与Windows导出。

以上未完成事项不能视为已经验收。SQLite扩展若不兼容当前版本，应先调查可用版本组合，再决定调整引擎版本，不能直接升级或降级覆盖现有安装。

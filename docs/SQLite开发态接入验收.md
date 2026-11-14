# SQLite开发态接入验收

## 当前范围

已完成Windows x86_64开发态SQLite接入，Godot 4.7.2可加载插件。此场景仅验证一个测试金币数值，尚未实现正式世界存档、多存档槽、备份恢复和发布版路径配置。

## 依赖

- 插件：2shady4u/godot-sqlite，锁定v4.9。
- 来源：https://github.com/2shady4u/godot-sqlite/releases/tag/v4.9 。
- 扩展最低Godot版本：4.7；实际验证引擎4.7.2.stable.official.ed1daf0bf。
- 授权：MIT，完整许可证保留在game/addons/godot-sqlite/LICENSE.md。
- 原始addons.zip的SHA256：95E91B72FE32984A84EDAF6357A78753661F37A170CB362F5B948E0EDE7C2CB0，用于锁定下载包；未宣称与独立签名校验值比较。
- 仅加入Windows x86_64 debug与release DLL和原始配置文件；其他平台未安装，不应据此导出其他平台。
- 第三方代码保留原始注释与许可，不按本项目中文注释约定改写。

## 实现

sqlite_save_repository.gd负责打开数据库、检查PRAGMA user_version、事务初始化、参数绑定保存、读取和关闭。main.gd只调用仓库，不直接执行SQL。

数据库表test_save只有一个槽位，slot_id=1、gold为0至9999999的整数。保存用BEGIN IMMEDIATE、参数绑定INSERT/UPDATE与COMMIT，失败尝试ROLLBACK。读取失败或空槽不会修改内存金币。拒绝高于当前版本的数据库，避免新档被旧程序覆盖。

开发存档路径由工程位置计算，为 game/local_data/saves/frontier_test.db。它位于E盘，已加入忽略规则。编辑器运行初始金币总为100，需要主动点击读取，不自动覆盖存档。仅在点击保存后写入，不自动保存退出时的数值。

非编辑器引擎运行预留user://路径作为未来发布方案，但发布版导出与该路径尚未验收，不能视为发布准备完成。

## 已执行测试

- 插件导入及原生SQLite类型加载。
- 空槽反馈。
- 保存130，关闭连接，创建新连接后读取130。
- 独立Godot子进程读取同一数据库，输出SQLITE_CHILD_REOPEN_PASS。
- 拒绝负数与超上限数值，旧档仍为130。
- 在显式事务内写999后ROLLBACK，读取仍为130。
- 数据库版本改成999后拒绝打开。
- 界面加值、保存、修改、读取后恢复110，提示读取成功。
- 原计时推进、暂停与恢复回归通过。
- 实际图形窗口中文可读，按钮与状态提示无截断；加值和空槽提示已实际点击检查，未给用户手动槽写入测试金币。

自动测试使用local_data/tests内唯一临时数据库，成功后关闭并删除，不触碰手动存档。失败保留测试库供排查。运行命令见开发测试指南。

## 待验收

同版本导出模板安装、Windows debug/release导出后的DLL加载与存档路径、SQLite备份能力和损坏库恢复。以上属于后续步骤，不影响本次开发态测试结论。

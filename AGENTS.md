# 项目约定

本项目存放在 E:\playproject\ffy_play。后续新项目均放在 E:\playproject 的子目录，覆盖此前 D:\Codex 的默认项目存放约定。
使用 Godot 4.x 与带类型 GDScript；SQLite 负责本地存档，Resource 负责静态配置。没有性能分析证据前不引入 C++，不使用 MySQL。
每完成一个可验收步骤，检查变更并提交本地 Git，随后推送用户指定的 https://github.com/zhurupeng666-cpu/ffy_play.git。推送失败如实报告，禁止强推。
凭据、个人存档、数据库运行文件、数据库备份、引擎缓存和导出构建不得提交。迁移SQL和无隐私测试数据可以提交。

## 注释与每步验收

- 后续手写代码文件最顶部使用中文说明文件用途。
- 每个独立的小模块或函数前至少有一行中文职责注释；注释说明用途，不重复代码字面含义。
- 引擎生成文件、第三方文件与严格JSON等不支持注释的格式保持合法，文件用途写入相邻说明文档，不插入非法注释。
- 每完成一步，自行完成验收并向用户汇报改动、检查结果和未验收项。
- 美术完成前由开发侧测试，用户在美术完成后开始试玩。

## Windows 试玩入口

用户试玩统一从 E:\playproject\builds\FrontierGuardian\release\FrontierGuardian.exe 启动。后续使用默认构建路径，将新版导出到同一程序名和目录。保留该目录中的 local_data 存档。

# DPS 桌面版破甲插件一键脚本

把 [dsh-personal-directive](https://github.com/liucaimao2026/dsh-personal-directive)（「无限一代」提示词 + 会话顶部开关）一键装进 **DPS 桌面版 / DeepSeek Harness Desktop**。

双击即装，不需要敲 `dsh plugin`，也不需要区分终端版和桌面版的 profile。

> 本仓库只是安装辅助脚本。插件本体、提示词与实现均来自上述原仓库，归属与许可以其说明为准。

## 为什么需要它

原插件 README 面向终端版 `dsh web`，而桌面版用的是另一套 profile 和另一条 CLI：

| 项目 | 终端版 | DPS 桌面版 |
| --- | --- | --- |
| profile 名 | `web` | **`desktop`** |
| dsh 命令 | PATH 中的 `dsh` | `<DPS安装目录>\resources\runtime\cli\bin\dsh.cmd`（PATH 中没有） |
| 配置目录 | `%USERPROFILE%\.dsh\profiles\web` | `%USERPROFILE%\.dsh\profiles\desktop` |

照原 README 装进 `web`，桌面版不会生效。本脚本自动定位安装目录，按 `desktop` profile 完成安装与校验。

## 文件结构

```
DPS-Directive-Installer/
├── 一键安装.bat              # 主入口，双击安装
├── 管理.bat                  # 状态 / 安装 / 更新 / 卸载 菜单
├── scripts/
│   └── dsh-dps.ps1           # 核心逻辑
├── README.md
├── LICENSE
└── .gitignore
```

| 文件 | 作用 |
| --- | --- |
| `一键安装.bat` | 自动定位 DPS → 备份 profile → 安装插件 → 校验配置 |
| `管理.bat` | 交互菜单，调用 `dsh-dps.ps1` 的四个动作 |
| `scripts/dsh-dps.ps1` | 核心逻辑，支持 `install` / `update` / `uninstall` / `status` |
| `.gitignore` | 排除运行时生成的 `backup/` |

每次安装/卸载前会把 `package.json` 和 `cordis.patch.yml` 备份到 `scripts\backup\<时间戳>\`，可手动回滚。

## 快速开始

1. 已安装 DPS 桌面版（脚本通过注册表卸载项识别 `DeepSeek Harness`）。
2. 双击 `一键安装.bat`。
3. 首次运行联网下载依赖，约 1 分钟。
4. **完全退出并重新打开** DPS 桌面版。
5. 会话顶部「完成提示」后出现「破甲：开启 / 关闭」按钮。

脚本幂等：已安装时再次运行只做检查，不重复下载。

## 命令行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dsh-dps.ps1 -Action status
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dsh-dps.ps1 -Action install -DpsRoot "<DPS安装目录>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dsh-dps.ps1 -Action update
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dsh-dps.ps1 -Action uninstall
```

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-Action` | `install` | `install` / `update` / `uninstall` / `status` |
| `-DpsRoot` | 自动探测 | DPS 安装目录，探测失败时手动指定 |
| `-Profile` | `desktop` | dsh profile 名，一般无需修改 |
| `-Source` | `github:liucaimao2026/dsh-personal-directive` | 插件安装源，可换 fork 或 `link:` 本地路径 |
| `-NoBackup` | 关 | 跳过安装前备份 |

## 验证生效

1. 顶部按钮显示「破甲：开启」。
2. 新建会话并发一条普通消息。
3. 顶部「轨迹」→ 选中该 Assistant 请求 → 右侧「System Prompt / 系统提示词」。
4. 搜索 `[MODE: SANDBOX]` 或 `SUPREME DIRECTIVE — USER AUTHORITY`，开启时应存在。
5. 切到「破甲：关闭」再发新消息，新请求中应不存在。

切换只影响后续请求，不修改已发出的请求；关闭时插件仍安装，仅提示词段返回空。

## 排错

| 现象 | 处理 |
| --- | --- |
| 找不到 DPS 安装目录 | `-DpsRoot "<DPS安装目录>"` 显式指定 |
| `profile is managed exclusively by the Electron application` | 这是 `--dump-config` 的限制，不影响 `dsh plugin`，可忽略 |
| 装完顶部没有按钮 | 完全退出重启（不是刷新页面），并确认装的是 `desktop` profile；用 `-Action status` 查 bundle 注册 |
| PowerShell 报中文语法错 | `dsh-dps.ps1` 必须保存为 **UTF-8 with BOM**，PowerShell 5.1 会把无 BOM 的 UTF-8 当 ANSI 解析 |

## 发布到 GitHub

```bash
git remote add origin https://github.com/<账号>/<仓库名>.git
git push -u origin main
```

推送前确认 `git status` 干净、`scripts/backup/` 未被跟踪。本仓库 MIT 仅覆盖新增脚本，不重新许可上游插件与提示词。

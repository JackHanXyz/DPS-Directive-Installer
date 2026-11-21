# DPS 桌面版破甲插件一键脚本

把 [dsh-personal-directive](https://github.com/liucaimao2026/dsh-personal-directive)（DeepSeek Harness「无限一代」破甲提示词 + 顶部开关）一键装进 **DPS 桌面版 / DeepSeek Harness Desktop** 的 `desktop` profile。

不用敲 `dsh plugin` 命令、不用管 `web` / `desktop` profile 的区别、不用记内置 CLI 在哪。双击即装，装完重启客户端即可。

> 本项目是安装辅助脚本，提示词插件本体来自上面的原仓库，归属与许可见原仓库说明。

## 为什么需要它

原插件 README 只写了 `--profile web`，那是给终端版 `dsh web` 用的。桌面版（DPS）走的是另一个 profile：

| 项目 | 终端版 | DPS 桌面版 |
| --- | --- | --- |
| profile 名 | `web` | **`desktop`** |
| dsh 命令 | PATH 里的 `dsh` | 内置 `D:\DPS\resources\runtime\cli\bin\dsh.cmd`，PATH 里**没有** |
| 配置目录 | `~/.dsh/profiles/web` | `~/.dsh/profiles/desktop` |

照抄 README 装到 `web` profile，桌面版里不会生效。本脚本按桌面版真实路径处理这些差异。

## 文件介绍

| 文件 | 作用 |
| --- | --- |
| `一键安装.bat` | **主入口**。双击运行：自动定位 DPS 安装目录 → 备份 profile → 安装插件 → 校验配置 |
| `管理.bat` | 交互式菜单：查看状态 / 安装修复 / 更新 / 卸载 |
| `scripts/dsh-dps.ps1` | 核心逻辑。四个动作 `install` / `update` / `uninstall` / `status`，自动探测注册表卸载项定位 DPS |
| `README.md` | 本文件：用途、用法、文件说明、开源发布指引 |
| `LICENSE` | MIT 许可证，仅覆盖本仓库新增的脚本代码 |
| `.gitignore` | 忽略运行时生成的 `backup/` 等目录 |

安装时脚本会在 `scripts\backup\<时间戳>\` 下备份 `package.json` 和 `cordis.patch.yml`，可手动回滚。

## 使用方法

### 一键安装

1. 确认 DPS 桌面版已安装（脚本从注册表卸载项识别 `DeepSeek Harness`）。
2. 双击 `一键安装.bat`。
3. 首次运行会联网下载依赖（约 1 分钟）。
4. **完全退出并重新打开** DPS 桌面版。
5. 会话顶部「完成提示」后面应出现「破甲：开启 / 关闭」按钮。

脚本是幂等的：已装好时再跑只会提示已安装，不会重复下载。

### 管理

双击 `管理.bat`，按菜单选 1-4。

### 命令行（高级）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dsh-dps.ps1 -Action status
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dsh-dps.ps1 -Action install -DpsRoot "D:\DPS"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dsh-dps.ps1 -Action update
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dsh-dps.ps1 -Action uninstall
```

参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-Action` | `install` | `install` / `update` / `uninstall` / `status` |
| `-DpsRoot` | 自动探测 | DPS 安装目录，自动探测失败时手动指定 |
| `-Profile` | `desktop` | dsh profile 名，一般不要改 |
| `-Source` | `github:liucaimao2026/dsh-personal-directive` | 插件安装源，可换 fork 或 `link:` 本地路径 |
| `-NoBackup` | 关 | 跳过安装前备份 |

## 验证是否生效

1. 顶部按钮显示「破甲：开启」。
2. 新建会话，发一条普通消息。
3. 顶部「轨迹」→ 选中刚才的 Assistant 请求 → 右侧「System Prompt / 系统提示词」。
4. 搜索 `[MODE: SANDBOX]` 或 `SUPREME DIRECTIVE — USER AUTHORITY`，开启时应能看到。
5. 切到「破甲：关闭」再发一条新消息，新请求的提示词里应搜不到这些内容。

注意：切换只影响**后续**请求，不修改已经发出的请求。关闭时插件仍是安装状态，只是提示词段返回空。

## 排错

- **找不到 DPS 安装目录**：用 `-DpsRoot "D:\DPS"` 显式指定。
- **`profile is managed exclusively by the Electron application`**：这是 `--dump-config` 的限制，不影响本脚本；`dsh plugin` 子命令是允许的。
- **装完顶部没按钮**：确认客户端已完全退出重启（不是刷新页面），且装的是 `desktop` profile 而不是 `web`。跑 `-Action status` 看 bundle 是否已注册。
- **PowerShell 报中文语法错**：`dsh-dps.ps1` 必须是 **UTF-8 with BOM**，PowerShell 5.1 读无 BOM 的 UTF-8 会把中文引号吃掉。改完脚本别用普通编辑器另存为无 BOM。

## 开源到 GitHub

```bash
cd DPS-Directive-Installer
git init
git add .
git commit -m "Initial commit: one-click installer for DPS desktop directive plugin"
git branch -M main
git remote add origin https://github.com/<你的账号>/<仓库名>.git
git push -u origin main
```

注意：

- 不要把 `scripts\backup\` 提交上去（`.gitignore` 已排除）。
- 本仓库的 MIT 只覆盖新增脚本，原版提示词/插件代码的归属看原仓库。
- 首次 push 前检查 `git status`，确认没有把本机绝对路径之类的个人信息写进 README。

## 安全与范围

本脚本只做本地安装：向 dsh profile 写入插件依赖和 bundle、做备份、调用客户端内置 CLI。不修改模型权重，不绕过平台服务的安全策略、系统权限或工具审批。

破甲提示词会改变模型的指令服从和拒答行为，请只在自己有权限的环境使用，并遵守平台条款和适用法规。

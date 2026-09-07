# dsh 一键安装器（dsh-oneclick）

帮没有 Node.js 环境的朋友一键装好 [dsh（DeepSeek Harness）](https://github.com/deepseek-ai/deepseek-harness) 的前置环境，启动 `dsh web`，并在桌面生成带鲸鱼娘图标的启动快捷方式。

> ⚠️ 本项目是**社区便利工具**，不是 DeepSeek 官方出品。脚本只通过 `npx` 从 npm 官方源下载运行 `@deepseek-ai/dsh`，不包含、不修改 dsh 的任何代码。

## 一键安装

### Windows

1. 在本仓库页面点绿色 **Code** 按钮 → **Download ZIP**，解压到任意文件夹。
2. 双击 `install-windows.bat`。
3. 如果 Windows 弹出蓝色 SmartScreen 提示，点 **更多信息** → **仍要运行**。
4. 脚本会自动完成：检查/安装 Node.js → 生成桌面 `dsh` 快捷方式（鲸鱼娘图标）→ 启动 dsh，浏览器自动打开。

### macOS

1. 下载并解压本项目。
2. 打开 **终端**（Terminal），进入解压后的文件夹，执行：
   ```bash
   chmod +x install-macos.command
   ```
3. 双击 `install-macos.command`。
   - 如果提示"来自身份不明的开发者"，右键该文件 → **打开**。
4. 脚本会自动完成：检查/安装 Node.js → 生成桌面 `dsh.app`（鲸鱼娘图标）→ 启动 dsh，浏览器自动打开。

## 以后怎么用

| 系统 | 操作 |
|---|---|
| Windows | 双击桌面 **dsh** 图标 |
| macOS | 双击桌面 **dsh** 图标（会打开一个终端窗口运行 dsh） |

停止 dsh：关掉那个命令行窗口 / 终端窗口即可。

## 脚本做了什么

1. **检查 Node.js**：没有就自动安装（Windows 用 winget，macOS 用 Homebrew；都没有时给出官网下载链接）。
2. **下载鲸鱼娘图标**（可选）：从配置的 GitHub 直链下载 PNG，转成 Windows `.ico` / macOS `.icns`；下载失败会自动跳过，不影响使用。
3. **生成桌面快捷方式**：Windows 创建 `dsh.lnk`，macOS 创建 `dsh.app`。
4. **启动 dsh**：运行 `npx -y @deepseek-ai/dsh web`，浏览器自动打开界面。

> 首次安装 Node.js 可能耗时较长（Windows 用 winget；macOS 用 Homebrew 时还可能自动安装 Xcode Command Line Tools，有时超过 10 分钟且没有明显进度）。请耐心等待，不要中途关掉窗口。

## 第一次使用

1. 双击桌面 **dsh** 图标，浏览器会自动打开 `http://127.0.0.1:3080`。
2. 首次使用需要配置模型和 **DeepSeek API Key**：去 [DeepSeek 开放平台](https://platform.deepseek.com/api_keys) 申请，然后在界面设置里填入。
3. API Key 只保存在你本机，**不要分享给任何人**。

## 常见问题

### 双击脚本没反应 / 一闪而过
- Windows：右键 `install-windows.bat` → **以管理员身份运行** 试试。
- macOS：确认已经执行 `chmod +x install-macos.command`。

### 脚本黑窗口里是英文，正常吗
正常。为了兼容所有 Windows 的编码环境，安装脚本统一使用英文提示；中文说明都在本 README 里。

### 怎么更换鲸鱼娘图标
编辑 `windows\install.ps1`，把 `$IconUrls` 列表里**第一个**地址换成你的图片直链（PNG 格式，保留两边的单引号），保存后重新双击 `install-windows.bat`。后面的几个地址是备用，第一个下载失败会自动试下一个。

### Windows 提示"已保护你的电脑"（SmartScreen）
因为脚本是个人发布、没有代码签名证书，这是正常提示。点 **更多信息** → **仍要运行**。

### 杀毒软件提示"威胁已隔离" / 误报
个人发布的脚本没有代码签名，Windows Defender、360 等可能误报。这是常见现象：在杀毒软件里选择"允许 / 还原"即可；不放心的可以把脚本文件上传到 [VirusTotal](https://www.virustotal.com) 扫描确认。

### macOS 提示"无法打开，因为它来自身份不明的开发者"
右键文件 → **打开** → 再点 **打开**。或在终端执行：
```bash
xattr -d com.apple.quarantine install-macos.command
```

### 想换端口
dsh web 默认端口是 3080。想改的话，编辑启动脚本里的 `npx -y @deepseek-ai/dsh web`，在后面加上 `--port 8080`：
- Windows：编辑 `%LOCALAPPDATA%\dsh-oneclick\start-dsh.bat`
- macOS：编辑 `~/Desktop/dsh.app/Contents/MacOS/dsh-launch`

### 如何更新 dsh
`npx` 每次启动都会使用 npm 上的最新版本，直接双击桌面图标就是最新的。

### 如何卸载
- Windows：删除桌面 `dsh` 快捷方式，删除文件夹 `%LOCALAPPDATA%\dsh-oneclick`。
- macOS：把桌面的 `dsh.app` 拖进废纸篓。
- Node.js 是否卸载由你自己决定（其它软件可能也在用）。

## 项目结构（想学习的话）

| 文件 | 作用 |
|---|---|
| `install-windows.bat` | Windows 入口，双击它。它只负责调用下面的 PowerShell 脚本 |
| `windows/install.ps1` | Windows 真正干活的脚本 |
| `install-macos.command` | macOS 入口，双击它 |
| `README.md` | 本说明文档 |
| `LICENSE` | 本项目的开源许可证（MIT） |
| `CREDITS.md` | 图标与 dsh 的版权致谢 |

## 版权与致谢

- **鲸鱼娘图标**：[fornarwhal/deepseek-whale-girl-icon](https://github.com/fornarwhal/deepseek-whale-girl-icon)，许可证为 [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh)（仅限非商业使用），详见 [CREDITS.md](CREDITS.md)。
- **dsh**：[deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)，MIT License（Copyright (c) 2026 DeepSeek）。
- 鲸鱼娘形象可能基于 DeepSeek 鲸鱼 logo 二创；**DeepSeek 及鲸鱼 logo 的商标权归深度求索所有**，本项目与其无隶属或代言关系。

## 许可证

- 本项目的**脚本与文档**采用 [MIT License](LICENSE)。
- **鲸鱼娘图标**采用 [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh)，仅限非商业性使用，且改编（`.ico` / `.icns` 转换）须以相同许可证共享。
- dsh 本体为 MIT License（Copyright (c) 2026 DeepSeek），本项目不包含其代码。

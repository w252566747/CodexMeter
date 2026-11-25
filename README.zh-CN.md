# CodexMeter

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

CodexMeter 是一个非官方的 macOS 菜单栏用量查看工具。5h/7d 圆环的彩色弧线表示距离对应周期重置还剩多少时间：刚重置后接近满圈，越接近重置弧线越短；圆环内的简写是重置倒计时，旁边的百分比表示剩余用量。点击圆环可查看完整倒计时、可用重置卡数量以及每张卡的到期时间。详情页支持简体中文、日语和英语，所选语言会保存在本机。

CodexMeter 是独立社区项目，与 OpenAI 没有隶属关系。

## 环境要求

- macOS 14 或更高版本
- Swift 6.1 工具链（Xcode Command Line Tools 或 Xcode）
- 已登录 Codex，本机存在 `~/.codex/auth.json`

## 构建运行

```zsh
./build-app.sh
open CodexMeter.app
```

用量每 10 秒刷新，重置卡详情每 5 分钟刷新。应用从本机 Codex 配置读取登录令牌，并直接向下方接口发送只读请求，不会把凭据发送给第三方服务。

## 生成可下载的 ZIP

运行 `./package-app.sh`。脚本会构建并临时签名 `CodexMeter.app`，再生成 `dist/CodexMeter-macos.zip` 和对应的 `dist/CodexMeter-macos.zip.sha256`。ZIP 内是应用本体，不是 `.dmg` 安装器，也未经过公证。生成的 `dist/` 目录不要提交到 Git。

## 分发与首次打开

- 当前仓库有源码，但还没有已发布的 GitHub Release 或可直接安装的下载包。本地打包脚本生成的 ZIP 不等于官方 Release。正式发布前，用户需要安装 Swift 工具链并自行构建。
- Release 构建使用临时签名，没有 Developer ID 签名，也没有经过 Apple 公证。Gatekeeper 可能阻止首次打开。
- 只从本项目的官方 GitHub Releases 页面下载应用和对应的 `.sha256` 文件，不要使用第三方镜像。
- 打开应用前，在终端运行 `shasum -a 256 -c CodexMeter-macos.zip.sha256` 校验下载的 ZIP；只有显示 `OK` 才继续。
- 校验通过后，也只有在确认来源可信并检查过项目的情况下，才前往**系统设置 → 隐私与安全性 → 仍要打开**。先阅读系统警告，再决定是否确认。
- 公司或学校管理的 Mac 可能会彻底禁止未签名或未公证的应用。请遵循组织政策并联系管理员，不要尝试绕过管理限制。
- 本项目目前不使用 Developer ID 签名或 Apple 公证；从源码构建不需要付费开发者会员。
- 仓库尚未选择软件许可证。源码可以公开查看，但当前没有授权他人复制、修改或再分发；添加许可证前，请先征得作者许可。

## 仅在 ChatGPT 运行时启动

附带的 LaunchAgent 监控 ChatGPT 桌面进程：ChatGPT 启动时打开 CodexMeter，ChatGPT 退出后关闭 CodexMeter。监控脚本要求应用位于 `/Applications/CodexMeter.app`：

```zsh
ditto CodexMeter.app /Applications/CodexMeter.app
mkdir -p ~/Library/LaunchAgents
cp com.codexmeter.watcher.plist ~/Library/LaunchAgents/com.codexmeter.watcher.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.codexmeter.watcher.plist
```

关闭监控：

```zsh
launchctl bootout gui/$(id -u)/com.codexmeter.watcher
rm ~/Library/LaunchAgents/com.codexmeter.watcher.plist
```

## 数据与限制

- 用量：`https://chatgpt.com/backend-api/wham/usage`
- 重置卡：`https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`

这些是服务端接口，不是有稳定性保证的公开 API，未来可能变化。应用会读取 `~/.codex/auth.json`；不要提交该文件、访问令牌或账户数据。

CodexMeter 是独立社区项目。OpenAI、ChatGPT 和 Codex 商标归其各自所有者所有。

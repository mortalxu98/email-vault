# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。
发布时 `scripts/release.sh` 会把对应版本的段落用作 GitHub Release 说明。

## [Unreleased]

## [1.1.1] - 2026-11-03

### 新增

- 支持通过 Homebrew 安装：`brew install --cask opsfantasy/tap/email-vault`。

### 变更

- 项目迁移到 `github.com/opsfantasy/email-vault`，「检查更新…」指向新地址；Homebrew tap 改为 `opsfantasy/tap`。

## [1.1.0] - 2026-11-03

### 新增

- 英文界面：跟随系统语言，中文系统显示中文，其他语言显示英文；系统菜单同步本地化。
- 导出 CSV（明文）：需再次输入主密码，文件权限 0600，包含全部密码、安全备注和续费信息，用于迁移到其他工具。
- 服务卡片和列表行支持右键菜单：复制用户名、密码、安全备注，打开网址，编辑，删除。
- 「关于 Email Vault」显示版本号、构建号与项目链接；新增「检查更新…」，在浏览器中打开最新版本页面。
- 全新应用图标：封蜡信封；解锁与设置页面显示应用图标。
- 项目开源（MIT），提供安全策略、贡献指南、Issue / PR 模板、中英文 README，以及持续集成。

### 变更

- 邮箱详情头部改为中性背景，删除操作收进「…」菜单。
- 卡片上的编辑 / 删除按钮仅在悬停时显示。
- 首字母头像改用更深的配色，白字更清晰。

### 修复

- 数据库无法打开时显示错误页，不再在设置主密码时崩溃。
- 删除邮箱或服务失败时会提示，不再静默忽略。
- Notion 图标在深色模式下显示为白块。
- 选中邮箱后再搜索，右侧不显示搜索结果。

## [1.0.0] - 2026-11-02

首个发布版本。

### 新增

- 邮箱与平台账号管理：按服务商分组，内置 70+ 平台目录，自动补全与品牌图标，卡片 / 列表视图，全局搜索。
- 加密：Argon2id 派生主密钥，AES-256-GCM 加密密码与安全备注。
- 安全备注：为邮箱和服务保存助记词、恢复码、2FA 密钥等，加密存储。
- 续费提醒：到期日、周期、金额、提前提醒天数；即将到期横幅，一键顺延。
- 总览首页：统计、续费列表、最近修改。
- 修改主密码：单事务重新加密全部数据，失败整体回滚。
- Touch ID 解锁：Secure Enclave 封装，每 14 天需输入一次主密码。
- 自动锁定：闲置 10 分钟、睡眠、锁屏、屏保、切换用户。
- 剪贴板保护：复制的密码标记为 concealed，30 秒或锁定时清除。
- 数据库只加列迁移，迁移与修改主密码前自动备份；一键导出备份。
- 拖拽安装 DMG 与 GitHub Release 发布流程。

[Unreleased]: https://github.com/opsfantasy/email-vault/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/opsfantasy/email-vault/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/opsfantasy/email-vault/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/opsfantasy/email-vault/releases/tag/v1.0.0

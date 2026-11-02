# 贡献指南

感谢你愿意改进 Email Vault。提交前请先读完这页。

## 先开 Issue

较大的改动（新功能、数据格式、加密相关）请先开 Issue 讨论，避免白费功夫。错别字、小 bug 可以直接提 PR。

安全问题不要开公开 Issue，按 [SECURITY.md](SECURITY.md) 私下报告。

## 开发环境

- macOS 14+，Swift 5.9+；`swift test` 需要完整 Xcode（只编译用 Command Line Tools 即可）。如果 `xcode-select` 指向 Command Line Tools，可临时指定：
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- 改图标需要 `rsvg-convert`（`brew install librsvg`）

```bash
cd email-swift
swift build
swift test
./scripts/build.sh --debug
```

## 红线

- **不要用真实保险箱调试。** 始终通过 `EMAIL_VAULT_DB` 指向临时数据库：
  ```bash
  open -n --env EMAIL_VAULT_DB=/tmp/ev-dev.db "dist/Email Vault.app"
  ```
- 不记录、不持久化任何明文密码或安全备注；不写日志，不写 UserDefaults。
- 数据格式只做向后兼容的**加列**；改动前更新 [docs/data-format.md](docs/data-format.md)，并保证现有测试向量通过。
- 不引入联网行为。

## 代码规范

- Swift：沿用现有风格，4 空格缩进；Core 层保持平台无关（`EmailVaultCore` 需能在 Linux 编译）。
- 分层：`EmailVaultCore` 负责加密、存储和数据格式；界面只通过 `AppModel` 读写数据，视图里不直接访问 `Store` 或密钥。
- Shell：`#!/usr/bin/env bash` + `set -euo pipefail`，变量加引号，能通过 shellcheck；破坏性操作支持 `--dry-run`。
- 代码、注释、提交信息用英文；面向用户的文档可以用中文。
- 界面文字用 `tr("中文原文")` / `trf("含 %@ 或 %ld 的格式", …)`，并在 `email-swift/Localization/en.lproj/Localizable.strings` 添加英文翻译；`scripts/check-l10n.py`（CI 会跑）检查是否遗漏。

## 提交与 PR

- 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)：`feat:`、`fix:`、`docs:`、`chore:`、`refactor:`、`test:`。
- 一个 PR 只做一件事；在 `CHANGELOG.md` 的 `[Unreleased]` 下记录对用户可见的变化。
- CI（`swift build` + `swift test`）必须通过。
- 改了界面请附截图（使用演示数据）。

## 发布（维护者）

1. 把 `CHANGELOG.md` 的 `[Unreleased]` 改成新版本号和日期，更新 `email-swift/VERSION`，提交并推送。
2. `cd email-swift && ./scripts/release.sh --dry-run` 预览，确认后去掉 `--dry-run` 正式发布。

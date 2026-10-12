# email-vault

纯本地的密码库，用来记录哪个邮箱注册了哪些平台，邮箱密码和平台密码都加密保存。
macOS 原生 SwiftUI 应用，代码在 `email-swift/`。

原来的 Python 网页版已删除。Swift 版读写的数据库格式与它完全一致
（表结构和加密测试向量见 `docs/swift-rewrite-prompt.md`）。

## 构建

```bash
cd email-swift
./scripts/build.sh            # 生成 email-swift/dist/Email Vault.app
./scripts/build.sh --dry-run  # 只打印命令，不构建
```

安装：把 `dist/Email Vault.app` 拷到 `/Applications`。构建产物未签名。

| 环境变量 | 默认值 | 说明 |
|---|---|---|
| `EMAIL_VAULT_DB` | `~/.local/share/email-vault/vault.db` | SQLite 数据库文件 |

首次启动需要设置主密码。**主密码丢失后无法找回。**

## 安全模型

- 密钥 = Argon2id(主密码, 随机 salt)，密码用 AES-256-GCM 加密。
  只加密密码字段，邮箱地址、平台名、备注都是明文，方便搜索。不要把机密写进备注。
- 密钥只存在内存中，闲置超时或手动锁定后即清除。

## 备份 / 恢复

数据库文件里的密码始终是密文。备份：

```bash
sqlite3 ~/.local/share/email-vault/vault.db ".backup <目标路径>"
```

恢复：退出应用，替换数据库文件，重新打开。需要使用原来的主密码。

## 致谢

品牌图标来自两个 CC0 图标集：[gilbarbara/logos](https://github.com/gilbarbara/logos)
和 [Simple Icons](https://simpleicons.org)。商标归各自所有者。
详见 `email-swift/Sources/EmailVaultApp/Resources/README.md`。

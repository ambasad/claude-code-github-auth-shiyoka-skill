# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このプロジェクトについて

Claude Code 用のスキル（`/github-auth-shiyoka`）。WSL2 環境での GitHub 認証を Claude がガイドしながら設定する。

Fine-grained PAT（リポジトリ単位の権限制御）を最優先とし、SSH 方式（Deploy Key / 1Password SSH Agent）や GCM にも対応する。

**対象環境：** Windows 11 + WSL2（Ubuntu）/ macOS / Linux、1Password デスクトップアプリ

### 認証方式の優先順位

| 優先順位 | 方式 | 権限スコープ | 条件 |
|---|---|---|---|
| 1（最優先） | Fine-grained PAT + 1Password CLI | リポジトリ単位・操作種別 | `op` インストール済み |
| 2 | Deploy Key | リポジトリ単位（SSH） | 1Password デスクトップアプリ使用可 |
| 3 | SSH + 1Password SSH Agent | アカウント全体 | 1Password デスクトップアプリ使用可・WSL2 対応 |
| 4 | GCM（Git Credential Manager） | アカウント全体 | GCM インストール済み |

## ファイル構成と役割

| ファイル | 役割 |
|---|---|
| `SKILL.md` | Claude Code がスキル実行時に読む指示ファイル。`/github-auth-shiyoka` 起動時の動作をすべてここに記述する |
| `templates/ssh_config_github` | Step 4b で Linux・Windows 両側の SSH config に追記するテンプレート |
| `op.env.example` | HTTPS + PAT 方式の `op.env` テンプレート（コミット用・実値なし） |
| `tests/github-auth-shiyoka.bats` | bats によるシェルスクリプトの動作テスト |
| `README.md` | 公開向けドキュメント（インストール・使い方・解除方法） |

## テストの実行

```bash
# bats のインストール（未インストールの場合）
npm install -g bats

# 全テスト実行
bats tests/github-auth-shiyoka.bats

# 単一テスト実行（テスト名で絞り込み）
bats tests/github-auth-shiyoka.bats --filter "SSH config"
```

## SKILL.md を編集するときの注意

`~/.claude/skills/**` はセキュリティポリシーで Claude Code から直接編集がブロックされる。変更は `/tmp/SKILL_updated.md` に書き出してからユーザーに `cp` してもらう。

```bash
cp /tmp/SKILL_updated.md ~/.claude/skills/github-auth-shiyoka/SKILL.md
```

### このリポジトリのファイルに個人情報を含めない

`SKILL.md`・`CLAUDE.md`・`README.md` 等、リポジトリ内のすべてのファイルに以下を含めてはならない：

- GitHub ユーザー名・組織名
- 1Password のアイテム名・Vault 名
- その他アカウント固有の文字列

サンプルコードや例示はすべて汎用プレースホルダー（`<ユーザー名>`・`[Vault名]` など）に置き換えること。スキル実行中にユーザー固有の値が判明しても、ファイルへの書き込み前に汎用表現に変換する。

## 設計上の重要な決定事項

### `ssh.exe` を使う理由

WSL2 では git が `ssh.exe`（Windows ネイティブ SSH）を使って接続する。WSL native `ssh` は 1Password SSH Agent（Windows 側プロセス）に接続できないため、SSH 疎通確認・config 確認はすべて `ssh.exe` で行う。

### SSH config を Linux・Windows 両側に書く理由

- `ssh.exe` は Windows 側 `%USERPROFILE%\.ssh\config` を読む
- WSL native `ssh` は Linux 側 `~/.ssh/config` を読む

`apply_ssh_config` 関数（SKILL.md の Step 4b）で両方に同じテンプレートを追記する。`IdentityAgent` は記載しない（`ssh.exe` 経由では不要）。

### `ssh -G` で config を確認する理由

`~/.ssh/config` は Claude Code の sandbox ポリシーで直接読み取れない。`ssh -G github.com | grep "^user "` を実行して設定済みかどうかを判定する（`user git` なら設定済み）。

## インストール方法（利用者向け）

```bash
git clone https://github.com/<ユーザー名>/claude-skill-github-auth-shiyoka.git ~/.claude/skills/github-auth-shiyoka
```

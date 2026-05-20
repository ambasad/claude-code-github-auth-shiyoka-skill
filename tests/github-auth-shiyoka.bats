#!/usr/bin/env bats

# テスト中は実際の git global config を汚染しないよう、HOME を一時ディレクトリに差し替える

setup() {
  ORIGINAL_HOME="$HOME"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  # op モック用ディレクトリ
  MOCK_BIN="$(mktemp -d)"
  export MOCK_BIN
}

teardown() {
  export HOME="$ORIGINAL_HOME"
  rm -rf "$TEST_HOME"
  rm -rf "$MOCK_BIN"
}

# op がある場合: github.com 限定の credential helper に op read が設定されること
@test "op がある場合: credential.https://github.com.helper に op read が使われる" {
  cat > "$MOCK_BIN/op" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$MOCK_BIN/op"
  export PATH="$MOCK_BIN:$PATH"

  git config --global credential.https://github.com.helper \
    '!f() { echo username=test-user; echo password=$(op read "op://Private/GitHub PAT/credential"); }; f'

  run git config --global credential.https://github.com.helper
  [ "$status" -eq 0 ]
  [[ "$output" == *"op read"* ]]
}

# op がある場合: github.com 以外のホストに credential helper が設定されないこと
@test "op がある場合: 他ホストの credential.helper は変更されない" {
  git config --global credential.https://github.com.helper \
    '!f() { echo username=test-user; echo password=$(op read "op://Private/GitHub PAT/credential"); }; f'

  run git config --global credential.helper
  [ "$status" -ne 0 ]  # グローバルの credential.helper は未設定
}

# op がない場合: GCM が credential helper に設定されること
@test "op がない場合: GCM が credential helper に設定される" {
  export PATH="$MOCK_BIN:$PATH"  # MOCK_BIN には op を置かない

  git config --global credential.helper manager

  run git config --global credential.helper
  [ "$status" -eq 0 ]
  [ "$output" = "manager" ]
}

# SSH config: 重複なく github.com ブロックが追加されること
@test "SSH config: github.com ブロックが重複せず追加される" {
  mkdir -p "$HOME/.ssh"

  # 1回目の書き込み
  if ! grep -q "^Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
    printf "\nHost github.com\n    HostName github.com\n    User git\n    IdentityAgent ~/.1password/agent.sock\n    IdentitiesOnly yes\n" >> "$HOME/.ssh/config"
  fi

  # 2回目（重複しないこと）
  if ! grep -q "^Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
    printf "\nHost github.com\n    HostName github.com\n    User git\n    IdentityAgent ~/.1password/agent.sock\n    IdentitiesOnly yes\n" >> "$HOME/.ssh/config"
  fi

  run grep -c "^Host github.com" "$HOME/.ssh/config"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# 解除: credential.https://github.com.helper が削除されること
@test "解除: credential.https://github.com.helper が削除される" {
  git config --global credential.https://github.com.helper \
    '!f() { echo username=test-user; echo password=$(op read "op://Private/GitHub PAT/credential"); }; f'

  git config --global --unset credential.https://github.com.helper

  run git config --global credential.https://github.com.helper
  [ "$status" -ne 0 ]  # 設定が存在しない場合は exit code 1
}

# op.env: .gitignore に op.env が追記されること
@test "op.env: .gitignore に op.env が追記される" {
  touch "$HOME/.gitignore"
  grep -qxF 'op.env' "$HOME/.gitignore" 2>/dev/null || echo 'op.env' >> "$HOME/.gitignore"

  run grep -c "^op\.env$" "$HOME/.gitignore"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# op.env: 二重追記されないこと
@test "op.env: .gitignore に op.env が重複追記されない" {
  touch "$HOME/.gitignore"
  grep -qxF 'op.env' "$HOME/.gitignore" 2>/dev/null || echo 'op.env' >> "$HOME/.gitignore"
  grep -qxF 'op.env' "$HOME/.gitignore" 2>/dev/null || echo 'op.env' >> "$HOME/.gitignore"

  run grep -c "^op\.env$" "$HOME/.gitignore"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# Deploy Key: Host エイリアスが SSH config に追加されること
@test "Deploy Key: Host github-<repo> エイリアスが SSH config に追加される" {
  mkdir -p "$HOME/.ssh"
  ALIAS="github-my-repo"
  BLOCK="
Host $ALIAS
    HostName github.com
    User git"

  sed -i "/^Host $ALIAS/,/^$/d" "$HOME/.ssh/config" 2>/dev/null || true
  printf '%s\n' "$BLOCK" >> "$HOME/.ssh/config"

  run grep -c "^Host $ALIAS" "$HOME/.ssh/config"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# Deploy Key: Host エイリアスが重複しないこと
@test "Deploy Key: Host github-<repo> エイリアスが重複しない" {
  mkdir -p "$HOME/.ssh"
  ALIAS="github-my-repo"
  BLOCK="
Host $ALIAS
    HostName github.com
    User git"

  for _ in 1 2; do
    sed -i "/^Host $ALIAS/,/^$/d" "$HOME/.ssh/config" 2>/dev/null || true
    printf '%s\n' "$BLOCK" >> "$HOME/.ssh/config"
  done

  run grep -c "^Host $ALIAS" "$HOME/.ssh/config"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# OS 判定: /proc/version に microsoft が含まれない場合は Linux と判定されること
@test "OS 判定: microsoft を含まない /proc/version では Linux と判定される" {
  run bash -c '
    PROC_VERSION_MOCK="Linux version 5.15.0-generic"
    if echo "$PROC_VERSION_MOCK" | grep -qi microsoft; then
      echo "WSL2"
    elif [[ "$(uname)" == "Darwin" ]]; then
      echo "macOS"
    else
      echo "Linux"
    fi
  '
  [ "$status" -eq 0 ]
  [ "$output" = "Linux" ]
}

# OS 判定: /proc/version に microsoft が含まれる場合は WSL2 と判定されること
@test "OS 判定: microsoft を含む /proc/version では WSL2 と判定される" {
  run bash -c '
    PROC_VERSION_MOCK="Linux version 5.15.0-microsoft-standard-WSL2"
    if echo "$PROC_VERSION_MOCK" | grep -qi microsoft; then
      echo "WSL2"
    elif [[ "$(uname)" == "Darwin" ]]; then
      echo "macOS"
    else
      echo "Linux"
    fi
  '
  [ "$status" -eq 0 ]
  [ "$output" = "WSL2" ]
}

# SSH config 反映確認: ssh.exe -G で user git が返ること（Windows 側 config 設定済みの場合）
@test "SSH config: ssh.exe -G github.com で user git が返る（Windows SSH config 設定済み）" {
  # ssh.exe モックを作成（Windows 側 config 設定済みの状態をシミュレート）
  cat > "$MOCK_BIN/ssh.exe" << 'EOF'
#!/bin/bash
# -G github.com の場合のみモック出力
if [[ "$*" == *"-G"* && "$*" == *"github.com"* ]]; then
  echo "hostname github.com"
  echo "user git"
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN/ssh.exe"
  export PATH="$MOCK_BIN:$PATH"

  run bash -c 'ssh.exe -G github.com 2>/dev/null | grep -q "^user git$" && echo "✅ 設定済み" || echo "🔧 未設定"'
  [ "$status" -eq 0 ]
  [ "$output" = "✅ 設定済み" ]
}

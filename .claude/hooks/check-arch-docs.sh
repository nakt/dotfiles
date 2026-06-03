#!/bin/bash

# docs/arch ディレクトリが存在しない場合はスキップ
if [ ! -d "docs/arch" ]; then
  exit 0
fi

# ステージングされたファイルにコード系があるかチェック
CODE_EXTENSIONS="ts|tsx|js|jsx|py|go|rs|java|rb|php|swift|kt"
STAGED_CODE=$(git diff --cached --name-only 2>/dev/null | grep -E "\.($CODE_EXTENSIONS)$")

if [ -z "$STAGED_CODE" ]; then
  exit 0
fi

# ブロックはせず、Claude に「アーキテクチャドキュメント更新の要否判断」を促す。
# PreToolUse の hookSpecificOutput.additionalContext を stdout に出して exit 0 すると、
# コミットは通したまま additionalContext が Claude のコンテキストに注入される。
# （exit 2 + stderr はブロック、exit 1 は破棄。ここではどちらも使わない）
FILE_LIST=$(echo "$STAGED_CODE" | sed 's/^/  - /')
STAT=$(git diff --cached --stat)

REMINDER=$(cat << EOF
docs/arch が存在するプロジェクトでコード変更を検出しました。
このコミットはブロックしません。コミット後にアーキテクチャドキュメントの更新要否を判断してください。

変更対象のコードファイル:
${FILE_LIST}

変更の概要:
${STAT}

判断基準:
- 更新必要: 新規機能追加、処理フロー変更、API変更、依存関係変更
- 更新不要: バグ修正(フロー変更なし)、リファクタ(振る舞い同一)、テスト追加

更新が必要なら docs/arch/ の関連ドキュメントを更新し、別途コミットしてください。
（更新が必要かは /update-arch スキルでも判断・反映できます）
EOF
)

jq -n --arg reason "$REMINDER" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $reason
  }
}'

exit 0

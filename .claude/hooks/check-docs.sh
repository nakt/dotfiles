#!/bin/bash

# git push 前に、未 push のコード変更を見て docs/arch / docs/adr の更新・起票を促す。
# どちらのディレクトリも無ければ何もしない。

if [ ! -d "docs/arch" ] && [ ! -d "docs/adr" ]; then
  exit 0
fi

# 未 push コミットの範囲を決める。
# 1) upstream があれば @{u}..HEAD
# 2) なければ origin/HEAD からの分岐点..HEAD（新規ブランチの初回 push 想定）
# 3) いずれも取れなければスキップ
RANGE=""
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  RANGE='@{u}..HEAD'
elif ORIGIN_HEAD=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null); then
  if BASE=$(git merge-base "$ORIGIN_HEAD" HEAD 2>/dev/null); then
    RANGE="$BASE..HEAD"
  fi
fi

if [ -z "$RANGE" ]; then
  exit 0
fi

# 範囲内のコード系ファイルの変更を抽出
CODE_EXTENSIONS="ts|tsx|js|jsx|py|go|rs|java|rb|php|swift|kt"
CHANGED_CODE=$(git diff "$RANGE" --name-only 2>/dev/null | grep -E "\.($CODE_EXTENSIONS)$")

if [ -z "$CHANGED_CODE" ]; then
  exit 0
fi

FILE_LIST=$(echo "$CHANGED_CODE" | sed 's/^/  - /')
STAT=$(git diff "$RANGE" --stat 2>/dev/null)

# 該当するドキュメント種別ごとに reminder パートを組み立て、1 つの additionalContext に合成。
# push はブロックせず（exit 0 + additionalContext の non-blocking 注入）、判断と即アクションを促す。
# exit 2 + stderr はブロック、exit 1 は破棄。ここではどちらも使わない。
PARTS=""

if [ -d "docs/arch" ]; then
  PARTS="${PARTS}
- docs/arch: この一連の変更に処理フロー・データフロー・構成の変化が含まれるなら、push 前に docs/arch を更新する（/update-arch でも可）。バグ修正・リファクタ・テストのみなら不要。"
fi

if [ -d "docs/adr" ]; then
  PARTS="${PARTS}
- docs/adr: この変更に新しい設計・ロジック判断（技術選定 / 処理フロー / アルゴリズム / データモデル / API 等）が含まれるなら、push 前に /record-adr で起票する。バグ修正・リファクタ・テストのみなら不要。"
fi

REMINDER=$(cat << EOF
push 予定のコミットにコード変更を検出しました。push はブロックしません。
進める前に、未反映・未起票のドキュメントがないか判断してください。
${PARTS}

変更対象のコードファイル:
${FILE_LIST}

変更の概要:
${STAT}
EOF
)

jq -n --arg reason "$REMINDER" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $reason
  }
}'

exit 0

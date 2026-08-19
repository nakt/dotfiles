#!/bin/bash

# gh pr create 前に、コード変更を見て docs/arch / docs/adr の更新・起票を促す。
# 発火は gh pr create 時の 1 回のみ。PR 作成後の追加 push は捕捉しない（1 PR = 1 回の促しに抑えるための意図的な設計）。
# どちらのディレクトリも無ければ何もしない。

if [ ! -d "docs/arch" ] && [ ! -d "docs/adr" ]; then
  exit 0
fi

# PR に含まれる変更の範囲を決める。
# 1) origin/HEAD からの分岐点（マージベース）..HEAD
# 2) origin/HEAD またはマージベースが取得できなければスキップ
RANGE=""
if ORIGIN_HEAD=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null); then
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
# PR 作成はブロックせず（exit 0 + additionalContext の non-blocking 注入）、判断と即アクションを促す。
# exit 2 + stderr はブロック、exit 1 は破棄。ここではどちらも使わない。
PARTS=""

if [ -d "docs/arch" ]; then
  PARTS="${PARTS}
- docs/arch: この一連の変更に処理フロー・データフロー・構成の変化が含まれるなら、PR 作成前に docs/arch を更新する（/update-arch でも可）。バグ修正・リファクタ・テストのみなら不要。"
fi

if [ -d "docs/adr" ]; then
  PARTS="${PARTS}
- docs/adr: この変更に新しい設計・ロジック判断（技術選定 / 処理フロー / アルゴリズム / データモデル / API 等）が含まれるなら、PR 作成前に /record-adr で起票する。既存の方針を代替なしで廃止する場合は Deprecated 化も /record-adr で行う。バグ修正・リファクタ・テストのみなら不要。"
fi

REMINDER=$(cat << EOF
PR 作成予定のコミットにコード変更を検出しました。PR 作成はブロックしません。
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

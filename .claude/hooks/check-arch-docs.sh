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

# block して Claude に自動判断を促す
cat << 'EOF'
BLOCK: docs/arch が存在するプロジェクトでコード変更を検出しました。

【自動判断を実行してください】
以下の手順でアーキテクチャドキュメントの更新要否を判断し、必要なら更新してからコミットしてください：

1. git diff --cached でコード変更内容を確認
2. docs/arch/ 内の関連ドキュメントを確認
3. 処理フローに影響があるか判断
4. 必要ならドキュメントを更新してステージング
5. 更新不要と判断した場合はその理由を説明してコミット続行

判断基準：
- 更新必要: 新規機能追加、処理フロー変更、API変更、依存関係変更
- 更新不要: バグ修正(フロー変更なし)、リファクタ(振る舞い同一)、テスト追加
EOF

echo ""
echo "変更対象のコードファイル:"
echo "$STAGED_CODE" | sed 's/^/  - /'

exit 1

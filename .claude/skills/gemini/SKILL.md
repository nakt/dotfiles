# Gemini CLI

Gemini CLI を活用して外部の視点を取り入れる補助スキル。意見取得（Opinion）とウェブリサーチ（Research）の2モードを提供する。

## When to use

- プラン、コード、設計、アイデアに対するフィードバックが欲しいとき
- ウェブ検索を活用して最新情報や技術調査を行いたいとき

## Instructions

### 役割

- Gemini CLI を活用して外部の視点を取り入れる補助スキル
- Claude Code 単体では得られない別モデルの知見やウェブ上の最新情報を補完する

### モード判定

ユーザーのリクエスト内容に応じて、以下を目安に判断する。

- Opinion: プラン、コード、設計、アイデアへのフィードバックを求める場合
- Research: ウェブ検索を活用した調査・情報収集を行う場合

### Opinion モード

外部モデルの視点からフィードバックを取得する。

手順:

1. レビュー対象（プラン、コード、設計など）を整理する
2. `gemini` コマンドにレビュー対象を渡してフィードバックを取得する
3. フィードバックの各項目を個別に評価する
4. プロジェクトのコンテキストに照らして妥当な提案のみ採用する

### Research モード

Gemini のウェブ検索機能を活用して調査を行う。

手順:

1. 調査したい内容を明確にする
2. `gemini` コマンドにリサーチ依頼を渡す
3. 返却された情報の正確性を検証する
4. 調査結果をタスクに反映する

## コマンドの使い方

### Opinion モードの例

```bash
gemini -p "Review this implementation plan. Point out any flaws or suggest improvements.
<レビュー対象をここに記載>"
```

### Research モードの例

```bash
gemini -p "Search the web and summarize the latest information about <調査対象>.
Include relevant URLs for reference."
```

## 結果の扱い方

- 各提案・情報を個別に評価する
- プロジェクトのコンテキストや既存の設計判断と照合する
- 全てを無条件に採用する必要はない
- 採用しない場合はその理由を明確にする
- Research モードの結果は、可能な限り別ソースで裏付けを取る

## Key Principles

1. Gemini の出力は参考意見であり、最終判断は Claude Code が行う
2. プロジェクト固有のコンテキストを常に優先する
3. フィードバックは個別に評価し、妥当性を判断する
4. Research 結果は正確性を検証してから活用する

---
name: gemini
description: >-
  Gemini CLI を活用して外部モデルの視点を取り入れる補助スキル。
  意見取得（Opinion）とウェブリサーチ（Research）の2モードを提供する。
  ユーザーがプラン・コード・設計・アイデアへのフィードバックを求めたとき、
  またはウェブ検索で最新情報や技術調査を行いたいときに使用する。
allowed-tools: Bash(gemini *)
---

## モード判定

リクエスト内容に応じて判断する。

- **Opinion**: プラン、コード、設計、アイデアへのフィードバックを求める場合
- **Research**: ウェブ検索を活用した調査・情報収集を行う場合

## Opinion モード

外部モデルの視点からフィードバックを取得する。

1. レビュー対象（プラン、コード、設計など）を整理する
2. `gemini` コマンドにレビュー対象を渡してフィードバックを取得する
3. フィードバックの各項目を個別に評価する
4. プロジェクトのコンテキストに照らして妥当な提案のみ採用する

```bash
gemini -p "Review this implementation plan. Point out any flaws or suggest improvements.
<レビュー対象をここに記載>"
```

## Research モード

Gemini のウェブ検索機能を活用して調査を行う。

1. 調査したい内容を明確にする
2. `gemini` コマンドにリサーチ依頼を渡す
3. 返却された情報の正確性を検証する
4. 調査結果をタスクに反映する

```bash
gemini -p "Search the web and summarize the latest information about <調査対象>.
Include relevant URLs for reference."
```

## 結果の扱い方

- Gemini の出力は参考意見であり、最終判断は Claude Code が行う
- プロジェクト固有のコンテキストを常に優先する
- 各提案・情報を個別に評価し、全てを無条件に採用しない
- Research 結果は、可能な限り別ソースで裏付けを取る

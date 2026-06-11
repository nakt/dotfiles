# GPT-5.3 Codex プロンプティングガイド（最小限）

agentic coding 特化モデル。本ファイルは Codex 固有のポインタに留め、共通原則は [common.md](common.md)、コーディング・Frontend Tasks・Verification 等の標準パターンは [gpt-5-4.md](gpt-5-4.md) を参照する。

公式: <https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide>

## 目次

- [GPT-5.3 Codex プロンプティングガイド（最小限）](#gpt-53-codex-プロンプティングガイド最小限)
  - [目次](#目次)
  - [1. 改善点の概要（vs 旧 Codex）](#1-改善点の概要vs-旧-codex)
  - [2. スタータープロンプトの構成ブロック](#2-スタータープロンプトの構成ブロック)
  - [3. 推奨ツール](#3-推奨ツール)
  - [4. Plan ツール（update\_plan）の開閉ルール](#4-plan-ツールupdate_planの開閉ルール)
  - [5. Editing Constraints 要点](#5-editing-constraints-要点)
  - [6. Phase Parameter (Codex 固有)](#6-phase-parameter-codex-固有)
  - [7. Mid-Rollout Updates の取り扱い](#7-mid-rollout-updates-の取り扱い)
  - [8. Frontend "AI slop" 回避](#8-frontend-ai-slop-回避)
  - [9. Compaction サポート](#9-compaction-サポート)

---

## 1. 改善点の概要（vs 旧 Codex）

- 高速化・トークン効率改善
- 困難なコード作業での長時間自律性向上
- マルチアワー推論向け Compaction の標準サポート
- ロールアウト中断を避けるため、事前計画と前置きを最小化する設計

## 2. スタータープロンプトの構成ブロック

公式スタータープロンプトは以下のブロック構成:

| ブロック | 主な内容 |
|---|---|
| General | `rg` 推奨（grep より高速）、ツール優先（シェル回避）、並列化推奨、ツール出力内のメタデータ注釈対応 |
| Autonomy & Persistence | シニアエンジニア相当の自律性、ターン内で完全処理、bias to action |
| Code Implementation | 正確性優先、コードベース慣例準拠、包括性、安全なデフォルト、エラー処理の厳密化 |
| Editing Constraints | ASCII 優先、簡潔コメント、`apply_patch` 推奨、git dirty 状態対応、破壊的コマンド回避 |
| Exploration | 事前計画、関連ファイル一括読込、`multi_tool_use.parallel` 活用、順次呼び出し最小化 |

詳細な Autonomy & Persistence / User Updates / Terminal Tool Hygiene の XML パターンは gpt-5-4.md「Coding Tasks」を参照。

## 3. 推奨ツール

| ツール | 用途 | 備考 |
|---|---|---|
| `apply_patch` | ファイル編集 | Responses API 内蔵実装推奨。CFG 形式の代替も可 |
| `shell` | 端末コマンド | Codex 用最適化版を推奨 |
| `update_plan` | TODO / 計画管理 | 後述の開閉ルールに従う |
| `multi_tool_use.parallel` | 独立ツール呼び出しの並列化 | 順次呼び出しを最小化 |

セマンティック検索・MCP・カスタムツールはモデルに合わせたチューニングが必要。

## 4. Plan ツール（update_plan）の開閉ルール

開く判断:

- 簡単なタスク（おおよそ上位 25%）はスキップ
- 単一ステップで完結する計画は作成しない

閉じる判断:

- 完了後に TODO を必ず更新
- 計画作成のみで終了しない（実装コード必須）
- 終了時に全アイテムを Done / Blocked / Cancelled いずれかに確定
- in_progress 状態のままでターンを終えない

## 5. Editing Constraints 要点

- ASCII 優先（非 ASCII 採用には正当化が必要）
- 自動説明的コメントを避け、複雑ブロックのみコメント
- 単一ファイル編集は `apply_patch` を優先
- git dirty 状態ではユーザー変更を保持（破壊的操作禁止）
- `git reset --hard` など破壊的シェル操作はユーザー承認なしに実行しない

## 6. Phase Parameter (Codex 固有)

Responses API の `phase` パラメータは Codex Prompting Guide で「currently only supported with gpt-5.3-codex」と明記され、正しい実装が gpt-5.3-codex のパフォーマンスに必須とされる。

| 値 | 用途 |
|---|---|
| `null` | デフォルト (未指定) |
| `"commentary"` | 中間のユーザー可視更新 (preamble、進捗) |
| `"final_answer"` | 完成した最終回答 |

ユースケース・assistant アイテム再生時の保持ルール等の詳細は [gpt-5-4.md](gpt-5-4.md)「Phase Parameter」と共通。

## 7. Mid-Rollout Updates の取り扱い

GPT-5.3 Codex 以降、ロールアウト中の更新メッセージはシステム生成からプロンプト可能に移行。他の GPT-5 系モデルと同様のプロンプト方式（[gpt-5-4.md](gpt-5-4.md)「User Updates Spec」）が適用できる。

## 8. Frontend "AI slop" 回避

Codex でも frontend タスクを扱う場合、"AI slop" 回避ルール（typography / color / motion / background の各原則）が適用される。Codex 固有の差分は少なく、ルール本体は [gpt-5-4.md](gpt-5-4.md)「Frontend Tasks」（`<frontend_tasks>` ブロック原文）を参照。

簡易ポイント:

- 表現力豊かで意図的なフォント、デフォルト実装の回避
- 明確な視覚方向、CSS 変数で色管理、紫-白のデフォルト配色を避ける
- 数個の有意義なアニメーション、汎用マイクロモーションは避ける
- 単色フラット背景を避け、グラデーション・図形・微細パターンを活用
- 既存デザインシステム内では既成パターンを保持

## 9. Compaction サポート

- エンドポイント: `/responses/compact`
- ZDR 互換、`encrypted_content` を返却
- 長時間タスク・多ターン会話でコンテキスト枠を実質拡張
- 詳細・ベストプラクティスは [gpt-5-4.md](gpt-5-4.md)「Compaction for Long Sessions」を参照

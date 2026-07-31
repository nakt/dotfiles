---
name: fable5-prompting
description: Claude Fable 5 / Mythos 5 向けプロンプト設計の支援スキル。references/ 内のガイド（common.md / fable-5.md / parameters.md）をリファレンスとして参照し、レビュー・ドラフティング・アドバイスを行う。Claude Fable 5 / Mythos 5 向けプロンプトの新規作成、既存プロンプト（他モデル・GPT 系含む）からの移行・最適化、effort/adaptive thinking/max_tokens 等のパラメータ設定検討、長時間 autonomous run のスキャフォールディング設計、サブエージェント委譲・メモリシステム・send-to-user ツールの設計、refusal/fallback 対応、reasoning_extraction を避けるプロンプト監査、プロンプトが期待通りに動かない場合の原因特定に使用する。
allowed-tools: Read
---

# Claude Fable 5 / Mythos 5 プロンプティングガイド

主張の根拠は `ファイル名「章タイトル」` の形で必ず添える（例: `fable-5.md「進捗報告を根拠づける」`）。references/ を読まずに答えない。

対象は Claude Fable 5（`claude-fable-5`）と Claude Mythos 5（`claude-mythos-5`）。両者はプロンプティング・パラメータ推奨が同一なので、特記しない限りまとめて扱う。

## モード判定

既存プロンプトの提示なら Review、新規作成の依頼なら Draft、パラメータ・手法の質問なら Advise。境界ケースや複合リクエストは組み合わせて対応する。

## リファレンスの読み分け

`common.md` は常に併読する。値の実体は references 側にあるので、下表で当たりをつけて該当章を Read してから答える。判断がつかなければ3ファイルすべてを Read する。

| リクエストの焦点 / シグナル | 読む章 |
|---|---|
| 長時間 autonomous run / 早期停止 / checkpoint / 境界設定 | fable-5.md「まれな早期停止」「境界を明示する」「強い指示遵守」 |
| 進捗報告 / 可読性 / send-to-user | fable-5.md「進捗報告を根拠づける」「ユーザーとのコミュニケーションの可読性」「send-to-user ツールを作る」 |
| サブエージェント / メモリ / 自己検証 | fable-5.md「並列サブエージェント」「メモリシステムを構築する」「推奨スキャフォールディング変更」、common.md「サブエージェント orchestration」 |
| Opus 4.8 や GPT 系からの移行 / スキルのリファクタ / prescriptive すぎる指示 | fable-5.md「推奨スキャフォールディング変更」「ターンが長くなる」 |
| effort のレベル一覧と運用方針 / max_tokens / コスト | parameters.md「effort パラメータ」「コスト制御」 |
| adaptive thinking / thinking.display / omitted / summarized / thinking ブロックの往復 | parameters.md「adaptive thinking」 |
| `stop_reason: refusal` / cyber / bio / frontier_llm / reasoning_extraction / fallback | parameters.md「Refusal と Fallback」 |
| clear-and-direct / 例 / XML タグ / ロール / 長 context / prefill 移行 / hallucination | common.md「一般原則」「出力とフォーマット」 |
| overthinking / 過剰エンジニアリング / 積極性の上げ下げ | common.md「overthinking の抑制」「過剰エンジニアリング（Overeagerness）」、fable-5.md「effort レベルを使い分ける」 |

Fable 5 固有の最重要ポイント（判断に迷ったら優先的に確認）:

1. Fable 5 は指示遵守が強く、挙動を1つずつ列挙するより短い指示1本で steer する方が良い。従来モデル向けの prescriptive なプロンプトは過度で、品質を下げうる（`fable-5.md「推奨スキャフォールディング変更」`）
2. thinking は常時オンの adaptive のみ。`budget_tokens` は 400 エラー。内部推論を応答テキストで再現させる指示は `reasoning_extraction` refusal を誘発する（`parameters.md「adaptive thinking」`）
3. effort が主要コントロールで既定は `high`（`parameters.md「effort パラメータ」`）

## Review

冒頭に対象モデル（Fable 5 / Mythos 5）を置き、他モデル向けからの移行ならその移行元も書く。次に Review Checklist を上から通し、各項目を OK / 要改善 / 該当なし に振り分ける。要改善には修正案と、根拠にした章を添える。最後に改善後のプロンプト全文を出す。

## Draft

対象モデルと設計方針を先に述べ、references のどの原則に沿って何を決めたかを説明してからプロンプト全文を書く。末尾に推奨パラメータ（effort、max_tokens、thinking.display、必要なら fallback 構成）を添える。

## Advise

パラメータや手法についての質問に、該当ファイル名と章タイトルを引用しながら回答する。

## Review Checklist

| チェック項目 | 参照 | 確認内容 |
|---|---|---|
| 過度な prescriptive さ | fable-5.md「推奨スキャフォールディング変更」 | 挙動を1つずつ列挙して steer していないか。短い指示に集約できないか |
| reasoning_extraction 誘発 | fable-5.md「推奨スキャフォールディング変更」 / parameters.md「Refusal と Fallback」 | 内部推論を応答テキストで echo / transcribe / explain させる指示がないか |
| outcome-first / 簡潔さ | fable-5.md「強い指示遵守」 | 結論を先頭に置く指示があるか。冗長化を抑えているか |
| 進捗報告の根拠づけ | fable-5.md「進捗報告を根拠づける」 | 長時間 run で claim をツール結果に照らして監査させているか |
| 境界の明示 | fable-5.md「境界を明示する」 | 要求外の行動を禁じ、system 状態変更コマンドの前に根拠確認をさせているか |
| checkpoint / 早期停止 | fable-5.md「強い指示遵守」 / 「まれな早期停止」 | 本当に必要なときだけ止める指示か。ターン終了前に未実行の約束を検査させているか |
| effort 設定 | parameters.md「effort パラメータ」 | タスク複雑度に見合うか。既定 high から始め、routine は下げているか |
| max_tokens | parameters.md「effort パラメータ」 / 「コスト制御」 | high/xhigh で thinking + response の総出力に足る大きさを確保しているか |
| thinking 制御 | parameters.md「adaptive thinking」 | budget_tokens を使っていないか。display の要否を意識しているか |
| overthinking 抑制 | common.md「overthinking の抑制」 / fable-5.md「effort レベルを使い分ける」 | 高 effort での要求外の整理・リファクタ・探索を抑えているか |
| サブエージェント委譲 | fable-5.md「並列サブエージェント」 / common.md「サブエージェント orchestration」 | 委譲の適否と非同期通信を指示しているか。過剰 spawn を抑えているか |
| メモリシステム | fable-5.md「メモリシステムを構築する」 | 教訓の記録・参照先を与えているか |
| 理由の提供 | fable-5.md「依頼だけでなく理由を伝える」 | why / 誰のため / 何を可能にするかを伝えているか |
| 可読性 | fable-5.md「ユーザーとのコミュニケーションの可読性」 | 長い agentic 会話で最終サマリーを re-grounding として書かせているか |
| send-to-user | fable-5.md「send-to-user ツールを作る」 | verbatim content が要る UX でツール定義 + elicitation 指示があるか |
| 自己検証 | fable-5.md「推奨スキャフォールディング変更」 / common.md「thinking / interleaved thinking の活用」 | fresh-context の別 verifier サブエージェントで検証させているか |
| fallback 構成 | parameters.md「Refusal と Fallback」 | cyber/bio 等に触れうるなら Opus 4.8 への fallback を各 request path に設定しているか |
| 明確さ / 具体性 | common.md「明確かつ直接的に」 | 望む出力・制約が具体的か。過剰な語調で overtrigger させていないか |
| ツール使用の明示 | common.md「ツール使用の明示」 | 行動させたいのに「提案して」になっていないか。CRITICAL 等の過剰語調がないか |
| 過剰エンジニアリング | common.md「過剰エンジニアリング」 / fable-5.md「effort レベルを使い分ける」 | 要求外のファイル・抽象・防御コードを抑えているか |

## References

- 共通原則: [references/common.md](references/common.md)
- Fable 5 / Mythos 5 固有: [references/fable-5.md](references/fable-5.md)
- API パラメータ（effort / adaptive thinking / refusal・fallback）: [references/parameters.md](references/parameters.md)
- 公式: [Prompting Claude Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)
- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [Effort](https://platform.claude.com/docs/en/build-with-claude/effort)
- [Adaptive thinking](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking)
- [Refusals and fallback](https://platform.claude.com/docs/en/build-with-claude/refusals-and-fallback)

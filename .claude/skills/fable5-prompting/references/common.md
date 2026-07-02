# Claude 共通プロンプティング原則

Fable 5 / Mythos 5 を含む現行 Claude モデル全般に適用される技法。Fable 5 固有の挙動は `fable-5.md`、API パラメータは `parameters.md` を参照。

出典: [Prompting best practices | Anthropic](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)

## 一般原則

### 明確かつ直接的に（Be clear and direct）

明示的で具体的な指示に良く応答する。「期待以上」の振る舞いが欲しいなら曖昧なプロンプトから推測させず明示的に要求する。Claude を「有能だが自社の慣習を知らない新入社員」と捉える。ゴールデンルール: タスクの前提を持たない同僚にプロンプトを渡して従ってもらう。混乱するなら Claude も混乱する。

- 望む出力フォーマットと制約を具体的に
- 順序や網羅性が重要なら番号付き / 箇条書きの逐次ステップで

### 動機を添える（Add context）

指示の背後にある context や理由を与えると、ゴールをよく理解し的を射た応答になる。例: 「省略記号を使うな」より「応答は TTS エンジンで読み上げられるため、発音できない省略記号を使わない」。Claude は説明から一般化できるほど賢い。

### 例を効果的に使う（Use examples / multishot）

例は出力フォーマット・トーン・構造を steer する最も信頼できる手段。few-shot の例は:

- Relevant: 実際のユースケースを忠実に反映
- Diverse: edge case を網羅し、意図しないパターンを拾わない程度に変化を持たせる
- Structured: `<example>`（複数なら `<examples>`）タグで指示と区別

3〜5 例が目安。例の relevance / diversity を Claude 自身に評価・追加生成させることもできる。

### XML タグで構造化（Structure with XML tags）

指示・context・例・可変入力が混在するプロンプトでは、種類ごとに `<instructions>` / `<context>` / `<input>` 等のタグで囲むと誤解釈が減る。一貫した descriptive なタグ名を使い、自然な階層があれば nest する。

### ロールを与える（Give Claude a role）

system prompt でのロール設定は挙動とトーンをユースケースに集中させる。一文でも効果がある（例: "You are a helpful coding assistant specializing in Python."）。

### 長 context プロンプティング（Long context）

20k トークン超の大きな文書・データでは:

- 長い文書・入力はプロンプト上部（クエリ・指示・例より前）に置く。全モデルで性能向上。末尾のクエリは複雑・複数文書入力で最大30%品質を上げうる
- 複数文書は `<document>` タグに `<document_content>` / `<source>` 等のサブタグで metadata と共に囲む
- 長文書タスクでは、本題の前に関連箇所を引用させると文書のノイズを切り抜けられる

## 出力とフォーマット

### コミュニケーションスタイルと冗長性

現行モデルは従来より簡潔で自然な文体。事実ベースの進捗報告、やや口語的、効率のためサマリーを省くことがある。ツール呼び出し後のサマリーを飛ばして次の行動に移ることもある。可視性が欲しいなら明示する: "After completing a task that involves tool use, provide a quick summary of the work you've done."

### 出力フォーマットの制御

- してほしいことを言う（否定形を避ける）: 「markdown を使うな」より「smoothly flowing prose paragraphs で構成せよ」
- XML フォーマット指示子: "Write the prose sections in `<smoothly_flowing_prose_paragraphs>` tags."
- プロンプトの文体を望む出力に合わせる: プロンプトから markdown を除くと出力の markdown も減る
- 詳細な指示: markdown / 箇条書きを抑えたいなら `<avoid_excessive_markdown_and_bullet_points>` のような明示ブロックで prose 志向を指定

### LaTeX 出力

数式は既定で LaTeX。plain text が良ければ、LaTeX / MathJax / マークアップを使わず標準文字（`/`・`*`・`^`）で書くよう明示する。

### prefill からの移行

Claude 4.6 系以降、last assistant ターンでの prefill（部分 assistant メッセージの継続）は非対応（400 エラー）。フォーマット強制は Structured Outputs、preamble 除去は "Respond directly without preamble." のような直接指示や XML タグ、continuation は user メッセージへ移して直前テキストを添える、で代替する。

## ツール使用

### ツール使用の明示

精密な指示遵守のため、特定ツールの使用は明示的な指示が効く。「変更を提案して」だと実装せず提案だけのことがある。行動させたいなら「この関数を変更して性能を上げて」のように明示する。

積極的に行動させたいなら `<default_to_action>`、慎重にさせたいなら `<do_not_act_before_instructions>` を system prompt に置く。なお現行モデルは system prompt への反応が強く、"CRITICAL: You MUST..." のような過剰な語調は overtrigger を招く。"Use this tool when..." 程度に緩める。

### 並列ツール呼び出しの最適化

現行モデルは独立なツール呼び出しを並列実行する。`<use_parallel_tool_calls>` ブロックで最大効率化でき、依存がある場合は逐次にする旨も添える。過剰な並列実行を抑えたいなら "Execute operations sequentially..." と指示する。

## thinking と推論

### overthinking の抑制

高 effort ほど upfront exploration が増え、要求外に context 収集・複数スレッド追跡をしうる。従来モデル向けに thoroughness を促していたなら調整する: blanket default を targeted 指示に置換、over-prompting（"If in doubt, use [tool]"）を除去、それでも過剰なら effort を下げる。決定を revisit させない指示も有効: "choose an approach and commit to it..."。

ハードなコスト上限が必要なら、Fable 5 / Mythos 5 では `budget_tokens` が 400 エラーなので、effort を下げるか `max_tokens` をハード上限に使う（`parameters.md` 参照）。

### thinking / interleaved thinking の活用

現行モデルは adaptive thinking を使い（Fable 5 / Mythos 5 は常時オン）、effort とクエリ複雑さで thinking 量を calibrate する。マルチステップのツール使用・複雑な coding・long-horizon agent loop で有効。ガイド例:

```text
After receiving tool results, carefully reflect on their quality and determine optimal next steps before proceeding. Use your thinking to plan and iterate based on this new information, and then take the best next action.
```

- prescriptive な手順より一般的な指示（"think thoroughly"）の方が良い推論を生むことが多い
- few-shot 例の中で `<thinking>` タグを使うと推論スタイルを一般化する
- thinking がオフのモデルでは manual CoT が fallback
- 自己チェックを促す: "Before you finish, verify your answer against [test criteria]."

## Agentic システム

### long-horizon 推論と状態追跡

現行モデルは強い状態追跡で長時間タスクを扱う。一度に全部でなく少数ずつ incremental に進めることで orientation を保つ。複数 context window / タスク反復にまたがるほど能力が現れ、状態を保存して fresh context で継続できる。

複数 context window のワークフロー:

- 最初の window は framework 構築（テスト作成・setup script）、以降の window で todo-list を反復
- テストを構造化形式（`tests.json`）で管理させ、「テストの削除・編集は機能欠落やバグを招くので不可」と念押し
- setup script（`init.sh`）でサーバ起動・テスト・lint を graceful にし再作業を防ぐ
- window クリア時は compaction より fresh context を検討（現行モデルは filesystem から状態を復元するのが得意）。`pwd` の確認・`progress.txt` / `tests.json` / git log のレビュー・基本的な integration test の実行を prescriptive に指示
- 状態データは構造化形式（JSON）、進捗ノートは自由テキスト、状態追跡には git を活用

### 自律性と安全性のバランス

ガイダンスがないと reversible でない行動（ファイル削除・force-push・外部投稿）を取りうる。reversibility と影響を考慮させ、hard to reverse / shared systems / destructive な行動は事前確認させる。障害時に destructive action を近道に使わない（`--no-verify` バイパスや不明ファイルの破棄をしない）ことも明示する。

### サブエージェント orchestration

現行モデルはサブエージェントをネイティブに orchestrate し、明示指示なしで適切に委譲する。ツール定義を明確にし自然に任せる。過剰使用（単純な grep で足りる探索にサブエージェントを spawn 等）が見えたら、いつ warranted かの明示ガイダンスを足す。

### 過剰エンジニアリング（Overeagerness）

余分なファイル・不要な抽象・要求外の柔軟性を作りがち。最小限に保つガイダンスを足す: scope を要求内に限定、変更していないコードに docstring / コメント / 型注釈を足さない、起こり得ないシナリオの防御コードを足さない、一度きりの操作に helper を作らない。

### テスト通過偏重・ハードコードの回避

テストを通すことに偏り、汎用解でなく workaround を使うことがある。「standard tools で高品質・汎用の解を書く。helper script や workaround を作らない。全 valid input で正しく動く実装をする。値をハードコードしない。テストは正しさの検証であって解の定義ではない」と指示する。

### hallucination の最小化（agentic coding）

現行モデルは hallucination が少ないが、さらに抑えるには `<investigate_before_answering>` で「開いていないコードを推測しない。参照されたファイルは回答前に必ず読む」と指示する。

## capability 別 tips

- Vision: crop / zoom ツールやスキルを与えると画像評価で一貫した uplift。反転・ぼやけ画像には Fable 5 が bash / crop を使う
- Frontend design: ガイダンスなしだと "AI slop" に収束しがち。`<frontend_aesthetics>` で typography / color / motion / background に distinctive な選択を促す

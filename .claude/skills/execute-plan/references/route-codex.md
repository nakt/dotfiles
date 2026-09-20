# Codex 経路: controller 手順

Phase 1 で実装経路として Codex が選ばれた場合に、controller (メインスレッド) が Phase 3 ステップ 2 (実装) で行う手順を定義する。
Codex に委譲するのは実装だけで、レビュー・コミット・`TaskUpdate`・エスカレーションは `SKILL.md` の記述どおり経路によらず共通。
Claude 経路の対応する手順は `references/route-claude.md` を参照。

## 実装の委譲

### 起動方法

controller (メインスレッド) が `Agent` ツールに `subagent_type: "codex:codex-rescue"` を渡して直接起動する。
`commands/rescue.md:8` は「`Agent` ツールは inline 実行だからこそスコープに残り、fork された general-purpose サブエージェントには渡らない」と明記しており、この呼び出し方を唯一の入口としている。
Codex の起動をサブエージェントに委ねることはできないため、メインスレッドである controller が直接起動する。

### プロンプトに載せる値

`Agent` の `prompt` には次の値を渡す。

1. Codex 向け指示書 (`references/codex-implementer-prompt.md`) の絶対パス
2. プランファイルの絶対パス
3. タスク番号
4. 再委譲時の追加指摘 (初回起動では渡さない)

並列バッチで実行する場合のみ、5 番目として「同一バッチの他タスクの対象ファイル一覧」を加える。
対象ファイルは渡さない。
`### Task N:` と `## 合意事項` の探索、対象ファイルの特定はリポジトリを自力で探索できる Codex 自身に行わせる (指示は Codex 向け指示書側に書く)。

パスはすべて `~` を展開した絶対パスで渡す。
`~` が Codex 側で展開される保証がないため。

### routing flag

初回起動では `--write --fresh --wait` を prompt 文字列に明示する (`Agent` ツールのパラメータではなく、`codex:codex-rescue` が自身のプロンプトテキストから読み取るルーティングフラグ)。

- `--write`: 付けないと `codex-companion.mjs` が読み取り専用サンドボックスでジョブを実行し、実装が丸ごと空振りする。wrapper (`codex:codex-rescue`) は既定でこのフラグを付けるが、プロンプトが調査・診断と読まれた場合は付けない規約になっているため、確実に付けるよう明示する。
- `--fresh`: このプロンプトが継続依頼と誤読されて `--resume-last` が付くのを防ぐ。
- `--wait`: 付けないと wrapper (`codex:codex-rescue`) がタスクを複雑・長時間と判断した場合にバックグラウンド実行を選び、`Agent` の戻り値がジョブ起動メッセージだけになる。この場合 controller は実装報告を回収できず、continuous execution の原則が崩れてユーザーの手動介入 (`/codex:result`) が要る。フォアグラウンド実行を確実にするため明示する。

## 再委譲時の Claude フォールバック

次の再委譲は、Codex への `--effort high` 再委譲ではなく、Claude 経路 (`references/route-claude.md` の「implementer の起動」) への fresh 起動 (`model=sonnet`) に切り替える。

- implementer の `DONE_WITH_CONCERNS` からの修正委譲 (影響ありと判断した場合)
- implementer の `NEEDS_CONTEXT` のうち、何ファイル読んでも理解が深まらず行き詰まっているのが原因の場合
- reviewer の `NEEDS_CHANGES` による再委譲
- pre-commit hook fail による再委譲
- エスカレーション後の追加指示つき再試行

`--effort high` (Codex 側の reasoning effort を上げる操作) は高確率で capacity error を誘発するため使用しない。
モデルを上げない Claude (`sonnet`) の経路に逃がすことで、再委譲そのものを安定させる。

このフォールバックは `AskUserQuestion` による確認を挟まず、controller が自動的に行う。
`SKILL.md` の「エスカレーション」(修正ループ超過 / `BLOCKED` 時の 3 択) とは別のフローであり、両者を混同しないこと。

フォールバックが発生した当該タスクは、以降そのタスクが完了するまで Claude 経路 (`route-claude.md`) のルールに従う (Codex には戻さない)。
他のタスクの初回実装は引き続き Codex 経路のまま進める。

いずれかの経路で昇格した場合、当該タスクは合意事項 A2 の「昇格済み」になる。
「昇格済み」とは、当該タスクで Claude 経路の implementer が `opus` で起動した、Codex 経路から Claude フォールバックが発生した、またはユーザーが実行時に `opus` を明示指定した、のいずれかが一度でも発生した状態を指す。
これは Claude 経路の `route-claude.md` における「implementer のモデル選択」と対応するルールである。
controller は「昇格済み」になった当該タスクについて reviewer も `opus` にする状態を保持し、タスクが完了するまで取り消さない。
したがって、1 タスク内でレビューが複数回走っても、一度「昇格済み」になれば以降は常に reviewer を `opus` にする。

## 戻り値の受け取り

`Agent` の戻り値は 2 通りある。

### ケース A: 戻り値が実装報告そのものの場合

Codex の実装報告 (先頭行が `Status:` から始まる) がそのまま返る。
これが通常の (前景実行の) 動作で、この場合はそのまま後述の「ステータス別の再委譲」に載せる。

### ケース B: 戻り値がジョブ起動メッセージの場合

`<タイトル> started in the background as <jobId>. Check /codex:status <jobId> for progress.` の形のメッセージが返ることがある。
wrapper (`codex:codex-rescue`) が自分の判断で background 実行を選んだ場合で、このメッセージが返った時点でも Codex の実装は走り続けている。

この場合、controller は報告本文を回収しない。
companion スクリプトの `status` / `result` を直接呼ぶ経路は取らない。
理由: それらはプラグイン内部の引数とパスに依存しており、プラグインが更新されると壊れる。

当該タスクをそこで中断し、次の内容をユーザーに報告して指示を待つ。

- Codex がバックグラウンド実行に回ったため、この経路では実装報告を回収できないこと
- メッセージから取り出した jobId
- 進捗は `/codex:status <jobId>`、結果は `/codex:result <jobId>` で確認できること
- Codex がまだ同じファイルを編集している可能性があるため、同じタスクを Codex で再試行しないこと

jobId は `started in the background as` の後ろから、`Check /codex:status` の直前にある `.` の手前までの文字列 (`.` は含まない)。
メッセージ末尾の `.` で切ると `for progress.` の `.` まで拾ってしまうので、区切りには `Check /codex:status` を使う。
同じ jobId が `/codex:status` の後にも繰り返されるので、両者が一致することを突き合わせて確認する。

ユーザーが `/codex:result <jobId>` で実装報告を取得して controller に渡した場合は、それをケース A と同じ implementer の報告として扱い、下記「ステータス別の再委譲」に載せる。
並列バッチの途中でこのケースに入った場合、同一バッチの他タスクはそのまま最後まで進め、中断したタスクだけをユーザーの指示待ちとして残す。

このケースを下記「Codex 起動失敗時の扱い」の 3 択に載せてはならない。
3 択の「Codex で再試行」を選ぶと、走り続けている Codex と新しく起動した Codex が同じファイルを同時に編集する。

## Codex 起動失敗時の扱い

次のいずれかに該当する場合、Codex 起動失敗として扱う。

- `Agent` の戻り値が空 (`codex:codex-rescue` は `Bash` 呼び出し失敗時に何も返さない規約)
- 戻り値の先頭行が `Status:` で始まらない

ただし上記「ケース B」のジョブ起動メッセージはこの判定から除外し、ケース B の手順に従う。
Codex は走り続けているので、3 択の「Codex で再試行」に載せると同じファイルを二重に編集することになる。

この場合、controller は自分の実装で肩代わりしない。
`AskUserQuestion` で次の 3 択をユーザーに提示する。

1. Codex で再試行
2. Claude の implementer に切り替えて再試行
3. 中止

「Claude の implementer に切り替えて再試行」を選んだ場合、当該タスクは `references/route-claude.md` の手順で再試行し、以降の残タスクも Codex 経路には戻さず Claude 経路のまま続ける。
経路が途中で行き来すると、どのタスクをどちらの経路が実装したか追えなくなるため。

## ステータス別の再委譲

implementer (Codex) の報告本文先頭行の `Status:` に応じて、再委譲先を次のように分ける。

| Status | 再委譲先 |
| -- | -- |
| `DONE` | 再委譲なし。レビュー段階へ進む (レビューのモデル選択は経路によらず共通。`SKILL.md` の「モデル選択方針」を参照) |
| `DONE_WITH_CONCERNS` | 懸念を読み、影響がなければレビュー段階へ。影響があれば上記「再委譲時の Claude フォールバック」に従い Claude (`sonnet`) の fresh implementer に修正委譲する |
| `NEEDS_CONTEXT` | 不足している参照先 (プランのタスク番号やファイルパスなど) を「再委譲時の追加指摘」としてプロンプトに加え、fresh `Agent` (`subagent_type: "codex:codex-rescue"`) に再委譲する。何ファイル読んでも理解が深まらず行き詰まっているのが原因の場合は、上記「再委譲時の Claude フォールバック」に従い Claude (`sonnet`) へ切り替える。原因は controller が報告の文面で見分ける |
| `BLOCKED` | `SKILL.md` の「エスカレーション」フローへ (`AskUserQuestion` の 3 択。追加指示を与えて再試行を選んだ場合は、ユーザー入力を「再委譲時の追加指摘」として渡し、上記「再委譲時の Claude フォールバック」に従い Claude (`sonnet`) の fresh implementer に再委譲する) |

reviewer の `NEEDS_CHANGES` による再委譲、および pre-commit hook fail による再委譲も同じ仕組みで、上記「再委譲時の Claude フォールバック」に従い Claude (`sonnet`) の fresh implementer に再委譲する。

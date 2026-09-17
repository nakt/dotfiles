# Claude 経路: controller 手順

`execute-plan` が実装経路として「Claude サブエージェント」を選んだ場合に controller が従う手順。
`SKILL.md` の複数箇所に散在していた Claude 経路固有の記述をここに集約する。
どの節から移したかは各見出しに付記する。

## implementer の起動 (元: Phase 3 ステップ 2)

バッチ内の各タスクに implementer `Agent` を起動する (バッチ内は同時起動可)。

- prompt では `~/.claude/skills/execute-plan/references/implementer-prompt.md` を `Read` し、それに従って実装するよう指示する。テンプレート本体は controller が読まず、prompt にも書き出さない
- あわせて渡す値は次の 8 つ: タスク番号 / プランファイルの絶対パス / 当該タスクの行範囲 / 合意事項の行範囲 (散在があれば追加の行範囲も) / 対象ファイル / 作業ディレクトリ / 並列実行時は同一バッチの他タスクの対象ファイル一覧 / 再委譲時の追加指摘 (初回の起動では無し)
- 合意事項の行範囲は Phase 2 「controller チェックリスト」で揃えたものを使う。合意事項なしのプランなら、合意事項の行範囲の代わりに Phase 1 ステップ 6 の固定文言を渡す
- `subagent_type=general-purpose`、初回起動は `model=sonnet` (ユーザーが `opus` を明示指定していればそれに従う。詳細は下記「implementer のモデル選択」)
- implementer は自分の対象ファイルのみ編集し、コミットはしない

## implementer のモデル選択 (元: モデル選択方針)

| ロール | 既定モデル | 切替条件 |
| -- | -- | -- |
| implementer (初回) | `sonnet` | 常に `sonnet` |
| implementer (再委譲) | `opus` | 実装のやり直しになる再委譲で昇格 |

controller は初回起動のモデルをタスクの複雑度で判定しない。
ただしユーザーが実行時に `opus` を明示指定した場合 (実行全体でもタスク単位でも) はそれに従う。

実装のやり直しになる再委譲では、次の 4 経路で implementer を `opus` に昇格させる。

- `NEEDS_CHANGES` による再委譲
- pre-commit hook fail による再委譲
- `DONE_WITH_CONCERNS` からの修正委譲
- エスカレーション後の追加指示つき再試行

implementer の `NEEDS_CONTEXT` は原因によって扱いが分かれる。
行範囲の不整合や参照先不足が原因の場合は `sonnet` のまま再委譲し、「何ファイル読んでも理解が深まらず、行き詰まっている」が原因の場合は `opus` に昇格させる。

## implementer のステータスハンドリング (元: ステータスハンドリング)

implementer subagent が返す 4 種の status ごとに、Claude 経路での再委譲の宛先と扱いは次のとおり。

| Status | 対応 |
| -- | -- |
| `DONE` | レビュー段階へ進む |
| `DONE_WITH_CONCERNS` | 懸念を読み、影響なければレビュー段階へ。影響あれば fresh implementer に `model=opus` で修正委譲 |
| `NEEDS_CONTEXT` | 行範囲の不整合が原因の場合は `sonnet` のまま、プランを読み直して行範囲を取り直してから fresh subagent を起動する。着手前の質問が原因の場合も `sonnet` のまま、不足分の参照先 (プランの行範囲、ファイルパス) を「再委譲時の追加指摘」として渡し fresh で再委譲する。ファイルに存在しない情報 (ユーザーからの口頭の指示など) に限って controller が文面を書く。「何ファイル読んでも理解が深まらず、行き詰まっている」が原因の場合は `model=opus` に昇格して再委譲する。原因は controller が報告の文面で見分ける |
| `BLOCKED` | 「エスカレーション」フローへ (`SKILL.md` 側、経路によらず共通) |

再委譲はいずれも fresh subagent (同じ Agent の継続ではない) で行う。

## acceptEdits モードの案内 (元: Phase 1 ステップ 9)

Claude 経路を選んだ場合、実装開始前に acceptEdits モード (`shift+tab` で切替) への切り替えをユーザーに 1 度だけ案内する。
理由: implementer subagent の Edit / Write が権限プロンプトで拒否されると自律実行が中断し、連続実行というスキルの狙いが崩れるため。
案内後は返答を待たずに続行してよい (切り替えなくても実行は可能だが、Edit ごとに確認が発生しうる)。

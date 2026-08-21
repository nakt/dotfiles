---
name: wrapup-dispatch
description: 長いセッションの終わりに、会話履歴から「やったこと・学び・決定・残すべき課題」と「反省・摩擦点(同じ修正の繰り返し / CLAUDE.md・rules を守れなかった場面)」を抽出・構造化し、既存のドキュメント化スキル(issue-tracker / record-adr / update-arch / update-readme)へ振り分け提案するルーター。自身は保存先を持たず、実体は各スキルに委譲する。「セッションをまとめて」「ラップアップして」「今日のセッションを振り返って記録に残して」「wrapup-dispatch」のような依頼で使う。GitHub PR/issue の操作には使わない。
argument-hint: "[なし] または振り返り範囲のヒント"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Skill
  - Bash(ls:*)
  - Bash(test:*)
  - Bash(date:*)
  - Bash(git log:*)
  - Bash(echo:*)
---

# Wrapup Dispatch

長いセッションの終わりに、会話セッションを唯一の一次入力として、残すべき知識(やったこと・学び・決定・課題・反省点)を抽出・整理し、既存のドキュメント化スキルへ振り分け提案するルーター。長いセッションで埋もれた要点を、会話が流れて失われる前に、適切な保存先へ送り出す役割。

このスキル自身は新しい保存先を一切持たず、ファイルも書かない。抽出した知識の実体は、すべて委譲先スキル(issue-tracker / record-adr / update-arch / update-readme)が各自の権限で書く。

## Current state

- issues/inbox: !`ls issues/inbox/ 2>/dev/null || echo '(none)'`
- docs/adr: !`ls docs/adr/[0-9]*.md 2>/dev/null || echo '(none)'`
- docs/arch: !`test -d docs/arch && echo 'yes' || echo 'no'`
- Recent commits: !`git log --oneline -10 2>/dev/null || echo '(none)'`
- Today: !`date +%Y-%m-%d`

上記は振り分け先の存在確認と重複回避の材料（重複回避の具体は「2. 振り分け判定」で扱う）。

## 1. 抽出(Collect)

### 引数による範囲指定

- `$ARGUMENTS` に範囲ヒント(例: 「今日の PR レビュー分」「直近 2 時間」「特定トピック名」)が渡されていれば、それを抽出対象スコープの絞り込みに使う。
- 引数が無ければセッション全体を対象とする。
- 範囲ヒントが会話文脈と照合できない場合(誤打鍵、範囲を絞れない語)は、一文で確認してから始める。
- 範囲ヒントは wrapup-dispatch 自身の抽出フェーズにのみ効かせる。委譲先へは従来どおり会話文脈で橋渡しする(理由は「4. 委譲」を参照)。

### 抽出カテゴリ

会話セッション全体を振り返り、根拠のある項目だけを下記カテゴリで列挙する。会話に裏づけの無い項目は作らない(捏造しない)。

- やったこと / 変更点
- 学び・発見(再利用可能な知識)
- 設計・ロジックの決定とその理由
- 残課題・未解決・後回しの TODO
- アーキテクチャ / プロジェクト構造の変化
- 反省・摩擦点(最重要・重点的に拾う): 「ルールやガイダンスの欠落・弱さ」を示す高価値シグナルなので、他カテゴリより優先して検出する。「何を・何回・なぜ繰り返したか / どのルールをどう破ったか」を具体的に記録する。検出の手がかり:
  - 同一の意図で 2 度目以降の修正指示が発生した箇所(数値ではなく意図ベースで判定)
  - 「さっきも言った」「また同じ」「前も指摘した」等の発話
  - 同一ファイル・同一シンボルへの手戻り編集の連鎖
  - CLAUDE.md / `~/.claude/rules/*.md` の各項目と実際の行動の突き合わせ(例: markdown-style の絵文字禁止に反した、git-workflow のブランチ規約を破った、workspace-management の `.workspace/` を使わず `/tmp` を使った 等)
  - 同一のエラー・警告をリトライ的に無視した箇所

## 2. 振り分け判定(Route)

各項目は、対応するドキュメント化スキル(issue-tracker / record-adr / update-arch / update-readme)の description を参照し、最も合致するものへ振り分ける。以下の表は行き先と出力先のみを示す(振り分け条件は各スキルの description に委ねる)。

| 行き先スキル | 出力先 |
| --- | --- |
| issue-tracker (create) | `issues/inbox/` |
| record-adr | `docs/adr/` |
| update-arch | `docs/arch/` |
| update-readme | `README.md` |
| 振り分けない(保留) | (なし。提示のみ) |

- 空提案をしない: update-arch / update-readme は処理フローやアプリコードの変化を前提とする。会話にその変化が無ければ arch / readme へは振り分けない。設定・スクリプト主体のリポジトリ（dotfiles、CI 設定、ドキュメント集など。Current state の `docs/arch` が `no` で、会話の変更対象が設定ファイルや Markdown に偏っていれば該当と見なせる）では特に該当が少ないので、無理に行き先を埋めない。
- 重複回避: Current state の `issues/inbox` / `docs/adr` を読み、既に起票・記録済みのテーマは再起票しない。
- 逆方向(クローズ)も提案: セッション中に既存の inbox issue が決着したなら done を提案に含める。委譲時は会話から抽出した決着メモ(決着理由 + 学び・経緯)を添えて、issue-tracker の done に渡す。これにより、クローズ時に学びを残して「issue-tracker の履歴をナレッジに活用」を双方向化する。
- Deprecated 化も提案: セッション中に既存 ADR の方針を後継方針なしでやめたなら、Deprecated 化を提案に含める(代わりの方針を立てて乗り換えた場合は従来どおり新規起票として扱う)。委譲時は対象 ADR 番号とやめた理由を record-adr に渡す。

## 3. 提案(Propose)

行き先ごとにグルーピングした振り分け提案を提示する。各項目は「1 行サマリ + なぜその行き先か」。採否をユーザーに確認してから次へ進む。承認なしに大量起票しない。

抽出が空、もしくは振り分けるに値する項目が無ければ「残すべき項目は無い」と伝えて終わる。空の起票を委譲しない。

## 4. 委譲(Dispatch)

承認された項目について、`Skill` ツールで同一会話の中でそのまま対応スキルを続けて起動する。このスキルの `allowed-tools` には読み取り系と `Skill` しか無く書き込みツールを持たないが、起動された各スキルは自分の `allowed-tools` で書き込むため、wrapup-dispatch 自身は何も書かないまま実体が作られる。Claude Code にはスキル間で引数を渡す正式 API が無いので、振り分け提案で確定した抽出内容を、続く各スキル起動の入力(直近会話の文脈)として渡す形で橋渡しする。

バッチ方針: 承認された項目は行き先ごと(スキル × モード)にグルーピングし、1 つにつき 1 回でまとめて委譲する(1 件ずつ起動して往復を増やさない)。具体的には issue-tracker create は複数件を 1 回、issue-tracker done も別途 1 回、record-adr の起票も複数件を 1 回、record-adr の Deprecated 化も別途 1 回、update-arch / update-readme はそれぞれ 1 回。

- issue-tracker → create モードで起票(反省・摩擦点は「ルールを追加/強化して再発防止」の TODO として起票する) / done モードで決着メモ付きクローズ(決着理由 + 学び・経緯を渡す)
- update-arch → 更新 / 初期化
- update-readme → 更新
- record-adr → 起票: タイトルと Context / Decision / Rationale の素案を渡して同一会話で起動 / Deprecated 化: 対象 ADR 番号と、後継方針を立てずにやめたこと・その理由を渡して同一会話で起動

## 5. 完了マニフェスト(Report)

Dispatch が終わったら、最終サマリを行き先スキル別の `###` サブ見出し + パス一覧の箇条書きで提示する。ラップアップの出口として「どこに何を書いたか / 何を保留にしたか」を一望できる形にする。

- `### issue-tracker (create)` / `### issue-tracker (done)` / `### update-arch` / `### update-readme` / `### record-adr (起票)` / `### record-adr (Deprecated 化)` の節に、書き込まれたパス一覧(例: `issues/inbox/20260707-xxx.md`, `docs/arch/flow.md`, `docs/adr/NNNN-*.md` 等)を箇条書き。
- `### 保留` の節に、承認されず保留になった項目を「1 行サマリ + 保留理由」で列挙。

抽出が空、または承認された委譲が無かった場合はマニフェスト自体を省略してよい。

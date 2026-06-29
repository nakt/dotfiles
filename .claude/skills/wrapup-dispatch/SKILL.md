---
name: wrapup-dispatch
description: 長いセッションの終わりに、会話履歴から「やったこと・学び・決定・残すべき課題」と「反省・摩擦点(同じ修正の繰り返し / CLAUDE.md・rules を守れなかった場面)」を抽出・構造化し、既存のドキュメント化スキル(issue-tracker / record-adr / update-arch / update-readme)へ振り分け提案する蒸留ルーター。自身は保存先を持たず、実体は各スキルに委譲する。「セッションをまとめて」「ラップアップして」「今日のセッションを振り返って記録に残して」「wrapup-dispatch」のような依頼、または長いセッションの区切りで使う。GitHub PR/issue の操作には使わない。
argument-hint: "[なし] または振り返り範囲のヒント"
allowed-tools: Read(*), Glob(*), Grep(*), Bash(ls:*), Bash(test:*), Bash(date:*), Bash(git status:*), Bash(git log:*), Bash(git diff:*)
---

# Wrapup Dispatch

長いセッションの終わりに、会話セッションを唯一の一次入力として知識を蒸留し、既存のドキュメント化スキルへ振り分け提案する蒸留ルーター。記事「揮発と蒸留」でいう「短期記憶(会話)から長期記憶への蒸留装置」にあたる。

このスキル自身は新しい保存先を一切持たず、ファイルも書かない。蒸留した知識の実体は、すべて委譲先スキル(issue-tracker / record-adr / update-arch / update-readme)が各自の権限で書く。`allowed-tools` を読み取り + 状態把握のみに絞っているのは、この「純粋ルーター」性をツールレベルで担保するため。

## Current state

- issues/inbox: !`ls issues/inbox/ 2>/dev/null || echo '(none)'`
- docs/adr: !`ls docs/adr/[0-9]*.md 2>/dev/null || echo '(none)'`
- docs/arch: !`test -d docs/arch && echo 'yes' || echo 'no'`
- Recent commits: !`git log --oneline -10 2>/dev/null || echo '(none)'`
- Today: !`date +%Y-%m-%d`

上記は振り分け先の存在確認と重複回避の材料。`issues/inbox` / `docs/adr` に既出のテーマは再起票しない。

## 1. 抽出(Collect)

会話セッション全体を振り返り、根拠のある項目だけを下記カテゴリで列挙する。会話に裏づけの無い項目は作らない(捏造しない)。

- やったこと / 変更点
- 学び・発見(再利用可能な知識)
- 設計・ロジックの決定とその理由
- 残課題・未解決・後回しの TODO
- アーキテクチャ / プロジェクト構造の変化
- 反省・摩擦点(最重要・重点的に拾う): (a) 同じ修正・指摘を何度も繰り返した箇所、(b) CLAUDE.md / rules に記載のルールを遵守できなかった場面。これらは「ルールやガイダンスの欠落・弱さ」を示す高価値シグナルなので、他カテゴリより優先して検出する。「何を・何回・なぜ繰り返したか / どのルールをどう破ったか」を具体的に記録する。

## 2. 振り分け判定(Route)

各項目を行き先スキルへマッピングする。判定ルーブリック:

| 抽出項目のシグナル | 行き先スキル | 出力先 |
| --- | --- | --- |
| 不具合・課題・TODO・後回しにした調査 | issue-tracker (create) | `issues/inbox/` |
| 反省・摩擦点(同じ修正の繰り返し / CLAUDE.md・rules 違反) | issue-tracker (create) | `issues/inbox/`(「ルール X を追加/強化して再発防止」の再発防止 TODO として起票) |
| 設計・ロジックの「決定とその理由」 | record-adr | `docs/adr/` |
| 処理フロー・データフロー・コンポーネント構成の変化 | update-arch | `docs/arch/` |
| プロジェクト構造・使い方・セットアップの変化 | update-readme | `README.md` |
| どこにも当てはまらない雑多なメモ | 振り分けない(保留) | (なし。提示のみ) |

- 設定リポジトリでの注記: update-arch / update-readme は処理フローやアプリコードの変化を前提とする。この dotfiles のような設定リポジトリでは該当が少ないので、該当する変化が会話に無ければ arch / readme へは空提案しない。
- 重複回避: Current state の `issues/inbox` / `docs/adr` を読み、既に起票・記録済みのテーマは再起票しない。
- 逆方向(クローズ)も提案: セッション中に既存の inbox issue が決着したなら done を提案に含める。委譲時は会話から蒸留した決着メモ(決着理由 + 学び・経緯)を添えて、issue-tracker の done に渡す。これにより、クローズ時に学びを残して「issue-tracker の履歴をナレッジに活用」を双方向化する。

## 3. 提案(Propose)

行き先ごとにグルーピングした振り分け提案を提示する。各項目は「1 行サマリ + なぜその行き先か」。採否をユーザーに確認してから次へ進む。承認なしに大量起票しない。

抽出が空、もしくは振り分けるに値する項目が無ければ「蒸留して残すべき項目は無い」と伝えて終わる。空の起票を委譲しない。

## 4. 委譲(Dispatch)

承認された項目について、同一会話の中でそのまま対応スキルを続けて起動する。このスキルの `allowed-tools` は読み取りのみだが、起動された各スキルは自分の `allowed-tools` で書き込むため、wrapup-dispatch 自身は何も書かないまま実体が作られる。Claude Code にはスキル間で引数を渡す正式 API が無いので、振り分け提案で確定した蒸留内容を、続く各スキル起動の入力(直近会話の文脈)として渡す形で橋渡しする。

- issue-tracker → create モードで起票 / done モードで決着メモ付きクローズ(決着理由 + 学び・経緯を渡す)
- update-arch → 更新 / 初期化
- update-readme → 更新
- record-adr → `disable-model-invocation: true` のため同一会話でも自動起動できない。ここだけは手動ハンドオフとし、タイトルと Context / Decision / Rationale の素案を提示して、ユーザーに `/record-adr "<title>"` の手動実行を促す。

## Key Principles

1. 純粋ルーター。自前の保存先を持たず、自分では書かない。実体は委譲先スキルが書く。
2. 一次入力は会話セッション。`Current state` の既存 issue / adr は重複回避と突き合わせにのみ使う。
3. 捏造しない。会話に根拠のある項目だけを抽出・振り分けする。
4. 反省・摩擦点を最優先で拾う。同じ修正の繰り返しや CLAUDE.md / rules 違反は、ルールの欠落・弱さを示す最重要シグナル。issue-tracker に「再発防止のためのルール追加/強化」TODO として起票する。
5. 承認を経てから委譲する。自動で一括起票しない。
6. 既存と重複する項目は再起票しない。決着済みは done を提案する。
7. Markdown スタイルは `~/.claude/rules/markdown-style.md` に従う。

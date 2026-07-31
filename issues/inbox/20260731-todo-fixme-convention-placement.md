---
id: 20260731-todo-fixme-convention-placement
title: TODO/FIXME 規約が言語別 dev-guide にあり jsx 専用構成と Python に届かない
created: 20260731
updated: 20260731
priority:            # high|med|low、任意。無ければ棚卸し時に推定される
tags: []             # 自由。特殊タグ `hold` は「今はやらない」表明で triage 候補から外れる
related: []          # 関連 issue の id（パスではなく id で参照する）
sources:
  - .claude/skills/typescript-dev-guide/SKILL.md
  - .claude/skills/python-dev-guide/SKILL.md
  - .claude/skills/react-dev-guide/SKILL.md
  - .claude/rules/typescript-coding.md
  - .claude/rules/react-coding.md
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない（MD025 回避） -->

## TL;DR

TODO / FIXME ラベル規約が 3 つの言語別 dev-guide（python / typescript / react）に重複していたため typescript-dev-guide 1 箇所に集約したが、`.jsx` 専用構成と Python には規約が届かなくなった。言語非依存の規約を言語別 dev-guide に置く限りどこを選んでも穴が残る構造にあり、恒久的な置き場は常時ロードされる rule ではないか、という論点が残っている。

## 背景 / 問い

Claude Code 設定群（`.claude/` 配下の rules / skills）の棚卸し作業中、`- 一時コメントには TODO / FIXME ラベルを使用` という同一の規約が python-dev-guide / typescript-dev-guide / react-dev-guide の 3 つの SKILL.md に重複して存在しているのを見つけた。受け入れ条件を「3 つの dev-guide のうち 1 箇所のみに存在する」と定め、1 箇所への集約を行った。その集約先選定の過程で、言語別 dev-guide に置く構造自体に穴があることに気づいた。

## 調査結果

### 事実

- `- 一時コメントには TODO / FIXME ラベルを使用` という同一の規約文言が、python-dev-guide / typescript-dev-guide / react-dev-guide の 3 つの SKILL.md に重複していた。
- 今回の棚卸しで、この規約を typescript-dev-guide/SKILL.md 1 箇所に集約し、python-dev-guide と react-dev-guide からは削除した。
- 集約先を typescript-dev-guide にした理由は、`.claude/rules/typescript-coding.md` が `**/*.ts` と `**/*.tsx` の 2 拡張子で発火し、`.tsx` では `.claude/rules/react-coding.md` 経由でも同時にロードされるため、3 択の中で最も到達範囲が広かったこと。
- ただし次の 2 つの構成では規約が届かない。
  - `.jsx` 専用の構成。`react-coding.md` は `**/*.jsx` も対象にするが、react-dev-guide からは規約を削除済みのため、`.jsx` のみのプロジェクトでは規約自体が参照されない。
  - Python。python-dev-guide からも規約を削除したため、`.py` ファイルの作業では規約が参照されない。変更前は python-dev-guide が規約を保持していたため、今回の集約で Python 側は実質的なカバレッジ後退になっている。

### 解釈

TODO / FIXME のラベル運用は言語に依存しない規約である。言語別の dev-guide（スキル）側に置く限り、3 つのうちどれを選んでも「そのスキルをトリガーする rule の対象拡張子」の外側では規約が届かない構造になっている。今回 typescript-dev-guide を選んだことで到達範囲は最大化したが、それでも `.jsx` 専用構成と Python は覆えない。

この構造問題を解消するなら、置き場を言語別 dev-guide から `.claude/rules/` 配下の、`paths` を持たず常時ロードされる rule（例: `markdown-style.md` や `git-workflow.md` と同じ位置づけ）に移すのが筋と考えられる。常時ロードの rule であれば、拡張子や言語を問わず一貫して規約が適用される。

ただし今回の棚卸しでは `.claude/rules/` への追加・変更は承認範囲に含まれておらず、受け入れ条件も「3 つの dev-guide のうち 1 箇所のみに存在する」という dev-guide 内での集約に限定していたため、rule 層への移動というより根本的な対応には手を付けていない。

## 結論 / プラン

- [ ] TODO / FIXME 規約を常時ロードされる rule に移すか、言語別 dev-guide に置いたままにするかを決める
- [ ] rule に移す場合、どの rule に置くか（既存の markdown-style のような主題別の rule を新設するか、既存のどれかに相乗りするか）を決める

## 未解決の論点 / リスク

- 常時ロードの rule に置くと、コードを書かないセッションでも毎回読み込まれる。1 行の規約に常駐コストを払う価値があるかは判断が要る。
- 逆に dev-guide に置いたままにする場合、`.jsx` 専用構成と Python で規約が届かない状態が今後も続く。
- Python は変更前に規約を持っていたため、今回の集約は Python にとって実質的なカバレッジ後退である。次に手を入れる際はこの後退を踏まえる必要がある。

## ログ

<!-- 追記専用。日付つきで状態変化を記録。
     done 化時はここに決着メモを残す:
       - <date> done: <決着理由 1 行>
         - 経緯: <何をして解決したか>
         - 学び: <得た知見。無ければ省略>
     文脈が薄ければ done: の 1 行のみでもよい -->

- 20260731 created

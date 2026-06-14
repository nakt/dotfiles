---
name: okf-format
description: 渡された Markdown を Google の OKF (Open Knowledge Format) の構造・フォーマットに整理するスキル。単一の .md ファイルを OKF concept document（YAML frontmatter + 慣例見出し）に整形するモードと、ディレクトリ全体を OKF バンドル（index.md / log.md / 概念ドキュメント群 + バンドル相対リンク）に整理するモードを持つ。ユーザーが「この .md を OKF にして」「OKF 形式で整理して」「OKF バンドルにまとめて」「Open Knowledge Format に変換して」と言ったとき、または知識を frontmatter 付きの可搬な Markdown 知識カタログとして構造化したいときに使用する。既存の内容を再構成・メタデータ付与するのみで、事実の捏造はしない。
allowed-tools: Read(*), Glob(*), Grep(*), Write(*), Bash(ls:*), Bash(find:*), Bash(head:*)
---

# OKF Format

渡された Markdown を OKF (Open Knowledge Format) の構造・フォーマットに整理する。OKF は Google Cloud の knowledge-catalog プロジェクトが提唱する、ベンダー中立で人間にもエージェントにも読める知識表現フォーマット。実体は「YAML frontmatter 付きの素の Markdown ファイル群」であり、専用ツールは不要。

仕様の出典: <https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md>

## OKF の設計思想（このスキルが守るべき前提）

- 人間と機械の両方が読める（特別なツール不要。LLM がそのままコンテキストに取り込める）
- バージョン管理できる（git の PR / diff ワークフローに乗る）
- 可搬（ファイルシステム・tarball・任意リポジトリのサブディレクトリから配信可能）
- 拡張可能（必須フィールドは最小限。任意の frontmatter フィールドや Markdown セクションを追加してよい）
- グラフ表現可能（Markdown リンクで階層を超えた関係を表す）

## スコープと 2 つのモード

入力を見てモードを判定する。

| 入力 | モード | 出力（デフォルト） |
| --- | --- | --- |
| 単一の `.md` ファイル | concept モード | 元ファイルを残し、`<name>.okf.md` を新規生成 |
| ディレクトリ | bundle モード | 元ディレクトリを残し、`<dir>-okf/` を新規生成 |

デフォルトは「新規ファイル/ディレクトリへの出力」で、元のファイルは変更しない。ユーザーが「上書きで」と指示した場合のみ元ファイルを書き換える（その場合は git で diff が確認できる状態であることを前提とする）。出力先の指定があればそれに従う。

## 共通の大原則

- 既存の内容の再構成・並べ替え・メタデータ付与のみを行う。本文に書かれていない事実・スキーマ・引用を捏造しない
- frontmatter に入れるべき値（title / description など）が本文から読み取れない場合は推定する。`type` が決められない場合だけはユーザーに確認する（後述）
- 元の文体は維持する。要約や言い換えで内容を痩せさせない

## concept モード（単一ファイルの整形）

OKF の concept document は **YAML frontmatter** と **Markdown 本文** の 2 部構成。

### 手順

1. 入力ファイルを Read する
2. 既存の frontmatter があれば取り込み、なければ本文から下表のフィールドを抽出・推定する
3. `type` を決める（必須・非空）。本文から判断できないときだけユーザーに確認する
4. 本文を慣例見出しに沿って再構成する
5. 内部参照があればバンドル相対リンク（`/` 始まり）に整える
6. 末尾に `# Citations` を置き、本文が参照している外部 URL を採番してまとめる
7. `<name>.okf.md`（または指定先）に Write する

### frontmatter フィールド仕様

```yaml
---
type: BigQuery Table            # REQUIRED: 概念の種別。非空であること（例: "Playbook", "API Endpoint"）
title: Customer Orders          # recommended: 表示名
description: 1 行サマリ          # recommended: 一行要約
resource: https://...           # recommended: 元アセットの正規 URI
tags: [sales, orders, revenue]  # recommended: 分類タグ（YAML リスト）
timestamp: 2026-05-28T14:30:00Z # recommended: 最終更新の ISO 8601 日時
---
```

- `type` だけが REQUIRED。これが非空であればフォーマット上は適合する
- それ以外は recommended。読み取れない recommended フィールドは省略してよい（捏造しない）
- 仕様外の独自フィールドを追加してよい（拡張可能性）

### 本文の慣例見出し

タイトルは frontmatter の `title` が担うため、本文の見出しは「セクション見出し」として使う。SPEC の例（§4.3）は本文セクションを `#`（h1）で開始している。慣例的に使われる見出し:

| 見出し | 用途 |
| --- | --- |
| `# Schema` | 構造化アセット（テーブル等）のカラム定義。GFM テーブルで `Column / Type / Description` |
| `# Examples` | 使い方やクエリのコード例 |
| `# Joins` | 他概念との結合関係（リンクで相手を指す） |
| `# Citations` | 主張の根拠となる外部参照。採番リスト |

これら以外の自由なセクションを追加してよい。本文の内容に合う見出しを選び、元の章立てを OKF の慣例に寄せる。

> 補足: house の `markdown-style` ルールは「`#` はドキュメントに 1 つ」を推奨するが、OKF concept document はタイトルを frontmatter に置き本文セクションを `#` で並べる仕様。OKF を優先する。絵文字不使用・過度な太字回避といった他の `markdown-style` ルールは引き続き守る。

### concept document の完成例

```markdown
---
type: BigQuery Table
title: Customer Orders
description: One row per completed customer order across all channels.
resource: https://console.cloud.google.com/bigquery?p=acme&d=sales&t=orders
tags: [sales, orders, revenue]
timestamp: 2026-05-28T14:30:00Z
---

# Schema

| Column        | Type      | Description                                         |
|---------------|-----------|-----------------------------------------------------|
| `order_id`    | STRING    | Globally unique order identifier.                   |
| `customer_id` | STRING    | Foreign key into [customers](/tables/customers.md). |
| `total_usd`   | NUMERIC   | Order total in US dollars.                           |
| `placed_at`   | TIMESTAMP | When the customer submitted the order.              |

# Joins

Joined with [customers](/tables/customers.md) on `customer_id`.

# Citations

[1] [BigQuery table schema](https://console.cloud.google.com/bigquery?p=acme&d=sales&t=orders)
```

## bundle モード（ディレクトリ全体の整理）

バンドルは Markdown ファイルを階層的に並べたディレクトリツリー。

### 構成要素

- ルートおよび各サブディレクトリに `index.md`（ディレクトリ目録、任意だが推奨）
- ルートに `log.md`（更新履歴、任意）
- それ以外の `.md` はすべて concept document
- サブディレクトリは無制限にネスト可能。整理の都合でグループ分けに使う

実際の OKF バンドル（公式サンプル）は、`datasets/` `tables/` `references/` のように種別でディレクトリを切り、各階層に `index.md` を置く構成になっている。

### 手順

1. 対象ディレクトリ配下の `.md` を Glob で列挙する
2. 各 `.md` を concept モードの手順で OKF concept document に整形する
3. 内部リンクをバンドル相対リンク（`/` 始まり）に張り直す
4. 各ディレクトリ階層に `index.md` を生成する
5. ルートに `log.md` を生成（または既存があれば追記）する
6. すべてを出力先（デフォルト `<dir>-okf/`）に同じ階層で書き出す

### index.md の仕様

- frontmatter は付けない（予約ファイル）
- セクション見出しでグルーピングし、各項目をリンク + 短い説明の箇条書きで並べる（progressive disclosure）
- サブディレクトリへのリンクは `subdir/`（または `subdir/index.md`）の形で張る

```markdown
# Section / Group Heading

* [Title 1](relative-url-1) - short description of item 1
* [Title 2](relative-url-2) - short description of item 2

# Another Section

* [Subdirectory](subdir/) - short description of the subdirectory
```

### log.md の仕様

- 日付（ISO 8601）ごとにグルーピングし、新しい日付を上に置く
- 慣例プレフィックス: `Initialization` / `Creation` / `Update` / `Deprecation`

```markdown
# Directory Update Log

## 2026-05-22
* **Update**: Added new BigQuery table reference for [Customer Metrics](/tables/customer-metrics.md).
* **Creation**: Established the [Dataplex Playbook](/playbooks/dataplex.md).

## 2026-05-15
* **Initialization**: Created foundational directory structure.
```

## リンク規約

- 絶対（バンドル相対）リンク: `/` 始まりでバンドルルートからのパス。**推奨**
- 相対リンク: 通常の Markdown 相対パスも可
- リンクは関係性の表明であり、関係の種類はリンク構文ではなく周囲の文章で表す
- consumer は壊れたリンクを許容する前提なので、リンク切れがあっても変換は止めない

## 適合性チェックリスト（出力前に確認）

- [ ] 予約ファイル（`index.md` / `log.md`）以外のすべての `.md` に解析可能な YAML frontmatter がある
- [ ] そのすべての frontmatter に非空の `type` がある
- [ ] `index.md` には frontmatter を付けていない
- [ ] `log.md` は日付降順・ISO 8601 で構成されている
- [ ] 内部リンクはできるだけバンドル相対（`/` 始まり）にした
- [ ] 本文に存在しない事実・引用を追加していない

## 制約

- 必須は `type` の非空のみ。その他は soft guidance であり、不明な recommended フィールドは無理に埋めない
- 絵文字はユーザーが明示要求しない限り使わない。過度な太字を避ける（`markdown-style` に従う）
- markdownlint は PostToolUse hook が自動実行するため自分で実行しない。lint フィードバックが来たら Edit で従う
- 出力はデフォルトで新規ファイル/ディレクトリ。元ファイルの上書きは明示指示があるときのみ

## 参考

- SPEC: <https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md>
- OKF README（設計思想・enrichment agent・visualizer）: <https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf>
- 公式サンプルバンドル（ga4 / stackoverflow / crypto_bitcoin）: <https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf/bundles>

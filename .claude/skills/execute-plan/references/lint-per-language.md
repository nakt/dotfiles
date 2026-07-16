# Lint / Hook 言語別パターン

`references/implementer-prompt.md` の「実行手順」で規定した「対象ファイル明示 + fix→check 2 段 + 設定検出条件付き実行」の原則に対して、言語別の判定・実行コマンドを載せる。実装者 (implementer subagent) が Phase 3 で本ファイルを参照して、対象ファイルの言語系統に対応するセクションを選び、記載のコマンドを実行する。

未収載言語 (Rust / Go / Elixir 等) は、原則に従って implementer が対象リポのツールチェーンから判断すること。判断がついたら本ファイルに新セクションを追加すると次回以降が楽になる (末尾「新言語追加時のフォーマット」を参照)。

## Python

### 系統判定

`test -f pyproject.toml` が真なら Python 系統。

### パッケージマネージャ前置

`test -f uv.lock` または `grep -q "^\[tool.uv" pyproject.toml` が真なら以降のコマンドに `uv run` を前置する。そうでなければ素で実行 (`uv run` を付けない)。以下の例では `[uv run]` と書いた箇所に前置を入れる / 入れない、を判定結果で決める。

### フォーマッタ / linter 検出 (ruff)

以下のいずれかが真なら ruff がリポで使われている:

- `grep -q "^\[tool.ruff" pyproject.toml`
- `test -f ruff.toml`
- `test -f .ruff.toml`

### hook 検出 (pre-commit)

`test -f .pre-commit-config.yaml` が真なら pre-commit がリポで使われている。

### 対象ファイル明示コマンド

ruff が検出された場合、対象ファイルパスを引数に渡して以下を順に実行:

```bash
[uv run] ruff format <対象ファイル>
[uv run] ruff format --check <対象ファイル>
[uv run] ruff check <対象ファイル>
```

pre-commit が検出された場合、対象ファイルを引数に渡して以下を実行:

```bash
[uv run] pre-commit run --files <対象ファイル>
```

リポ全体に対する `ruff format --check .` や `pre-commit run --all-files` だけで pass 判定しないこと。他ファイルの pass に紛れて自分の編集ファイルの fail を見落とす原因になる。

### スキップ時の報告文言テンプレ

ruff / pre-commit がいずれも検出されなかった場合、報告に以下を含める:

```text
lint / hook 実行: Python 系統だが ruff (pyproject / ruff.toml) と pre-commit (.pre-commit-config.yaml) がいずれも検出されず、スキップ
```

## TypeScript / JavaScript

### 系統判定

`test -f package.json` が真なら TypeScript / JavaScript 系統。

### パッケージマネージャ前置

以下の優先順で判定:

1. `test -f bun.lockb` または `test -f bun.lock` が真なら `bun run` (バイナリを直接叩く場合は `bun x`)
2. そうでなくて `test -f pnpm-lock.yaml` が真なら `pnpm exec`
3. そうでなくて `test -f yarn.lock` が真なら `yarn` (バイナリ直叩きは `yarn <name>`)
4. そうでなくて `test -f package-lock.json` が真なら `npx` または `npm exec`
5. どれも無ければ素で実行 (グローバル install や PATH に頼るフォールバック)

以下の例では `[<pm> exec]` と書いた箇所に、判定した前置を入れる。素実行の場合は前置なし。

### フォーマッタ / linter 検出

biome, eslint, prettier のいずれか / 複数が併用される。以下の順で検出:

- biome: `test -f biome.json` OR `test -f biome.jsonc` OR `grep -q '"biome"' package.json`
- eslint: `test -f eslint.config.js` OR `test -f eslint.config.mjs` OR `test -f eslint.config.cjs` OR `test -f eslint.config.ts` OR `test -f .eslintrc.js` OR `test -f .eslintrc.json` OR `test -f .eslintrc.cjs` OR `test -f .eslintrc.yml` OR `grep -q '"eslintConfig"' package.json`
- prettier: `test -f .prettierrc` OR `test -f .prettierrc.json` OR `test -f .prettierrc.js` OR `test -f prettier.config.js` OR `grep -q '"prettier"' package.json`

同じリポで複数検出されたら、全てを対象ファイル明示で実行する。

### hook 検出 (husky / lint-staged)

- husky: `test -d .husky`
- lint-staged: `grep -q '"lint-staged"' package.json` または `test -f .lintstagedrc*`

### 対象ファイル明示コマンド

biome が検出された場合:

```bash
[<pm> exec] biome check --write <対象ファイル>
[<pm> exec] biome check <対象ファイル>
```

eslint が検出された場合:

```bash
[<pm> exec] eslint --fix <対象ファイル>
[<pm> exec] eslint <対象ファイル>
```

prettier が検出された場合:

```bash
[<pm> exec] prettier --write <対象ファイル>
[<pm> exec] prettier --check <対象ファイル>
```

husky / lint-staged が検出された場合 (pre-commit 相当の hook を回す):

```bash
[<pm> exec] lint-staged --diff=HEAD --files <対象ファイル>
```

リポ全体に対する `biome check .` / `eslint .` / `lint-staged` だけで pass 判定しないこと。他ファイルの pass に紛れて自分の編集ファイルの fail を見落とす原因になる。

### スキップ時の報告文言テンプレ

linter / hook がいずれも検出されなかった場合、報告に以下を含める:

```text
lint / hook 実行: TypeScript / JavaScript 系統だが biome / eslint / prettier / husky / lint-staged がいずれも検出されず、スキップ
```

## 新言語追加時のフォーマット

新しい言語系統を本ファイルに追加するときは、以下の統一フォーマットで書く (Python / TS・JS セクションと同じ順序)。

```markdown
## <言語系統名>

### 系統判定

`<系統ファイル検出コマンド>` が真なら本系統。

### パッケージマネージャ前置

<判定コマンドと結果に応じた前置ルール>

### フォーマッタ / linter 検出

<ツール名ごとの検出コマンド (複数ツール併用可)>

### hook 検出

<hook 設定ファイルの検出コマンド>

### 対象ファイル明示コマンド

<対象ファイルパスを引数に渡した fix → check 2 段の具体コマンド>

### スキップ時の報告文言テンプレ

<検出条件が全て偽だった場合の報告文言>
```

`references/implementer-prompt.md` の原則 (対象ファイル明示 + fix→check 2 段 + リポ全体 pass に紛れさせない) は言語非依存で必ず守ること。新セクション追加時に原則を破らないように既存 2 系統を参考にする。

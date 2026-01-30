# TypeScript Development Guide

bun + Biome を使った TypeScript 開発の支援スキル。プロジェクト構成、型設計、コーディング規約のガイドラインを提供する。

## When to use

- TypeScript プロジェクトを新規作成するとき
- tsconfig.json の設定を整えるとき
- 型設計のパターン（Result 型、Zod バリデーション等）を確認したいとき
- 型戦略やエラーハンドリング方針の判断基準が欲しいとき
- Biome の設定やプロジェクト構成を整えるとき
- TypeScript のコーディング規約を確認したいとき

## Instructions

### 役割

- TypeScript 開発のベストプラクティスに基づいたコード設計を支援する
- bun + Biome の技術スタックを前提とした開発ガイドを提供する
- 型安全性を重視した設計パターンを推奨する
- 技術選定では Decision Guide の判断基準に基づいて推奨する

## Quick Start

bun でプロジェクトを開始する:

```bash
# 1. プロジェクト初期化
bun init

# 2. TypeScript 設定を厳格化
# tsconfig.json を編集

# 3. 開発ツールをセットアップ
bun add -d @biomejs/biome
bun run biome init
```

## Common Commands

```bash
# 実行
bun run src/index.ts           # TypeScript を直接実行
bun build ./src/index.ts       # ビルド

# 型チェック
bun run tsc --noEmit           # 型チェックのみ
bun run tsc --noEmit --watch   # ウォッチモード

# フォーマット/Lint (Biome)
bun run biome check .          # チェック
bun run biome check --write .  # 自動修正

# テスト (Vitest)
bun run test                   # テスト実行
bun run test --watch           # ウォッチモード
```

## Recommended tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noEmit": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  },
  "include": ["src"]
}
```

## Biome Configuration

`biome.json`:

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "organizeImports": { "enabled": true },
  "linter": {
    "enabled": true,
    "rules": { "recommended": true }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2
  }
}
```

## Coding Conventions

### Comment Labels

一時的なコメントには以下のラベルを使用:

- `TODO`: 後で実装する作業
- `FIXME`: 修正が必要な問題

```typescript
// TODO: キャッシュ機能を追加
function fetchData(id: string) {
  // FIXME: エラーハンドリングが不足
  return fetch(`/api/${id}`)
}
```

### Type Annotations

型推論を活用し、必要な箇所のみアノテーション:

```typescript
// 推論可能な場合は省略
const count = 0
const name = "hello"

// 関数の引数と返り値は明示
function add(a: number, b: number): number {
  return a + b
}

// オブジェクトは interface/type で定義
interface User {
  id: string
  name: string
}
```

### Import Organization

型インポートは `type` キーワードを使用:

```typescript
import type { User } from "./types"
import { fetchUser } from "./api"
```

### Result Type Pattern

エラーハンドリングに Result 型を使用:

```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E }

function parseJson<T>(json: string): Result<T> {
  try {
    return { ok: true, value: JSON.parse(json) }
  } catch (e) {
    return { ok: false, error: e as Error }
  }
}
```

### Zod for Validation

外部データのバリデーションには Zod を使用:

```typescript
import { z } from "zod"

const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.string().email(),
})

type User = z.infer<typeof UserSchema>

// 使用例
const result = UserSchema.safeParse(data)
if (result.success) {
  console.log(result.data)
}
```

## Decision Guide

### Type Strategy

| Situation | Choice | Rationale |
|---|---|---|
| API response | Zod + infer | Runtime validation and type generation |
| Internal data | interface/type | Compile-time only is sufficient |
| Union discrimination needed | Discriminated Union | Exhaustive check |
| String literals | as const | Leverage type inference |

### Error Handling

| Situation | Choice | Rationale |
|---|---|---|
| Recoverable error | Result type | Explicit error handling |
| Unexpected error | throw | Catch at upper level |
| External input validation | Zod | Unified parsing and validation |

### Strictness

| Setting | Recommended | Rationale |
|---|---|---|
| strict | true | Basic type safety |
| noUncheckedIndexedAccess | true | Array access safety |
| exactOptionalPropertyTypes | Depends | Can be too strict |

### Testing

| Use Case | Choice | Rationale |
|---|---|---|
| Unit tests | Vitest | bun/Vite compatible, fast |
| Type tests | tsd or expect-type | Type correctness verification |

### Type Patterns

| Situation | Choice | Rationale |
|---|---|---|
| Extract common properties | Pick/Omit | Leverage existing types |
| Object transformation | Mapped Types | Flexible type transformation |
| Conditional types | Conditional Types | Context-dependent types |
| Branded types | Branded Types | Type-level distinction |

## Key Principles

1. bun + Biome の技術スタックを使用する
2. `strict: true` を基本とし、`noUncheckedIndexedAccess` で型安全性を強化する
3. 型推論を活用し、関数の引数と返り値のみ明示的に型を付ける
4. 型インポートは `import type` を使用する
5. エラーハンドリングには Result 型パターンを推奨する
6. 外部データのバリデーションには Zod を使用する
7. コードスタイルは Biome で統一する
8. シンプルな型戦略を優先し、過度な型パズルを避ける

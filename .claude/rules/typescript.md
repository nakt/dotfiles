# TypeScript Development Guide

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

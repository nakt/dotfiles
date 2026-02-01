---
name: typescript
description: >-
  bun + Biome を使った TypeScript 開発の支援スキル。
  プロジェクト固有の構成、型設計方針、コーディング規約のガイドラインを提供する。
  TypeScript プロジェクトの新規作成、tsconfig.json の設定、
  型設計パターン（Result 型、Zod バリデーション等）の確認、
  Biome 設定やプロジェクト構成の整備に使用する。
---

## Tech Stack

bun + Biome を標準とする。

## Quick Start

```bash
bun init
bun add -d @biomejs/biome
bun run biome init
```

## Common Commands

```bash
bun run src/index.ts           # 直接実行
bun build ./src/index.ts       # ビルド
bun run tsc --noEmit           # 型チェック
bun run biome check .          # Lint/フォーマットチェック
bun run biome check --write .  # 自動修正
bun run test                   # テスト実行
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

- 一時コメントには `TODO` / `FIXME` ラベルを使用
- 型推論を活用し、関数の引数と返り値のみ明示的に型を付ける
- 型インポートは `import type` を使用
- エラーハンドリングには Result 型パターンを推奨
- 外部データのバリデーションには Zod を使用
- コードスタイルは Biome で統一

## Decision Guide

### Type Strategy

| Situation | Choice | Rationale |
|---|---|---|
| API response | Zod + infer | Runtime validation and type generation |
| Internal data | interface/type | Compile-time only is sufficient |
| Union discrimination | Discriminated Union | Exhaustive check |
| String literals | as const | Leverage type inference |

### Error Handling

| Situation | Choice | Rationale |
|---|---|---|
| Recoverable error | Result type | Explicit error handling |
| Unexpected error | throw | Catch at upper level |
| External input | Zod | Unified parsing and validation |

## Key Principles

1. bun + Biome の技術スタックを使用する
2. `strict: true` + `noUncheckedIndexedAccess` で型安全性を強化
3. 型推論を活用し、関数の引数と返り値のみ明示的に型を付ける
4. 型インポートは `import type` を使用する
5. エラーハンドリングには Result 型パターンを推奨
6. 外部データのバリデーションには Zod を使用
7. シンプルな型戦略を優先し、過度な型パズルを避ける

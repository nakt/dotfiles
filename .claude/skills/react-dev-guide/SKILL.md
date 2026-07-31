---
name: react-dev-guide
description: bun + Vite + Biome を使った React 開発の支援スキル。プロジェクト固有の構成、コーディング規約、推奨ツールのガイドラインを提供する。React プロジェクトの新規作成、コンポーネント設計方針の確認、状態管理・スタイリング・テスト等の技術選定、Biome 設定やプロジェクト構成の整備に使用する。
allowed-tools: Write, Read, Glob, Edit, Bash(bun:*)
---

# React Development Guide

## Tech Stack

bun + Vite + Biome を標準とする。

## Quick Start

```bash
bun create vite my-app --template react-ts
bun install --cwd my-app
bun run --cwd my-app dev
```

以降の Common Commands は、生成したプロジェクトのルートで実行する前提で書いている。リポジトリルートから実行する場合は同様に `--cwd` を付ける。

## Common Commands

```bash
bun run dev                    # 開発サーバー起動
bun run build                  # プロダクションビルド
bun run biome check .          # Lint/フォーマットチェック
bun run biome check --write .  # 自動修正
bun run test                   # テスト実行
```

## Rules

パッケージを追加する操作（`bun add` の実行を含む）に着手する前に、必ず [../typescript-dev-guide/references/bun-workflow.md](../typescript-dev-guide/references/bun-workflow.md) を読む。禁止事項とサプライチェーン対策が定義されている。

### 型チェック

`cd` を含む複合コマンドは実行のたびに権限プロンプトを誘発し、シェルの作業ディレクトリも呼び出しをまたいで保持されない。React プロジェクトがリポジトリのサブディレクトリにある場合は、`cd` せずに `--cwd` か `--project` で対象を指定する。

```bash
# Good（React プロジェクトが apps/web/ にある場合）
bun run --cwd apps/web tsc --noEmit

# 依存がリポジトリルートに hoist されている場合は --project でもよい
bun run tsc --noEmit --project apps/web/tsconfig.json

# Bad
cd apps/web && bun run tsc --noEmit
```

## Recommended Dependencies

標準スタック（bun / Vite / Biome）に追加するもの。状態管理の選定は下の Decision Guide で扱う。

| カテゴリ | パッケージ | 用途 |
|---|---|---|
| フォーム | react-hook-form + zod | フォーム管理+バリデーション |
| スタイリング | tailwindcss | ユーティリティファースト |
| テスト | vitest + @testing-library/react | ユニット+コンポーネント |

## Project Structure

```text
src/
├── components/
│   ├── ui/          # 汎用UI (Button, Input)
│   └── features/    # 機能単位のコンポーネント
├── hooks/           # カスタムフック
├── lib/             # ユーティリティ
├── types/           # 型定義
└── App.tsx
```

## Coding Conventions

- 関数コンポーネントのみ使用（クラスコンポーネント不可）
- Props は `interface` で定義
- カスタムフックは `use` プレフィックスで命名
- コードスタイルは Biome で統一
- シンプルな選択を優先し、過度な最適化・設計を避ける

## Decision Guide

### State Management

| Scope | Choice | Rationale |
|---|---|---|
| Component local | `useState` | Simplest |
| Parent-child sharing | props drilling or Context | Explicit dependencies |
| Global (small scale) | `zustand` | Lightweight, simple API |
| Server state | `@tanstack/react-query` | Cache, revalidation |

### Framework Selection

| Requirements | Choice | Rationale |
|---|---|---|
| SPA, simple | Vite + React | Minimal setup, bun compatible |
| SSR, SEO needed | Next.js (App Router) | Proven (note bun compatibility) |
| Static site | Astro | Minimal JS |

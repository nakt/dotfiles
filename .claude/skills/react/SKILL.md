---
name: react
description: >-
  bun + Vite + Biome を使った React 開発の支援スキル。
  プロジェクト固有の構成、コーディング規約、推奨ツールのガイドラインを提供する。
  React プロジェクトの新規作成、コンポーネント設計方針の確認、
  状態管理・スタイリング・テスト等の技術選定、
  Biome 設定やプロジェクト構成の整備に使用する。
---

## Tech Stack

bun + Vite + Biome を標準とする。

## Quick Start

```bash
bun create vite my-app --template react-ts
cd my-app && bun install
bun run dev
```

## Common Commands

```bash
bun run dev                    # 開発サーバー起動
bun run build                  # プロダクションビルド
bun run biome check .          # Lint/フォーマットチェック
bun run biome check --write .  # 自動修正
bun run test                   # テスト実行
```

## Recommended Dependencies

| カテゴリ | パッケージ | 用途 |
|---|---|---|
| 状態管理 | zustand | グローバル状態 |
| サーバー状態 | @tanstack/react-query | キャッシュ・再検証 |
| フォーム | react-hook-form + zod | フォーム管理+バリデーション |
| スタイリング | tailwindcss | ユーティリティファースト |
| Lint/Format | @biomejs/biome | 統一ツール |
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

- 一時コメントには `TODO` / `FIXME` ラベルを使用
- 関数コンポーネントのみ使用（クラスコンポーネント不可）
- Props は `interface` で定義
- カスタムフックは `use` プレフィックスで命名
- コードスタイルは Biome で統一

## Decision Guide

### State Management

| Scope | Choice | Rationale |
|---|---|---|
| Component local | `useState` | Simplest |
| Parent-child sharing | props drilling or Context | Explicit dependencies |
| Global (small scale) | Zustand | Lightweight, simple API |
| Server state | TanStack Query | Cache, revalidation |

### Framework Selection

| Requirements | Choice | Rationale |
|---|---|---|
| SPA, simple | Vite + React | Minimal setup, bun compatible |
| SSR, SEO needed | Next.js (App Router) | Proven (note bun compatibility) |
| Static site | Astro | Minimal JS |

## Key Principles

1. bun + Vite + Biome の技術スタックを使用する
2. 関数コンポーネントのみ（クラスコンポーネント不可）
3. 状態管理は zustand、サーバー状態は TanStack Query
4. コードスタイルは Biome で統一する
5. シンプルな選択を優先し、過度な最適化・設計を避ける

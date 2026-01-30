# React Development Guide

bun + Vite + Biome を使った React 開発の支援スキル。プロジェクト構成、コーディング規約、推奨ツールのガイドラインを提供する。

## When to use

- React プロジェクトを新規作成するとき
- React コンポーネントの設計方針を確認したいとき
- 状態管理、スタイリング、テスト等の技術選定で判断基準が欲しいとき
- Biome の設定やプロジェクト構成を整えるとき
- React のコーディング規約を確認したいとき

## Instructions

### 役割

- React 開発のベストプラクティスに基づいたコード設計を支援する
- bun + Vite + Biome の技術スタックを前提とした開発ガイドを提供する
- 技術選定では Decision Guide の判断基準に基づいて推奨する

## Quick Start

bun + Vite でプロジェクトを開始する:

```bash
# 1. プロジェクト作成
bun create vite my-app --template react-ts

# 2. 依存インストール
cd my-app && bun install

# 3. 開発サーバー起動
bun run dev
```

## Common Commands

```bash
# 開発
bun run dev                    # 開発サーバー起動
bun run build                  # プロダクションビルド
bun run preview                # ビルドプレビュー

# 依存管理
bun add package-name           # パッケージ追加
bun add -d package-name        # 開発依存追加
bun remove package-name        # パッケージ削除

# フォーマット/Lint (Biome)
bun run biome check .          # チェック
bun run biome check --write .  # 自動修正

# テスト (Vitest)
bun run test                   # テスト実行
bun run test --watch           # ウォッチモード
bun run test --coverage        # カバレッジ
```

## Recommended Dependencies

```bash
# 状態管理
bun add zustand                # シンプルな状態管理
bun add @tanstack/react-query  # サーバー状態

# フォーム
bun add react-hook-form        # フォーム管理
bun add zod                    # バリデーション

# スタイリング
bun add -d tailwindcss postcss autoprefixer

# 開発ツール
bun add -d @biomejs/biome      # フォーマット/Lint
bun add -d vitest              # テスト
bun add -d @testing-library/react  # コンポーネントテスト
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

## Project Structure

```text
src/
├── components/      # UIコンポーネント
│   ├── ui/          # 汎用UI (Button, Input)
│   └── features/    # 機能単位のコンポーネント
├── hooks/           # カスタムフック
├── lib/             # ユーティリティ
├── types/           # 型定義
└── App.tsx          # ルートコンポーネント
```

## Coding Conventions

### Comment Labels

一時的なコメントには以下のラベルを使用:

- `TODO`: 後で実装する作業
- `FIXME`: 修正が必要な問題

```tsx
// TODO: ローディング状態を追加
function UserList() {
  // FIXME: 空配列の場合のハンドリング
  return <ul>{users.map(u => <li key={u.id}>{u.name}</li>)}</ul>
}
```

### Component Definition

関数コンポーネントを使用:

```tsx
interface Props {
  title: string
  onClick?: () => void
}

export function Button({ title, onClick }: Props) {
  return <button onClick={onClick}>{title}</button>
}
```

### Custom Hook

`use` プレフィックスを使用:

```tsx
export function useCounter(initial = 0) {
  const [count, setCount] = useState(initial)
  const increment = () => setCount(c => c + 1)
  return { count, increment }
}
```

## Decision Guide

### State Management

| Scope | Choice | Rationale |
|---|---|---|
| Component local | `useState` | Simplest |
| Parent-child sharing | props drilling or Context | Explicit dependencies |
| Global state (small scale) | Zustand | Lightweight, simple API |
| Server state | TanStack Query | Cache, revalidation |

### Component Pattern

| Situation | Choice | Rationale |
|---|---|---|
| Reusable UI | Presentational | Works with props only |
| Share state logic | Custom Hook | Logic separation |
| Conditional rendering | Early return | Readability |
| List rendering | Stable ID for key | Prevent unnecessary re-renders |

### Framework Selection

| Requirements | Choice | Rationale |
|---|---|---|
| SPA, simple | Vite + React | Minimal setup, bun compatible |
| SSR, SEO needed | Next.js (App Router) | Proven (note bun compatibility) |
| Static site | Astro | Minimal JS |

### Testing

| Use Case | Choice | Rationale |
|---|---|---|
| Unit tests | Vitest | bun/Vite compatible, fast |
| Component tests | Testing Library | User perspective |

### Styling

| Requirements | Choice | Rationale |
|---|---|---|
| Utility-first | Tailwind CSS | Fast prototyping |
| Component-scoped | CSS Modules | Scope isolation |
| Dynamic styles | Tailwind or Vanilla Extract | Practicality or type-safety |

### Performance Optimization

| Situation | Choice | Rationale |
|---|---|---|
| Expensive computation | `useMemo` | Prevent recalculation |
| Callback stabilization | `useCallback` | Reference stability (when needed) |
| Prevent re-renders | `React.memo` | Props comparison (when needed) |
| Faster initial load | lazy + Suspense | Code splitting |

## Key Principles

1. bun + Vite + Biome の技術スタックを使用する
2. 関数コンポーネントを使用する（クラスコンポーネントは使わない）
3. カスタムフックは `use` プレフィックスで命名する
4. コンポーネントの Props は `interface` で定義する
5. 状態管理は zustand、サーバー状態は TanStack Query を推奨する
6. コードスタイルは Biome で統一する
7. シンプルな選択を優先し、過度な最適化・過度な設計を避ける

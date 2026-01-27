# React Development Guide

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

```
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

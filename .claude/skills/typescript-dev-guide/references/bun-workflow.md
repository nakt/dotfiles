# bun のパッケージ運用

bun を使う TypeScript / React プロジェクトに共通するルール。typescript-dev-guide と react-dev-guide の両方がこのファイルを唯一の定義として参照する。

## パッケージ追加

- `bun add xxx` でパッケージを追加しない
- `package.json` を直接編集し、`bun install` で反映する

## サプライチェーン対策

- プロジェクトルートに `.npmrc` を作成し `min-release-age=7` を設定する

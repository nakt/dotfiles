# bun のパッケージ運用

bun を使う TypeScript / React プロジェクトに共通するルール。typescript-dev-guide と react-dev-guide の両方がこのファイルを唯一の定義として参照する。

## パッケージ追加

- `bun add xxx` でパッケージを追加しない
- `package.json` を直接編集し、`bun install` で反映する

`bun add` はバージョン解決とインストールを一括で実行するため、どのバージョンが入るかを実行後の diff でしか確認できない。`package.json` を直接編集すれば、追加するバージョンをレビュー可能な変更として明示でき、`bun install` を実行する前に内容を確認できる。

## サプライチェーン対策

- プロジェクトルートの `bunfig.toml` に cooldown を設定する

```toml
[install]
minimumReleaseAge = 604800  # 7 日（秒で指定する）
```

`minimumReleaseAge` は、公開から指定秒数未満のバージョンのインストールを拒否する設定。パッケージの乗っ取りや悪意あるバージョンの混入は公開直後に発覚し撤回されることが多いため、公開直後のバージョンを避けるだけでサプライチェーン攻撃の多くを回避できる。値は秒なので、日数のつもりで `7` と書くと 7 秒になる。型定義など待てない依存は `minimumReleaseAgeExcludes` に列挙して個別に除外する。

npm にも同趣旨の `.npmrc` の `min-release-age`（単位は日）があるが、bun はこのキーを読まない。bun を使うプロジェクトでは `bunfig.toml` 側に書く。

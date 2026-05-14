# コード健全性パターン

デッドコードとコメントアウトされた残骸を整理し、ノイズを減らす。重複の検出・統合は [dedupe.md](dedupe.md) を参照。

## 検出コマンド

```bash
uv run vulture . --min-confidence 80                       # 信頼度 80% 以上
uv run vulture . --min-confidence 80 --sort-by-size        # 大きい順
uv run vulture . --min-confidence 80 --exclude tests,.venv
```

詳細は [tools.md](tools.md) を参照。

## vulture 出力の読み方

```
src/billing.py:45: unused function 'calculate_tax' (80% confidence)
src/processors.py:123: unused class 'LegacyProcessor' (90% confidence)
src/config.py:12: unused variable 'debug_mode' (60% confidence)
```

信頼度の対応指針:

| 信頼度 | 判断 |
| --- | --- |
| 60-70% | 偽陽性の可能性が高い。動的呼び出し・メタクラス・型注釈用途を疑う |
| 80-89% | おそらく未使用。実際の呼び出し元を Grep で確認してから削除 |
| 90-100% | ほぼ確実に未使用。削除可 |

## 偽陽性のハンドリング

vulture が誤って未使用と判定するケース:

### 1. 動的呼び出し

```python
# getattr 経由で呼ばれている
def plugin_handler() -> None: ...

# 呼び出し例 (vulture からは見えない)
getattr(module, "plugin_handler")()
```

### 2. フレームワーク慣習

```python
# ORM フィールド、テストフィクスチャ、ルートハンドラ など
class User(models.Model):
    email = models.EmailField()        # Django ORM が参照

@pytest.fixture
def temp_dir(): ...                    # pytest が呼び出し

@app.route("/health")
def health(): ...                      # フレームワークが登録
```

### 3. 公開 API

```python
# ライブラリの外部公開関数。プロジェクト内では未使用に見える
def public_api(): ...
```

### 対応

- 公開 API は `__all__` に明記し、whitelist で除外
- フレームワーク慣習はディレクトリ単位で `--exclude` を当てる
- 動的呼び出しは設計を見直すか、最小限の whitelist にとどめる

whitelist は通常のモジュールとして書き、vulture に引数として渡す:

```python
# whitelist.py
public_api  # type: ignore  # External consumers
```

```bash
uv run vulture . whitelist.py --min-confidence 80
```

## 「使われていない＝本来使われるべきだった」ケース

定数、型定義、エラークラスなどは「使うべき場所で使われていない」可能性がある。削除する前に以下を確認する。

- 同名・類似名の文字列リテラルや magic value が他所にないか
- 同じ責務を持つ重複実装がないか
- リファクタリング途中で参照側だけ忘れられていないか

該当する場合は削除ではなく参照側の修正を選ぶ。

## Remove Dead Code

```python
# BEFORE: 2 年前に置き換えられた関数が残っている
def old_calculate_price(item: Item) -> float:
    return item.cost * 1.1

def deprecated_handler(data: dict) -> None:
    pass

def calculate_price(item: Item) -> float:
    return item.cost * (1 + item.tax_rate)

# AFTER
def calculate_price(item: Item) -> float:
    return item.cost * (1 + item.tax_rate)
```

git 履歴で過去実装は追えるので、コードから削除する。

## Remove Commented Code

コメントアウトされた旧コードはノイズになる。

```python
# BEFORE
def calculate_total(items: list[Item]) -> float:
    # total = 0
    # for item in items:
    #     total += item.price * item.quantity
    # return total
    return sum(item.total_price() for item in items)

# AFTER
def calculate_total(items: list[Item]) -> float:
    return sum(item.total_price() for item in items)
```

「あとで戻すかも」は git で復元できるため不要。

## Verification Checklist

- [ ] `uv run vulture . --min-confidence 80` が空、または偽陽性のみ
- [ ] コメントアウトされたコードブロックが残っていない
- [ ] 削除前にテストが通り、削除後もテストが通る
- [ ] カバレッジが下がっていない
- [ ] 必要なら whitelist.py を作って意図的な除外を明記

## 出典

[l-mb/python-refactoring-skills](https://github.com/l-mb/python-refactoring-skills) (MIT) の py-code-health からデッドコード部分のみ抽出して翻案。

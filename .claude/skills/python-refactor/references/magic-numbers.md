# マジックナンバー定数化パターン

コード中に散らばった数値・文字列リテラルを意味のある名前に変え、変更可能性と読みやすさを高める。

## 検出コマンド

```bash
# 2 桁以上の数値リテラル
grep -rnE '\b[0-9]{2,}\b' --include='*.py' .

# 短い文字列リテラル (キーやモード名の候補)
grep -rnE '"[a-zA-Z_]{2,20}"' --include='*.py' . \
    | grep -v 'docstring\|"""'

# ruff の magic value ルール
uv run ruff check . --select PLR2004
```

詳細は [tools.md](tools.md) を参照。

## 改善パターン

### 1. Extract to Constants

繰り返し登場するリテラルをモジュールトップの `Final` 定数にする。

```python
# BEFORE
def calculate_fee(amount: int) -> float:
    if amount < 100:
        return 2.50
    if amount < 1000:
        return 5.00
    return 10.00

# AFTER
from typing import Final

SMALL_AMOUNT_THRESHOLD: Final = 100
MEDIUM_AMOUNT_THRESHOLD: Final = 1000
SMALL_FEE: Final = 2.50
MEDIUM_FEE: Final = 5.00
LARGE_FEE: Final = 10.00

def calculate_fee(amount: int) -> float:
    if amount < SMALL_AMOUNT_THRESHOLD:
        return SMALL_FEE
    if amount < MEDIUM_AMOUNT_THRESHOLD:
        return MEDIUM_FEE
    return LARGE_FEE
```

### 2. Config クラス化

関連する定数群は `dataclass` にまとめると、グルーピングと型の表現力が上がる。

```python
# BEFORE: 関連する定数が散らばる
SMALL_AMOUNT_THRESHOLD: Final = 100
MEDIUM_AMOUNT_THRESHOLD: Final = 1000
SMALL_FEE: Final = 2.50
MEDIUM_FEE: Final = 5.00
LARGE_FEE: Final = 10.00
PREMIUM_DISCOUNT: Final = 0.5

# AFTER: グループ化
from dataclasses import dataclass
from typing import Final

@dataclass(frozen=True)
class FeeConfig:
    small_threshold: int = 100
    medium_threshold: int = 1000
    small_fee: float = 2.50
    medium_fee: float = 5.00
    large_fee: float = 10.00
    premium_discount: float = 0.5

FEE_CONFIG: Final = FeeConfig()

def calculate_fee(amount: int) -> float:
    if amount < FEE_CONFIG.small_threshold:
        return FEE_CONFIG.small_fee
    if amount < FEE_CONFIG.medium_threshold:
        return FEE_CONFIG.medium_fee
    return FEE_CONFIG.large_fee
```

### 3. 単位を名前に含める

数値の単位は名前で表現する。`30` と `30.0` が秒なのかミリ秒なのかメガバイトなのかを呼び出し側で迷わせない。

```python
# BEFORE
SESSION_TIMEOUT = 30                # 秒？ミリ秒？
BUFFER_SIZE = 1024                  # バイト？KB？

# AFTER
SESSION_TIMEOUT_SECONDS: Final = 30
BUFFER_SIZE_BYTES: Final = 1024
MAX_RETRY_DELAY_MS: Final = 5000
```

`timedelta` を使えるところは使う方が安全:

```python
from datetime import timedelta

SESSION_TIMEOUT: Final = timedelta(seconds=30)
```

### 4. pydantic-settings での環境変数オーバーライド

実行環境ごとに変えたい値は `pydantic-settings` の `BaseSettings` に集約し、環境変数で上書きできるようにする。

```python
# AFTER
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class AppSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="APP_", env_file=".env")

    session_timeout_seconds: int = Field(default=30, ge=1)
    buffer_size_bytes: int = Field(default=1024, ge=64)
    max_retry_delay_ms: int = Field(default=5000, ge=0)

settings = AppSettings()
```

`APP_SESSION_TIMEOUT_SECONDS=60` を環境変数で渡すだけで上書きされる。バリデーションが付いてくる利点もある。

### 5. テストでの定数置換

テストでは `monkeypatch.setattr` で定数を一時的に置き換える。`importlib.reload` を避けられる。

```python
# tests/test_fees.py
def test_small_fee_threshold(monkeypatch):
    from myapp import fees
    monkeypatch.setattr(fees.FEE_CONFIG, "small_threshold", 200)
    assert fees.calculate_fee(150) == fees.FEE_CONFIG.small_fee
```

`pydantic-settings` の場合はテスト用 fixture でインスタンスを差し替える:

```python
@pytest.fixture
def test_settings(monkeypatch):
    monkeypatch.setenv("APP_SESSION_TIMEOUT_SECONDS", "5")
    return AppSettings()
```

## 除外対象

すべての数値・文字列を定数化する必要はない。以下はそのままで読みやすい。

- `0`, `1`, `-1` (初期値・インクリメント・末尾アクセス)
- `2` (二乗、ペア)
- 自己説明的なリテラル (`if len(items) == 1:`、`return [0] * n`)
- テストの期待値 (`assert calculate(3, 4) == 12`)
- 文字列キーで「その場限り、1 箇所のみ」のもの

判断基準: 同じ値が 2 箇所以上に現れる、または値の意味が呼び出し側から読み取れない場合に定数化する。

## Verification Checklist

- [ ] `uv run ruff check . --select PLR2004` が空、または意図的な例外のみ
- [ ] 同じリテラルが複数箇所で重複していない
- [ ] 数値定数の単位が名前で明示されている
- [ ] 環境ごとに変える値は `pydantic-settings` でオーバーライド可能
- [ ] テストで定数置換が必要な箇所は fixture / monkeypatch で対応
- [ ] テストグリーンを維持

## 出典

[l-mb/python-refactoring-skills](https://github.com/l-mb/python-refactoring-skills) (MIT) の py-complexity「Extract Magic Numbers」を切り出して拡張し、`pydantic-settings` と単位命名を加えて翻案。

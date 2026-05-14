# 複雑性削減パターン

循環的・認知的複雑度を下げ、保守性指数を高めるためのリファクタリングパターン集。

## 計測コマンド要約

```bash
uv run radon cc . -n C -s           # cyclomatic ≥ 11 を表示
uv run radon mi . -n B              # 保守性指数 < 65
uv run lizard -C 15 -L 50 .         # 認知的複雑度・関数行数
uv run wily diff HEAD~1             # 直前コミットからの改善差分
```

詳細は [tools.md](tools.md) を参照。

## 改善パターン

### 1. Extract Function

長大な関数を意味のある小関数に分割する。各関数を単一責任に保つ。

```python
# BEFORE: cyclomatic 12、20 行超
def process_order(order: dict) -> bool:
    if not order.get("items"):
        return False
    if order["total"] < 0:
        return False
    # ... 支払い処理 ...
    # ... 在庫更新 ...
    # ... 通知送信 ...
    return True

# AFTER: 各関数 cyclomatic ≤ 3
def process_order(order: dict) -> bool:
    return is_valid_order(order) and process_payment(order) and finalize_order(order)
```

### 2. Guard Clauses

深いネストを早期 return で平坦化する。

```python
# BEFORE: ネスト 3 段
def get_user_status(user: User | None) -> str:
    if user:
        if user.is_active:
            if user.is_verified:
                return "ok"
    return "denied"

# AFTER: ガード節
def get_user_status(user: User | None) -> str:
    if user is None or not user.is_active or not user.is_verified:
        return "denied"
    return "ok"
```

### 3. Lookup Tables

`if/elif` の連鎖を辞書による参照に置き換える。

```python
# BEFORE: cyclomatic 7
def get_discount(tier: str, total: float) -> float:
    if tier == "gold" and total > 1000:
        return 0.20
    elif tier == "gold":
        return 0.15
    elif tier == "silver" and total > 1000:
        return 0.10
    elif tier == "silver":
        return 0.05
    return 0.0

# AFTER: cyclomatic 2
DISCOUNT_TABLE: dict[tuple[str, bool], float] = {
    ("gold", True): 0.20,
    ("gold", False): 0.15,
    ("silver", True): 0.10,
    ("silver", False): 0.05,
}

def get_discount(tier: str, total: float) -> float:
    return DISCOUNT_TABLE.get((tier, total > 1000), 0.0)
```

### 4. Repetitive Field Operations

同形の `if` を繰り返すコードは `getattr` / `setattr` のループで畳む。

```python
# BEFORE: 同じ if を 4 回繰り返す
def apply_secrets(config: EmailConfig, secrets: dict) -> None:
    if config.smtp_host:
        config.smtp_host = substitute(config.smtp_host, secrets)
    if config.smtp_user:
        config.smtp_user = substitute(config.smtp_user, secrets)
    if config.smtp_password:
        config.smtp_password = substitute(config.smtp_password, secrets)
    if config.smtp_from:
        config.smtp_from = substitute(config.smtp_from, secrets)

# AFTER: ループで畳む
SECRET_FIELDS = ("smtp_host", "smtp_user", "smtp_password", "smtp_from")

def apply_secrets(config: EmailConfig, secrets: dict) -> None:
    for field in SECRET_FIELDS:
        if value := getattr(config, field, None):
            setattr(config, field, substitute(value, secrets))
```

ただし型チェックは弱くなるので、フィールドが静的に決まる場合のみ使う。

### 5. Extract Complex Type Definitions

繰り返し登場する複雑な型注釈は `TypeAlias` として 1 箇所で定義する。

```python
# BEFORE: 同じ型が 8 箇所に散らばる
def load(cache_mode: Literal["use", "only", "refresh"] | None) -> Data: ...
def save(data: Data, cache_mode: Literal["use", "only", "refresh"] | None) -> None: ...

# AFTER: 名前を付けて再利用
type CacheMode = Literal["use", "only", "refresh"]
type CacheModeOption = CacheMode | None

def load(cache_mode: CacheModeOption) -> Data: ...
def save(data: Data, cache_mode: CacheModeOption) -> None: ...
```

配置先の目安: モジュール内利用なら同モジュール冒頭、プロジェクト横断なら `types.py`。

## Verification Checklist

- [ ] `uv run radon cc . -n C` で C 以上の関数が報告されない（または対処済み）
- [ ] `uv run lizard -C 15 .` で認知的複雑度の警告が出ない
- [ ] `uv run radon mi . -n B` で保守性指数 < 65 のモジュールがない
- [ ] 1 ファイル > 500 行は分割するか分割不可な理由を確認
- [ ] テストグリーンを維持
- [ ] `uv run wily diff HEAD~1` で改善方向を確認

## 出典

[l-mb/python-refactoring-skills](https://github.com/l-mb/python-refactoring-skills) (MIT) の py-complexity を Python 3.12+ に合わせて翻案。

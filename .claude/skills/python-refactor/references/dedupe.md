# 類似処理の共通化・正規化パターン

インクリメンタル開発で蓄積した「似ているが微妙に違う」コードを統合し、命名・シグネチャを揃えるためのパターン集。

## 類似コードの検出

```bash
# 重複コード検出 (デフォルト 4 行以上)
uv run pylint --disable=all --enable=duplicate-code --recursive=y .

# しきい値を 6 行に上げてノイズを減らす
uv run pylint --disable=all --enable=duplicate-code \
    --duplicate-code-min-lines=6 --recursive=y .
```

語幹で類似関数を探す:

```bash
grep -rnE 'def (process|handle|fetch|create|update|delete)_[a-z_]+' \
    --include='*.py' .
```

詳細は [tools.md](tools.md) を参照。

## 改善パターン

### 1. Parameterize Function

ほぼ同じ処理を型パラメータで 1 つに統合する。

```python
# BEFORE: 戻り値の型だけ違う関数が並ぶ
def process_user(data: dict) -> User:
    if not data.get("email"):
        raise ValueError("email required")
    if not data.get("name"):
        raise ValueError("name required")
    return User(email=data["email"], name=data["name"])

def process_admin(data: dict) -> Admin:
    if not data.get("email"):
        raise ValueError("email required")
    if not data.get("name"):
        raise ValueError("name required")
    return Admin(email=data["email"], name=data["name"])

# AFTER: TypeVar で統合 (PEP 695 構文)
def process_entity[T: (User, Admin)](data: dict, cls: type[T]) -> T:
    if not data.get("email"):
        raise ValueError("email required")
    if not data.get("name"):
        raise ValueError("name required")
    return cls(email=data["email"], name=data["name"])

user = process_entity(payload, User)
admin = process_entity(payload, Admin)
```

### 2. Extract Common Logic

複数関数で重複するバリデーションを切り出す。

```python
# BEFORE: バリデーションが create / update に重複
def create_user(email: str, age: int) -> User:
    if "@" not in email:
        raise ValueError("invalid email")
    if not 0 <= age <= 150:
        raise ValueError("invalid age")
    return User(email=email, age=age)

def update_user(user_id: int, email: str, age: int) -> User:
    if "@" not in email:
        raise ValueError("invalid email")
    if not 0 <= age <= 150:
        raise ValueError("invalid age")
    user = get_user(user_id)
    user.email = email
    user.age = age
    return user

# AFTER: バリデーションを抽出
def _validate_user_input(email: str, age: int) -> None:
    if "@" not in email:
        raise ValueError("invalid email")
    if not 0 <= age <= 150:
        raise ValueError("invalid age")

def create_user(email: str, age: int) -> User:
    _validate_user_input(email, age)
    return User(email=email, age=age)

def update_user(user_id: int, email: str, age: int) -> User:
    _validate_user_input(email, age)
    user = get_user(user_id)
    user.email = email
    user.age = age
    return user
```

### 3. Configuration Over Duplication

「ほぼ同じだが定数だけ違う」関数群は設定を引数化して 1 つに集約する。

```python
# BEFORE: パーサが 3 つ並ぶ
def process_csv(path: str) -> list[dict]:
    return parse_file(path, delimiter=",", encoding="utf-8", skip_header=True)

def process_tsv(path: str) -> list[dict]:
    return parse_file(path, delimiter="\t", encoding="utf-8", skip_header=True)

def process_psv(path: str) -> list[dict]:
    return parse_file(path, delimiter="|", encoding="utf-8", skip_header=True)

# AFTER: 設定駆動
from dataclasses import dataclass

@dataclass(frozen=True)
class FileFormat:
    delimiter: str
    encoding: str = "utf-8"
    skip_header: bool = True

FORMATS: dict[str, FileFormat] = {
    "csv": FileFormat(","),
    "tsv": FileFormat("\t"),
    "psv": FileFormat("|"),
}

def process_file(path: str, fmt: str) -> list[dict]:
    spec = FORMATS[fmt]
    return parse_file(path, delimiter=spec.delimiter,
                      encoding=spec.encoding, skip_header=spec.skip_header)
```

### 4. シグネチャ・命名統一

似た関数の引数順・名前・戻り値型を揃えると、呼び出し側のテンプレートが安定する。

- 動詞は同じ意味で同じ語を使う (例: 取得は `get_` か `fetch_` のどちらかに統一)
- 主キーの引数名は全関数で同じに (例: 常に `user_id: int`)
- 戻り値は同じ抽象度で揃える (例: `User | None` か例外送出かを統一)

```python
# BEFORE: 不揃い
def get_user(id: int) -> dict: ...
def fetch_user_by_id(user_id: int) -> User | None: ...
def find_user(uid: int) -> User: ...

# AFTER: get_<entity>(<entity>_id) -> <Entity> | None で統一
def get_user(user_id: int) -> User | None: ...
def get_order(order_id: int) -> Order | None: ...
```

### 5. 文字列分岐の Enum / Literal 化

文字列キーで分岐するコードは `StrEnum` または `Literal` に置き換えると、typo を型チェックで検出できる。

```python
# BEFORE: 文字列直書き
def select_strategy(mode: str) -> Strategy:
    if mode == "fast":
        return FastStrategy()
    if mode == "safe":
        return SafeStrategy()
    if mode == "balanced":
        return BalancedStrategy()
    raise ValueError(f"unknown mode: {mode}")

# AFTER: StrEnum + dispatch
from enum import StrEnum

class Mode(StrEnum):
    FAST = "fast"
    SAFE = "safe"
    BALANCED = "balanced"

STRATEGIES: dict[Mode, type[Strategy]] = {
    Mode.FAST: FastStrategy,
    Mode.SAFE: SafeStrategy,
    Mode.BALANCED: BalancedStrategy,
}

def select_strategy(mode: Mode) -> Strategy:
    return STRATEGIES[mode]()
```

少数の固定値で外部 API シグネチャを変えたくない場合は `Literal["fast", "safe", "balanced"]` を使う。

### 6. Template Method

「処理の骨格は同じ、一部の手順だけ違う」関数群は基底クラスにテンプレートを置く。

```python
# BEFORE: import → 加工 → 保存 の骨格が同じレポート生成関数が複数
def generate_sales_report(period: str) -> Report:
    raw = load_sales(period)
    cleaned = clean_rows(raw)
    metrics = compute_sales_metrics(cleaned)
    return save_report(metrics, kind="sales")

def generate_traffic_report(period: str) -> Report:
    raw = load_traffic(period)
    cleaned = clean_rows(raw)
    metrics = compute_traffic_metrics(cleaned)
    return save_report(metrics, kind="traffic")

# AFTER: 骨格を基底クラスに、差分だけサブクラスに
from abc import ABC, abstractmethod

class ReportBuilder(ABC):
    kind: str

    def build(self, period: str) -> Report:
        raw = self.load(period)
        cleaned = clean_rows(raw)
        metrics = self.compute_metrics(cleaned)
        return save_report(metrics, kind=self.kind)

    @abstractmethod
    def load(self, period: str) -> list[dict]: ...

    @abstractmethod
    def compute_metrics(self, rows: list[dict]) -> dict: ...

class SalesReport(ReportBuilder):
    kind = "sales"
    def load(self, period): return load_sales(period)
    def compute_metrics(self, rows): return compute_sales_metrics(rows)

class TrafficReport(ReportBuilder):
    kind = "traffic"
    def load(self, period): return load_traffic(period)
    def compute_metrics(self, rows): return compute_traffic_metrics(rows)
```

差分が 1, 2 個ならクラス化せず高階関数 (`build(load_fn, metrics_fn, kind)`) でも良い。

## 過抽象化への警戒

統合は便利だが行きすぎると逆に読みにくくなる。判断の目安:

- 3 回ルール: 同じパターンが 3 回出てから抽出する。2 回までは複製のままにしておく
- 統合後にパラメータが 5 個以上になる、もしくは `if kind == "..."` 分岐が新たに増えるなら、分離したままが正解
- ドメイン的に別概念なら統合しない (例: `User` と `Product` のバリデーションが似ていても無理に共通化しない)

## Verification Checklist

- [ ] `uv run pylint --disable=all --enable=duplicate-code --recursive=y .` で 6 行以上の重複が報告されない
- [ ] 命名・シグネチャが揃っている
- [ ] 文字列分岐が Enum / Literal で型付けされている
- [ ] テストグリーンを維持
- [ ] 統合の結果、可読性が上がったか目視で確認

## 出典

[l-mb/python-refactoring-skills](https://github.com/l-mb/python-refactoring-skills) (MIT) の py-code-health 重複統合部分を起点に、Enum 化・テンプレートメソッド・命名統一を加筆して翻案。

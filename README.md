# kyoshin-flake

[KyoshinEewViewer for ingen](https://github.com/ingen084/KyoshinEewViewerIngen) の Nix フレーク。
強震モニタ・緊急地震速報クライアントを NixOS / nix-darwin で使えるようにします。

## 使い方

### NixOS モジュール (flake.nix)

パッケージをインストールするだけ:

```nix
{
  inputs.kyoshin-flake.url = "github:<your-user>/kyoshin-flake";

  outputs = { nixpkgs, kyoshin-flake, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        kyoshin-flake.nixosModules.default
        {
          programs.kyoshin-eew-viewer.enable = true;
        }
      ];
    };
  };
}
```

### バックグラウンドサービスとして自動起動

`autoStart = true` を追加すると、グラフィカルセッション開始時に systemd ユーザーサービスとして自動起動します。
ウィンドウは表示されますが、手動で起動する必要がなくなります。

```nix
programs.kyoshin-eew-viewer = {
  enable    = true;
  autoStart = true;
};
```

サービスの操作:

```bash
# 状態確認
systemctl --user status kyoshin-eew-viewer

# 手動で起動 / 停止 / 再起動
systemctl --user start   kyoshin-eew-viewer
systemctl --user stop    kyoshin-eew-viewer
systemctl --user restart kyoshin-eew-viewer

# ログ確認
journalctl --user -u kyoshin-eew-viewer -f
```

> **仕組み**
> アプリ自体にヘッドレスモードはないため、`graphical-session.target` 配下の
> systemd ユーザーサービスとして起動します。X11 / Wayland のセッションに
> アタッチされ、セッション終了時に自動停止します。

### 単発で試す

```bash
nix run github:<your-user>/kyoshin-flake
```

### ローカルビルド

```bash
nix build .#kyoshin-eew-viewer
./result/bin/KyoshinEewViewer.Desktop
```

---

## バージョンアップ手順

アップストリームが新しいタグ (`X.Y.Z`) をリリースしたときの更新手順です。

### 1. `flake.nix` のバージョンとハッシュを更新

`flake.nix` の以下の 4 箇所を新バージョンに書き換えます。

```nix
version = "X.Y.Z";

src = pkgs.fetchFromGitHub {
  rev  = "X.Y.Z";
  hash = "";          # ← 空にして一度 nix build し、エラーに出たハッシュを貼る
  ...
};

dotnetFlags = [
  ...
  "-p:AssemblyVersion=X.Y.Z.0"   # ← バージョンに合わせる
];
```

ハッシュの取得:

```bash
# hash = "" のまま nix build を走らせると "got: sha256-..." が出る
nix build .#kyoshin-eew-viewer 2>&1 | grep "got:"
# → 表示されたハッシュを hash = "sha256-..." に貼る
```

> **なぜ `AssemblyVersion` を手動で指定するか**
> `common.props` が `<AssemblyVersion>$(Version).$(BuildNumber)</AssemblyVersion>` と定義しており、
> `BuildNumber` が未設定だと `0.Y.Z.0.0` (5 ピリオド区切り) になり .NET のビルドエラーになるため。

### 2. NuGet 依存関係ロックファイルを再生成

```bash
# fetch-deps スクリプトをビルド
nix build .#packages.x86_64-linux.kyoshin-eew-viewer.fetch-deps

# スクリプトを直接実行して deps.json を上書き生成
bash $(readlink result) ./deps.json
```

> `nix run .#packages.x86_64-linux.kyoshin-eew-viewer.fetch-deps` は使えません。
> fetch-deps の出力はディレクトリではなく単一スクリプトなので、`bash` で直接呼び出す必要があります。

### 3. ビルド確認

```bash
git add flake.nix deps.json
nix build .#kyoshin-eew-viewer
```

### 4. コミット

```bash
git commit -m "update to X.Y.Z"
```

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `path '.../deps.nix' does not exist` | `deps.json` が git に追加されていない | `git add deps.json` してから `nix build` |
| `hash mismatch` | `hash = ""` のまま | エラーの `got:` 行のハッシュを `flake.nix` に貼る |
| `version string '...' does not conform` | `AssemblyVersion` の `.0` が余分 | `dotnetFlags` の `-p:AssemblyVersion=X.Y.Z.0` を更新 |
| `binary ... does not exist` | 実行ファイル名が違う | `executables` と `mainProgram` を実際のファイル名に合わせる |

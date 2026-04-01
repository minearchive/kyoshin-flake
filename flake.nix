{
  description = "KyoshinEewViewer for ingen - 強震モニタ・緊急地震速報カスタムクライアント";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      nixosModule = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.kyoshin-eew-viewer;
        in
        {
          options.programs.kyoshin-eew-viewer = {
            enable = lib.mkEnableOption "KyoshinEewViewer for ingen (強震モニタクライアント)";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              defaultText = lib.literalExpression "kyoshin-eew-viewer";
              description = "使用するパッケージ。オーバーライド可能。";
            };

            autoStart = lib.mkEnableOption "グラフィカルセッション開始時に自動起動 (systemd ユーザーサービス)";
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];

            systemd.user.services.kyoshin-eew-viewer = lib.mkIf cfg.autoStart {
              description = "KyoshinEewViewer for ingen";
              after    = [ "graphical-session.target" ];
              wantedBy = [ "graphical-session.target" ];
              partOf   = [ "graphical-session.target" ];
              serviceConfig = {
                ExecStart = "${cfg.package}/bin/KyoshinEewViewer.Desktop --no-logo";
                Restart    = "on-failure";
                RestartSec = 5;
              };
            };
          };
        };

    in
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        avaloniaRuntimeDeps = with pkgs; [
          libx11
          libice
          libsm
          libxext
          libxrandr
          libxcursor
          libxi
          libxfixes
          wayland
          libxkbcommon
          mesa
          libGL
          fontconfig
          freetype
          gtk3
          libpulseaudio
        ];

        kyoshin-eew-viewer = pkgs.buildDotnetModule {
          pname = "kyoshin-eew-viewer";
          version = "0.20.27";

          src = pkgs.fetchFromGitHub {
            owner = "ingen084";
            repo = "KyoshinEewViewerIngen";
            rev = "0.20.26";
            hash = "sha256-asGLWxI2poeEx8nlEm6ju6kmMmAtD+Cstpab9k13o+I=";
            fetchSubmodules = true;
          };

          projectFile = "src/KyoshinEewViewer.Desktop/KyoshinEewViewer.Desktop.csproj";
          nugetDeps = ./deps.json;

          dotnet-sdk     = pkgs.dotnet-sdk_10;
          dotnet-runtime = pkgs.dotnet-runtime_10;

          dotnetFlags = [
            "-p:PublishReadyToRun=true"
            "-p:InvariantGlobalization=false"
            "-p:AssemblyVersion=0.20.27.0"
          ];

          executables = [ "KyoshinEewViewer.Desktop" ];
          runtimeDeps = avaloniaRuntimeDeps;

          meta = with pkgs.lib; {
            description = "強震モニタ・緊急地震速報のカスタムクライアント (KyoshinEewViewer for ingen)";
            longDescription = ''
              日本のリアルタイム地震監視アプリケーション。
              強震ネットワーク観測データや気象庁からの緊急地震速報・地震情報を統合し、
              包括的な地震監視を提供します。Avalonia UI ベース。
            '';
            homepage    = "https://github.com/ingen084/KyoshinEewViewerIngen";
            license     = licenses.mit;
            platforms   = platforms.linux;
            mainProgram = "KyoshinEewViewer.Desktop";
          };
        };

      in
      {
        packages = {
          default            = kyoshin-eew-viewer;
          kyoshin-eew-viewer = kyoshin-eew-viewer;
        };
      }
    )

    // {
      nixosModules = {
        default            = nixosModule;
        kyoshin-eew-viewer = nixosModule;
      };
    };
}

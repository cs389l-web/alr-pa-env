{
  description = "ALR programming assignments environment flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    dockerSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    forDockerSystems = f: nixpkgs.lib.genAttrs dockerSystems (system: f system);
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      javaEnv = with pkgs;
        mkShell {
          buildInputs = [jdk_headless maven];
          shellHook = ''
            export JAVA_HOME=${pkgs.jdk_headless}
          '';
        };
      dafnyEnv = with pkgs;
        mkShell {
          buildInputs = [dafny dotnet-sdk];
        };
    in {
      pa1 = javaEnv;
      pa2 = javaEnv;
      pa3 = dafnyEnv;
    });

    packages = forDockerSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      archMap = {
        "x86_64-linux" = "amd64";
        "aarch64-linux" = "arm64";
      };
      baseImageHashes = {
        "x86_64-linux" = "sha256-7skZqBy1GE4hjEH67XizzwhUzMvo4bJNvmD0v71pBgE=";
        "aarch64-linux" = "sha256-m2Gjt52Z5X1Aa2RFg42p6OPd90s/6AF/zSm0UYiU2YI=";
      };

      fromImage = pkgs.dockerTools.pullImage {
        imageName = "mcr.microsoft.com/devcontainers/base";
        imageDigest = "sha256:30b0a0c004ca94d36c323ee993361a7e0ae25ea255ea125201e8a9587501c324";
        finalImageName = "devcontainers/base";
        finalImageTag = "2.1.3-trixie";
        sha256 = baseImageHashes.${system};
        os = "linux";
        arch = archMap.${system};
      };
      tag = "25.11-trixie";
      runAsRoot = ''
        # https://github.com/NixOS/nixpkgs/issues/129007
        for f in /usr/bin/*; do /bin/ln -s $f /bin/$(/bin/basename $f) 2>/dev/null || true; done
        for f in /usr/lib/*; do /bin/ln -s $f /lib/$(/bin/basename $f) 2>/dev/null || true; done
      '';
      diskSize = 2048;
    in {
      alr-java = with pkgs;
        dockerTools.buildImage {
          name = "alr-java";
          inherit fromImage tag runAsRoot diskSize;

          copyToRoot = buildEnv {
            name = "image-root";
            paths = [jdk_headless maven];
            pathsToLink = ["/bin"];
          };

          config = {
            User = "vscode:vscode";
            Env = ["JAVA_HOME=${jdk_headless}"];
          };
        };

      alr-dafny = with pkgs;
        dockerTools.buildImage {
          name = "alr-dafny";
          inherit fromImage tag runAsRoot diskSize;

          copyToRoot = buildEnv {
            name = "image-root";
            paths = [dafny dotnet-sdk coreutils];
            pathsToLink = ["/bin"];
          };

          config = {
            User = "vscode:vscode";
          };
        };
    });
  };
}

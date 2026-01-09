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
        "x86_64-linux" = "sha256-ePkUyhDGAJTKBs1QNJQHs/NUD7IFA3xmhAVb9lRDQGw=";
        "aarch64-linux" = "sha256-3F8WSg/sRBqgy8mFOkJzPLsiH38BtHV8jTY/leljcqw=";
      };
      devcontainerBase = pkgs.dockerTools.pullImage {
        imageName = "mcr.microsoft.com/devcontainers/base";
        imageDigest = "sha256:03359a0274041de0ba5d4e667ef305678834799d2ffa2b0c49dd71356e33c7be";
        finalImageName = "devcontainers/base";
        finalImageTag = "1.0.2-alpine-3.21";
        sha256 = baseImageHashes.${system};
        os = "linux";
        arch = archMap.${system};
      };
    in {
      alr-java = with pkgs;
        dockerTools.buildImage {
          name = "alr-java";
          tag = "25.11";
          fromImage = devcontainerBase;

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
          tag = "25.11";
          fromImage = devcontainerBase;

          copyToRoot = buildEnv {
            name = "image-root";
            paths = [dafny dotnet-sdk];
            pathsToLink = ["/bin"];
          };

          config = {
            User = "vscode:vscode";
          };
        };
    });
  };
}

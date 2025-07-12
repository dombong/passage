{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = [ "x86_64-linux" ];
      perSystem = { pkgs, ... }:
        ############################ PACKAGES ############################
        let
          ocamlPackages = pkgs.ocaml-ng.ocamlPackages_5_3;
          libevent = pkgs.stdenv.mkDerivation {
            name = "libevent";
            version = "20250621.0";

            src = pkgs.fetchFromGitHub {
              owner = "ygrek";
              repo = "ocaml-libevent";
              rev = "d8c7417a015233b3a276341ed68010653606baf6";
              sha256 = "sha256-4F6PjUvV0+ef1rN17wyhYcnZAKvDxsYJ4P/NDEA6KWw=";
            };

            nativeBuildInputs = with ocamlPackages; [ findlib ocaml ];

            propagatedBuildInputs = [ pkgs.libevent.dev ];

            postPatch = ''
              substituteInPlace Makefile \
                --subst-var-by EVENT_LIBS "${pkgs.libevent.out}/lib" \
                --subst-var-by EVENT_CFLAGS "${pkgs.libevent.dev}/include"
            '';

            buildFlags = [ "depend" "all" "allopt" ];

            preInstall = ''
              mkdir -p $out/lib/ocaml/${ocamlPackages.ocaml.version}/site-lib/stublibs
            '';
          };
          extunix = ocamlPackages.buildDunePackage {
            pname = "extunix";
            version = "20250621.0";
            minimumOCamlVersion = "4.13";
            src = pkgs.fetchFromGitHub {
              owner = "dombong";
              repo = "extunix";
              rev = "5b426e7b912b1bcd6d0acf2d96ef0f94dd12edeb";
              sha256 = "sha256-C3jPXOdRD56NnDqzvmV7Lpxw5JhMOp/21N6qCofyzy0=";
            };
            nativeBuildInputs = with ocamlPackages; [ findlib ocaml ];

            buildInputs = with ocamlPackages; [
              ocaml
              findlib
              ppxlib
              dune-configurator
            ];
          };
          devkitBuildInputs = with ocamlPackages; [
            ocaml
            extlib
            camlzip
            ocaml_pcre
            ocurl
            trace
            lwt
            lwt_ppx
            stdlib-shims
            yojson
          ];
          devInputs = with ocamlPackages; [ ocaml-lsp ocamlformat utop ];
          buildShellInputs' = devkitBuildInputs ++ (with pkgs; [
            dune_3
            opam
            ocaml
            libevent
            extunix
            pcre.dev
            libz.dev
            libzip.dev
            pkg-config
            age
          ]) ++ (with ocamlPackages; [
            re2
            cmdliner
            fileutils
            fpath
            menhir
            menhirLib
            menhirSdk
            ppx_expect
            sedlex
          ]);
          devkit = ocamlPackages.buildDunePackage {
            pname = "devkit";
            version = "20250621.0";
            minimumOCamlVersion = "4.13";

            src = pkgs.fetchFromGitHub {
              owner = "ahrefs";
              repo = "devkit";
              rev = "26e6648e5dafcc54d65d7f5356e8617f5f351250";
              sha256 = "sha256-uAq2BGTqdXDv9xeJFeH1Rjjq8iT4YHrCgPUOlbJ1nL4=";
            };

            buildInputs = buildShellInputs';
          };
          passage = ocamlPackages.buildDunePackage {
            pname = "passage";
            version = "20250621.0";
            minimumOCamlVersion = "4.13";

            src = ./.;

            buildInputs = buildShellInputs' ++ [ devkit ];
            nativeBuildInputs = with ocamlPackages; [ menhirSdk menhir menhirLib ];
          };
          buildInputs = [ devkit ] ++ (with ocamlPackages; [
            ocaml
            re2
            ppx_deriving
            cmdliner
            base64
            findlib
            atdgen-runtime
          ]);
          depPackages = [ devkit extunix libevent ];
          buildShellInputs = buildShellInputs' ++ depPackages ++ devInputs
            ++ buildInputs;
        in {
          packages.default = passage;
          legacyPackages = depPackages ++ [ passage ];

          devShells.default = pkgs.mkShell {
            inputsFrom = [ passage ];
            nativeBuildInputs = buildShellInputs;
            buildInputs = buildShellInputs;
          };
        };
    };
}

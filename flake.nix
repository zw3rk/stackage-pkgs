{
  description = "A very basic flake";

  inputs = {
    haskell-nix = {
      type = "github";
      owner = "input-output-hk";
      repo = "haskell.nix";
      ref = "hkm/stackage-pkgs-fixes";
    };
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };


  outputs = { self, haskell-nix, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ] (system:
    let
      overlays = [ haskell-nix.overlay ];
      pkgs = import nixpkgs {
        inherit system overlays;
        inherit (haskell-nix) config;
      };
      packagesFor = pkg:
        let snapshot = pkgs.haskell-nix.snapshots."lts-18.10";
        in pkgs.lib.mapAttrs (packageName: p:
          let
            package = pkgs.haskell-nix.hackage-package { name = packageName; version = p.identifier.version; compiler-nix-name = "ghc8107"; };
          in pkgs.releaseTools.aggregate {
            name = packageName;
            meta.description = packageName;
            constituents = pkgs.lib.optional (package != null) (
              pkgs.lib.optional (package.components ? library)
                  package.components.library
              ++ builtins.attrValues
                (package.components.sublibs or {})
              ++ builtins.attrValues
                (package.components.exes or {})
              ++ builtins.attrValues
                (package.components.tests or {}));
           }) (pkgs.lib.filterAttrs (n: p: !(__elem n [ "buildPackages" "text" "ghcWithPackages" "shellFor" "makeConfigFiles" "ghcWithHoogle" "iserv-proxy" "remote-iserv" "iserv" "ghc" "base" "ghci" "libiserv" "rts" "ghc-heap" "ghc-prim" "ghc-boot" "hpc" "integer-gmp" "integer-simple" "deepseq" "array" "ghc-boot-th" "pretty" "template-haskell" "ghcjs-prim" "ghcjs-th" "cabal-install" ])) snapshot);
    in rec {
      packages = hydraJobs.native;
      hydraJobs = {
        native = packagesFor pkgs;
      } // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
        x86_64-mingw32 = packagesFor pkgs.pkgsCross.mingwW64;
        js-ghcjs = packagesFor pkgs.pkgsCross.ghcjs;
        x86_64-musl = packagesFor pkgs.pkgsCross.musl64;
        aarch64-musl = packagesFor pkgs.pkgsCross.aarch64-multiplatform-musl;
      };
    }) // {
      # hydraJobs = self.packages;
    };
}

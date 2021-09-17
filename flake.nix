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
      packagesForSnapshot = snapshot:
        builtins.mapAttrs (packageName: package: pkgs.releaseTools.aggregate {
          name = packageName;
          meta.description = packageName;
          constituents =
            if !(package != null && (package ? components))
            then []
            else (nixpkgs.lib.optional (package.components ? library)
                package.components.library
            ++ builtins.attrValues
              (package.components.sublibs)
            ++ builtins.attrValues
              (package.components.exes)
            ++ builtins.attrValues
              (package.components.tests));
          }) snapshot;
    in {
      packages = {
        native = packagesForSnapshot pkgs.haskell-nix.snapshots."lts-18.8";
      } // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
        x86_64-mingw32 = packagesForSnapshot pkgs.pkgsCross.mingwW64.haskell-nix.snapshots."lts-18.8";
        js-ghcjs = packagesForSnapshot pkgs.pkgsCross.ghcjs.haskell-nix.snapshots."lts-18.8";
        x86_64-musl = packagesForSnapshot pkgs.pkgsCross.musl64.haskell-nix.snapshots."lts-18.8";
        aarch64-musl = packagesForSnapshot pkgs.pkgsCross.aarch64-multiplatform-musl.haskell-nix.snapshots."lts-18.8";
      };
    }) // {
      hydraJobs = self.packages;
    };
}

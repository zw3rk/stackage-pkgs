{
  description = "A very basic flake";

  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };


  outputs = { self, haskell-nix, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [
      "x86_64-linux"
      # "aarch64-linux"
      # "x86_64-darwin"
      # "aarch64-darwin"
    ] (system:
    let
      overlays = [ haskell-nix.overlay ];
      pkgs = import nixpkgs { inherit system overlays; };
      packagesForSnapshot = prefix: snapshot:
        builtins.listToAttrs (
          nixpkgs.lib.concatMap (packageName:
            let package = snapshot.${packageName};
            in if !(package != null && (package ? components))
            then []
            else (nixpkgs.lib.optional (package.components ? library)
                { name = "${prefix}${packageName}:lib:${packageName}"; value = package.components.library; }
            ++ nixpkgs.lib.mapAttrsToList (n: v:
                { name = "${prefix}${packageName}:lib:${n}"; value = v; })
              (package.components.sublibs)
            ++ nixpkgs.lib.mapAttrsToList (n: v:
                { name = "${prefix}${packageName}:exe:${n}"; value = v; })
              (package.components.exes)
            ++ nixpkgs.lib.mapAttrsToList (n: v:
                { name = "${prefix}${packageName}:test:${n}"; value = v; })
              (package.components.tests))
          ) (nixpkgs.lib.attrNames snapshot));
    in {
      packages = packagesForSnapshot "" pkgs.haskell-nix.snapshots."lts-18.8"
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") (
            packagesForSnapshot "x86_64-mingw32-" pkgs.pkgsCross.mingwW64.haskell-nix.snapshots."lts-18.8"
         // packagesForSnapshot "js-ghcjs-" pkgs.pkgsCross.ghcjs.haskell-nix.snapshots."lts-18.8"
         // packagesForSnapshot "x86_64-musl-" pkgs.pkgsCross.musl64.haskell-nix.snapshots."lts-18.8"
         // packagesForSnapshot "aarch64-musl-" pkgs.pkgsCross.aarch64-multiplatform-musl.haskell-nix.snapshots."lts-18.8");
      hydraJobs = self.packages;
    });
}

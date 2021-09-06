{
  description = "A very basic flake";

  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
  };


  outputs = { self, haskell-nix, nixpkgs }:
    let pkgs = nixpkgs; in
    let packagesForSnapshot = prefix: snapshot:
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
      packages.x86_64-linux =  (packagesForSnapshot "" (import nixpkgs { system = "x86_64-linux"; overlays = [ haskell-nix.overlay ]; }).haskell-nix.snapshots."lts-18.8")
                            // (packagesForSnapshot "x86_64-mingw32-" (import nixpkgs { system = "x86_64-linux"; overlays = [ haskell-nix.overlay ]; crossSystem = pkgs.lib.systems.examples.mingwW64; }).haskell-nix.snapshots."lts-18.8")
                            # // (packagesForSnapshot "js-ghcjs-" (import nixpkgs { system = "x86_64-linux"; overlays = [ haskell-nix.overlay ]; crossSystem = pkgs.lib.systems.examples.ghcjs; }).haskell-nix.snapshots."lts-18.8")
                            # // (packagesForSnapshot "x86_64-musl-" (import nixpkgs { system = "x86_64-linux"; overlays = [ haskell-nix.overlay ]; crossSystem = pkgs.lib.systems.examples.musl64; }).haskell-nix.snapshots."lts-18.8")
                            # // (packagesForSnapshot "aarch64-musl-" (import nixpkgs { system = "x86_64-linux"; overlays = [ haskell-nix.overlay ]; crossSystem = pkgs.lib.systems.examples.aarch64-multiplatform-musl; }).haskell-nix.snapshots."lts-18.8")
                            ;
      packages.aarch64-linux =  packagesForSnapshot "" (import nixpkgs { system = "aarch64-linux"; overlays = [ haskell-nix.overlay ]; }).haskell-nix.snapshots."lts-18.8";
      packages.x86_64-darwin =  packagesForSnapshot "" (import nixpkgs { system = "x86_64-darwin"; overlays = [ haskell-nix.overlay ]; }).haskell-nix.snapshots."lts-18.8";
      packages.aarch64-darwin =  packagesForSnapshot "" (import nixpkgs { system = "aarch64-darwin"; overlays = [ haskell-nix.overlay ]; }).haskell-nix.snapshots."lts-18.8";

      hydraJobs = self.packages;
  };
}

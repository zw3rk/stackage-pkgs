{ selectFunction, libsOnly ? false }:
{ self, haskell-nix, nixpkgs, flake-utils }:
flake-utils.lib.eachSystem [
  "x86_64-linux"
  "aarch64-linux"
#  "x86_64-darwin"
#  "aarch64-darwin"
] (system:
let
  ifdLevel = 1;
  overlays = [ haskell-nix.overlay ];
  pkgs = import nixpkgs {
    inherit system overlays;
    inherit (haskell-nix) config;
  };
  packagesFor = pkgs:
    let snapshot = pkgs.haskell-nix.snapshots."lts-18.10";
        notPackages = [
          # Not packages (perhaps we should remove these form snapshots)
          "buildPackages"
          "ghcWithHoogle"
          "ghcWithPackages"
          "makeConfigFiles"
          "shellFor"
        ];
        ghcPackages = [
          "text"
          "iserv-proxy"
          "remote-iserv"
          "iserv"
          "ghc"
          "base"
          "ghci"
          "libiserv"
          "rts"
          "ghc-heap"
          "ghc-prim"
          "ghc-boot"
          "hpc"
          "integer-gmp"
          "integer-simple"
          "deepseq"
          "array"
          "ghc-boot-th"
          "pretty"
          "template-haskell"
          "ghcjs-prim"
          "ghcjs-th"
          "cabal-install"
          "binary"
        ];
        cabalProjectWithStackageConstraints = ''
          packages: .
          allow-newer: binary-parsers:criterion
          constraints:
            ${pkgs.lib.concatStringsSep ", " (pkgs.lib.mapAttrsToList (n: p: "${n} ==${p.identifier.version}")  (builtins.removeAttrs snapshot (notPackages ++ ghcPackages)))}
        '';
        # cabal configure sometimes fails if the tests depend on the package being tested
        # See https://github.com/haskell/cabal/issues/1575
        skipTestsForHackage = [
          "attoparsec"
          "colour"
        ];
    in pkgs.lib.mapAttrs (packageName: pStackage:
      let
        pHackage = args: pkgs.haskell-nix.hackage-project ({
          name = packageName;
          compiler-nix-name = "ghc8107";
        } // pkgs.lib.optionalAttrs (__elem packageName skipTestsForHackage) {
          configureArgs = "--disable-benchmarks --disable-tests";
        } // args // {
          cabalProject =
            # https://github.com/emilypi/Base16/issues/9
            if packageName == "base16" then ''
              packages: .
              constraints: base16-bytestring <1.0
            ''
            else if __elem packageName ["cryptohash-md5" "cryptohash-sha1" "cryptohash-sha256" "cryptohash-sha512"] then ''
              packages: .
              constraints: base16-bytestring <1.0
              allow-newer: cryptohash-md5:*, cryptohash-sha1:*, cryptohash-sha256:*, cryptohash-sha512:*
              package cryptohash-sha256
                benchmarks: false
            ''
            else args.cabalProject or ''
                packages: .
              '' + pkgs.lib.optionalString (packageName == "HsYAML") ''
                allow-newer: HsYAML:tasty, HsYAML:QuickCheck
              '' + pkgs.lib.optionalString (packageName == "asif") ''
                allow-newer: asif:doctest
              '' + pkgs.lib.optionalString (packageName == "buffer-builder") ''
                allow-newer: json-builder:base
              '' + pkgs.lib.optionalString (packageName == "binary-instances") ''
                allow-newer: binary-instances:tasty
              '';
        });
        hackageProject = pHackage {
          version = pStackage.identifier.version;
          cabalProject = cabalProjectWithStackageConstraints;
        };
        hackageProjectLatest = pHackage {};
        aggregatePackageOutputs = package:
          pkgs.releaseTools.aggregate {
            name = packageName;
            meta.description = packageName;
            constituents =
              pkgs.lib.optional (package.components ? library)
                (package.components.library)
              ++ pkgs.lib.optionals (!libsOnly) (
                builtins.attrValues
                  (package.components.sublibs or {})
                ++ builtins.attrValues
                  (package.components.exes or {})
                ++ builtins.attrValues
                  (package.components.tests or {})
              );
          };
      in selectFunction (pkgs.lib.optionalAttrs (!__elem packageName ghcPackages) ({
        plans =
          pkgs.releaseTools.aggregate {
            name = packageName + "-plans";
            meta.description = packageName + " plan-nix";
            constituents = [hackageProject.plan-nix hackageProjectLatest.plan-nix];
          };
      } // pkgs.lib.optionalAttrs (ifdLevel > 0) {
        stackage = aggregatePackageOutputs pStackage;
        hackage = aggregatePackageOutputs (hackageProject.getPackage packageName);
        hackageLatest = aggregatePackageOutputs (hackageProjectLatest.getPackage packageName);
      }))) (builtins.removeAttrs snapshot notPackages);
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
}

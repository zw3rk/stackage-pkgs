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

  outputs = args: import ../outputs.nix { selectFunction = (p: { inherit (p) hackage; }); libsOnly = true; } args;
}

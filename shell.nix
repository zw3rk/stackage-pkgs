{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-21.05.tar.gz") {} }:
pkgs.mkShell {
  name = "Nix-Flakes-Test-Shell";
  buildInputs = with pkgs; [ nixUnstable nixFlakes git ];
  shellHook = ''
    echo "Welcome to the Nix Flakes Test Shell!";
  '';
}

{ pkgs, ... }:
with pkgs;
{
  myPkgs = {
    lssecret = callPackage ./lssecret.nix { };
    onedriver = callPackage ./onedriver.nix { };
    weechat-matrix-rs = callPackage ./weechat-matrix-rs.nix { };
  };
}

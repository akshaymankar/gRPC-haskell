# To build this repository with `nix` you run:
#
#     $ nix-build release.nix -I ssh-config-file=/path/to/ssh/config
#
# ... where the `ssh-config-file` is an SSH configuration file with enough
# information to authenticate (i.e. an `IdentityFile` readable by the user that
# builds this expression, for example).
#
# If you update the `.cabal` file (such as changing dependencies or adding new
# library/executable/test/benchmark sections), then update the `default.nix`
# expression by running:
#
#     $ cabal2nix . > default.nix
#
# If you want to update a dependency like `proto3-wire` to the latest git
# revision, then run:
#
#     $ nix-prefetch-git https://github.com/awakenetworks/proto3-wire.git
#
# ... and modify the `rev` and `sha256` fields of the corresponding `fetchgit`
# expression below using the output of the `nix-prefetch-git` command.
#
# If you want to test a local `proto3-wire` repository, then replace the
# `fetchgit { ... }` expression with the relative path to the source repository
# such as:
#
#     let proto3-wire-src = ../proto3-wire;
#     in
#     ...

let
  config = {
    packageOverrides = pkgs: rec {
      grpc = pkgs.stdenv.mkDerivation rec {
        name    = "grpc-${version}";
        version = "0.15-${pkgs.lib.strings.substring 0 7 rev}";
        rev     = "03efbd34ce64615f58007eae667b375accc6c8e6";
        src = pkgs.fetchgit {
          inherit rev;
          url    = "https://github.com/grpc/grpc.git";
          sha256 = "1pac3jby5p5a6p6vpqc5whkgy36hnn2ph2jbckg3w73hrxrnwmdh";
        };
        preInstall  = "export prefix";
        buildInputs =
          (if pkgs.stdenv.isDarwin then [ pkgs.darwin.cctools ] else []) ++ [
          pkgs.autoconf
          pkgs.automake
          pkgs.libtool
          pkgs.which
          pkgs.zlib
          pkgs.openssl
        ];
      };

      haskellPackages = pkgs.haskell.packages.ghc7103.override {
        overrides = haskellPackagesNew: haskellPackagesOld: rec {
          proto3-wire =
            let proto3-wire-src = pkgs.fetchgit {
              url    = "https://github.com/awakenetworks/proto3-wire.git";
              rev    = "b5151914873b9ede230094e742953b5062566244";
              sha256 = "09vjza18gnh5mf9l8vg3ka1c7rqfbjwviyjwpvam07hf90r0yg5b";
            };
            in
            haskellPackagesNew.callPackage proto3-wire-src { };

          protobuf-wire =
            let protobuf-wire-src = pkgs.fetchgitPrivate {
              url    = "git@github.mv.awakenetworks.net:awakenetworks/protobuf-wire.git";
              rev    = "c766074e3e5da9bcca1e5a5fc069983d8fbc97b3";
              sha256 = "0mlpfzvnzfblq7a265q4b61xkn30ndvqp8qjshbrx7kvyjxjlvnn";
            };
            in
            haskellPackagesNew.callPackage protobuf-wire-src { };

          grpc-haskell-no-tests =
            haskellPackagesNew.callPackage ./default.nix { };

          grpc-haskell =
            haskellPackagesNew.callPackage (import ./default-tests.nix {
              inherit grpc-haskell-no-tests;
              inherit (pkgs) ghc python;
            }) { };

          sorted-list = haskellPackagesNew.callPackage
            ({ mkDerivation, base, deepseq }:
             mkDerivation {
               pname = "sorted-list";
               version = "0.2.0.0";
               sha256 = "cc52c787b056f4d3a9ecc59f06701695602558a4233042ff8f613cdd4985d138";
               libraryHaskellDepends = [ base deepseq ];
               homepage = "https://github.com/Daniel-Diaz/sorted-list/blob/master/README.md";
               description = "Type-enforced sorted lists and related functions";
               license = pkgs.stdenv.lib.licenses.bsd3;
             }) {};
        };
      };
    };

    allowUnfree = true;
  };

in
{ pkgs ? import <nixpkgs> { inherit config; } }:
# Disable tests for now, since they don't pass yet
{ grpc-haskell = pkgs.haskell.lib.dontCheck pkgs.haskellPackages.grpc-haskell;
}
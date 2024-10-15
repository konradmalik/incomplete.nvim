{
  description = "incomplete.nvim";

  nixConfig = {
    extra-substituters = "https://neorocks.cachix.org";
    extra-trusted-public-keys = "neorocks.cachix.org-1:WqMESxmVTOJX7qoBC54TwrMMoVI1xAM+7yFin8NRfwk=";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    neorocks.url = "github:nvim-neorocks/neorocks";
    gen-luarc = {
      url = "github:mrcjkb/nix-gen-luarc-json";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-parts,
      neorocks,
      gen-luarc,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              neorocks.overlays.default
              gen-luarc.overlays.default
            ];
          };
        in
        {
          packages =
            let
              fs = pkgs.lib.fileset;
              sourceFiles = fs.unions [
                ./lua
              ];
              incomplete-nvim = pkgs.vimUtils.buildVimPlugin {
                src = fs.toSource {
                  root = ./.;
                  fileset = sourceFiles;
                };
                pname = "incomplete-nvim";
                version = "latest";
                nvimRequireCheck = "incomplete";
              };
            in
            {
              inherit incomplete-nvim;
              default = incomplete-nvim;
            };
          devShells.default = pkgs.mkShell {
            shellHook =
              let
                luarc = pkgs.mk-luarc-json { };
              in
              # bash
              ''
                ln -fs ${luarc} .luarc.json
              '';
            packages = with pkgs; [
              gnumake
              busted-nlua
              luajitPackages.luacheck
              stylua
            ];
          };
          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}

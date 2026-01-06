{
  description = "incomplete.nvim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    gen-luarc = {
      url = "github:mrcjkb/nix-gen-luarc-json";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      gen-luarc,
      ...
    }:
    let
      nixpkgsFor =
        system:
        (import nixpkgs {
          inherit system;
          overlays = [
            gen-luarc.overlays.default
          ];
        });

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function (nixpkgsFor system));
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          fs = pkgs.lib.fileset;
          sourceFiles = fs.unions [
            ./lua
            ./plugin
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
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
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
            luajitPackages.busted
            luajitPackages.luacheck
            luajitPackages.nlua
            stylua
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}

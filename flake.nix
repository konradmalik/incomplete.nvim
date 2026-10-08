{
  description = "incomplete.nvim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    gen-luarc = {
      url = "github:mrcjkb/nix-gen-luarc-json";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      gen-luarc,
      treefmt-nix,
      ...
    }:
    let
      nixpkgsFor = system: nixpkgs.legacyPackages.${system}.extend gen-luarc.overlays.default;

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ] (system: function (nixpkgsFor system));

      treefmtFor = pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
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

      devShells = forAllSystems (
        pkgs:
        let
          treefmt = (treefmtFor pkgs).config.build;
        in
        {
          default = pkgs.mkShellNoCC {
            shellHook =
              let
                luarc = pkgs.mk-luarc-json { };
              in
              # bash
              ''
                ln -fs ${luarc} .luarc.json
              '';
            packages = [
              treefmt.wrapper
            ]
            ++ builtins.attrValues treefmt.programs
            ++ (with pkgs; [
              luajitPackages.busted
              luajitPackages.luacheck
              luajitPackages.nlua
            ]);
          };
        }
      );

      checks = forAllSystems (
        pkgs:
        let
          # runs the script in a writable copy of the repo
          mkCheck =
            name: packages: script:
            pkgs.runCommandLocal name { nativeBuildInputs = packages; } ''
              export HOME=$TMPDIR
              cp -r ${self} src && chmod -R u+w src && cd src
              patchShebangs .
              ${script}
              touch $out
            '';
        in
        {
          formatting = (treefmtFor pkgs).config.build.check self;

          lint-lua = mkCheck "lint-lua" [
            pkgs.luajitPackages.luacheck
          ] "luacheck --codes --no-cache lua spec";

          tests = mkCheck "tests" (with pkgs.luajitPackages; [
            busted
            nlua
          ]) "busted --lua=nlua";
        }
      );

      formatter = forAllSystems (pkgs: (treefmtFor pkgs).config.build.wrapper);
    };
}

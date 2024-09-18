{
  description = "incomplete.nvim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "incomplete-shell";

          packages = with pkgs; [
            stylua
            lua.pkgs.luacheck
          ];

        };
      });
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };

}

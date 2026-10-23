{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    stylua.enable = true;
    prettier = {
      enable = true;
      includes = [
        "*.json"
        "*.md"
        "*.yaml"
        "*.yml"
      ];
      # intentionally invalid fixture
      excludes = [ "test/edge/malformed.json" ];
    };
    shfmt = {
      enable = true;
      useEditorConfig = true;
      includes = [ "*.sh" ];
    };
    shellcheck = {
      enable = true;
      includes = [ "*.sh" ];
    };
  };
}

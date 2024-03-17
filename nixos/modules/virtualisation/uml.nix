# Enable user-mode linux virtualisation

{ config, lib, ... }: {
  options = {
    virtualisation = {
      uml = {
        enable = lib.mkEnableOption (lib.mdDoc "user-mode linux");
      };
    };
  };
  config = {
    boot.kernelPatches = lib.mkIf config.virtualisation.uml.enable [
      {
        name = "UML target";
        patch = null;
        features = {
          uml = true;
        };
      }
    ];
  };
}
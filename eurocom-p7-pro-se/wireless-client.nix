{ config, lib, ... }:
  let
    cfg = config.networking.wirelessModeClient;
    wirelessClient = {
      networking = {
        networkmanager = {
          enable = true;
          useDnsmasq = true;
          insertNameservers = import ./nameservers.nix;
        };
      };
    };
  in
    with lib; {
      options = {
        networking.wirelessModeClient = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
        };
      };
      config = mkIf cfg.enable wirelessClient;
    }


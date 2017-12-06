{ config, lib, ... }:
  let
    cfg = config.networking.wirelessMode;
    wirelessClient = {
      networking = {
        networkmanager = {
          enable = true;
          useDnsmasq = true;
          insertNameservers = import ./nameservers.nix;
        };
      };
    };
    wirelessHost = {
      networking = {
        interfaces = {
          wlp6s0 = {
            ipAddress = "10.0.0.1";
            prefixLength = 24;
            ipv6Address = "fd99:cbc4:692::1";
            ipv6PrefixLength = 64;
          };
        };
        nat = {
          enable = true;
          externalInterface = "enp7s0";
          internalInterfaces = [ "wlp6s0" ];
          forwardPorts = [];
        };
        networkmanager = {
          enable = true;
          unmanaged = [ "wlp6s0" ];
        };
      };
      services = {
        hostapd = {
          enable = true;
          interface = "wlp6s0";
          hwMode = "g";
          channel = 1;
          wpa = false;
          ssid = (builtins.readFile ./secrets/ap_ssid);
          extraConfig = ''
            auth_algs=1
            wpa=2
            wpa_key_mgmt=WPA-PSK
            wpa_passphrase=${builtins.readFile ./secrets/ap_pass}
            wpa_pairwise=CCMP TKIP
            rsn_pairwise=CCMP
            ieee80211n=1
            wmm_enabled=1
            country_code=AU
            ieee80211d=1
            ht_capab=[HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]
          '';
        };
        dnsmasq = {
          enable = true;
          extraConfig = ''
            dhcp-authoritative
            interface=wlp6s0
            bind-interfaces
            dhcp-range=10.0.0.2,10.0.0.254
            dhcp-range=fd99:cbc4:692::,ra-stateless
            address=/localhost/127.0.0.1
            address=/localhost/::1
          '';
          resolveLocalQueries = true;
          servers = import ./nameservers.nix;
        };
      };
    };
  in
    with lib; {
      options = {
        networking.wirelessMode = mkOption {
          type = types.enum [ "client" "host" ];
          default = "client";
        };
      };
      config =
        if (cfg.networking.wirelessMode == "client") then
          wirelessClient
        else if (cfg.networking.wirelessMode == "host") 
          wirelessHost
        else then 
          wirelessClient;
    }


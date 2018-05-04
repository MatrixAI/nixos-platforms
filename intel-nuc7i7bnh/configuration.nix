{ config, lib, pkgs, ... }:

let
  esp = {
  mountPath = "/boot";
};
in
{

  imports = [
    ./wireless-client.nix
  ];

  fileSystems = {
    "/" = {
      device = "rpool";
      fsType = "zfs";
    };
    "/tmp" = {
      device = "rpool/tmp";
      fsType = "zfs";
    };
    "/boot" = {
      device = "/dev/disk/by-id/ata-WDC_WDS250G1B0B-00AS40_171812420165-part1";
      fsType = "vfat";
      options = [ "umask=0022" ];
    };
  };

  swapDevices = [];

  # CPU microcode
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.u2f.enable = true;

  # Video codec acceleration
  # https://wiki.archlinux.org/index.php/Hardware_video_acceleration
  hardware.opengl.driSupport = true;
  hardware.opengl.extraPackages = [ pkgs.vaapiIntel ];

  # Audio
  sound.enable = true;
  sound.mediaKeys.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = esp.mountPath;

  # Kernel command line parameters on boot
  # Make ZFS ignore the hostId and force import
  boot.kernelParams = [ "zfs_force=1" ];

  # Autoload kernel modules by scanning hardware
  boot.hardwareScan = true;

  # Sets the linux kernel version
  boot.kernelPackages = pkgs.linuxPackages_4_15;

  # Kernel modules available for loading for stage 1 boot
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci"  "usb_storage" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];

  # Kernel modules that must be loaded for stage 1 boot
  boot.initrd.kernelModules = [];

  # ZFS for stage 1 boot
  boot.initrd.supportedFilesystems = [ "zfs" ];

  boot.kernelModules = [ "kvm-intel" "coretemp" ];

  boot.supportedFilesystems = [ "zfs" ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 1;
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 100;
  };

  # Clean the temporary directory on reboot
  boot.cleanTmpDir = true;

  boot.runSize = "50%"; # refers to /run (runtime files, could use some memory)
  boot.devShmSize = "50%"; # refers to /dev/shm (shared memory, useless if no applications use shared memory)
  boot.devSize = "5%"; # refers to /dev (this shouldn't much at all)

  networking = {
    hostName = "matrix-sidekick";
    hostId = builtins.readFile ./secrets/hostid;
    enableIPv6 = true;
    useNetworkd = false;
    firewall = {
      enable = true;
      allowPing = true;
      pingLimit = "--limit 3/second --limit-burst 5";
      allowedTCPPorts = [
        22    # ssh
        55555 # five 5s for custom TCP
      ];
      allowedUDPPorts = [
        53 # dnsmasq dns
        67 # dnsmasq dhcp
        22 # ssh
        55555 # five 5s for custom UDP
      ];
      rejectPackets = false;
      logRefusedConnections = true;
      logRefusedPackets = false;
      logRefusedUnicastsOnly = false;
    };
    wirelessModeClient.enable = true;
  };

  i18n = {
    consoleKeyMap = "us";
    defaultLocale = "en_AU.UTF-8";
  };

  time.timeZone = "Australia/Sydney";

  fonts = {
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      corefonts # microsoft fonts
    ];
  };

  nix.nixPath = [
    "nixpkgs=/nix/nixpkgs"
    "nixos-config=/etc/nixos/intel-nuc7i7bnh/configuration.nix"
  ];
  nix.maxJobs = 4;
  nix.buildCores = 0;
  nix.useSandbox =  true;
  nix.readOnlyStore = true;
  nix.extraOptions = ''
    auto-optimise-store = true
    fsync-metadata = true
  '';

  # packages required for system functionality
  # all other packages should be part of the user profile
  environment.systemPackages = with pkgs; [
    coreutils       # basic shell utilities
    gnused          # sed
    gnugrep         # grep
    gawk            # awk
    ncurses         # tput (terminal control)
    iw              # wireless configuration
    iproute         # ip, tc
    nettools        # hostname, ifconfig
    dmidecode       # dmidecode
    lshw            # lshw
    pciutils        # lspci, setpci
    usbutils        # lsusb
    bluez-tools     # bluetooth tools
    utillinux       # linux system utilities
    cryptsetup      # luks
    mtools          # disk labelling
    smartmontools   # disk monitoring
    lm_sensors      # fan monitoring
    xorg.xbacklight # monitor brightness
    procps          # ps, top, pidof, vmstat, slabtop, skill, w
    psmisc          # fuser, killall, pstree, peekfd
    shadow          # passwd, su
    mkpasswd        # mkpasswd
    efibootmgr      # efi management
    openssh         # ssh
    gnupg           # encryption/decryption/signing
    hdparm          # disk info
    git             # needed for content addressed nixpkgs
  ];

  nixpkgs.config.allowUnfree = true;

  # use gnupg (for ssh agent as well)
  programs.gnupg.agent.enable = true;
  programs.gnupg.agent.enableSSHSupport = true;

  # Enable ZSH as a shell
  programs.zsh.enable = true;

  # Only load motd.sh during an interactive shell
  # Only execute matrix-motd when its both an interactive and login shell
  programs.zsh.interactiveShellInit = ''
    if [ -n "$PS1" ]; then
      . /etc/nixos/eurocom-p7-pro-se/motd.sh
      [[ -o login ]] && matrix-motd
    fi
  '';

  # Android development
  programs.adb.enable = true;

  # Scanning
  hardware.sane.enable = true;

  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };
    mingetty.greetingLine = ''[[[ \l @ \n (\s \r \m) ]]]''; # getty message
    gpm.enable = true;
    avahi.enable = true;
    kmscon.enable = true;
    kmscon.hwRender = true;
    dbus.enable = true;
    haveged.enable = true;
    locate.enable = true;
    upower.enable = true;
    cron.enable = false;
    openssh = {
      enable = true;
      startWhenNeeded = true;
      permitRootLogin = "no";
      passwordAuthentication = false;
      ports = [ 22 ];
      extraConfig = ''
        PrintLastLog no
      '';
    };
    xserver = {
      enable = true;
      autorun = true;
      exportConfiguration = true;
      videoDrivers = [ "intel" ];
      displayManager = {
        sddm.enable = true;
        hiddenUsers = [ "root" "nobody" ]; # cannot login to root
      };
      desktopManager = {
        xterm.enable = false;
        plasma5.enable = true;
      };
      windowManager = {
        xmonad.enable = true;
        xmonad.enableContribAndExtras = true;
        xmonad.extraPackages = haskellPackages: [];
      };
    };
  };

  users = {
    defaultUserShell = "/run/current-system/sw/bin/zsh";
    enforceIdUniqueness = true;
    mutableUsers = false;
    groups = [
      {
        name = "operators";
        gid = 1000;
      }
    ];
    users = {
      "cmcdragonkai" = {
        uid = 1000;
        description = "CMCDragonkai";
        group = "operators";
        extraGroups = [
          "wheel"
          "users"
          "networkmanager"
          "scanner"
          "lp"
          "docker"
          "adbusers"
          "plugdev"
        ];
        home = "/home/cmcdragonkai";
        createHome = true;
        useDefaultShell = true;
        hashedPassword = builtins.readFile ./secrets/cmcdragonkai_password_hash;
        openssh.authorizedKeys.keyFiles = [ ./cmcdragonkai.pub ];
      };
      "oliver" = {
        uid = 1001;
        description = "Oliver";
        group = "operators";
        extraGroups = [
          "users"
          "networkmanager"
          "scanner"
          "lp"
          "docker"
          "adbusers"
          "plugdev"
        ];
        home = "/home/oliver";
        createHome = true;
        useDefaultShell = true;
        hashedPassword = builtins.readFile ./secrets/oliver_password_hash;
      };
      "vivian" = {
        uid = 1002;
        description = "Vivian";
        group = "operators";
        extraGroups = [
          "users"
          "networkmanager"
          "scanner"
          "lp"
          "docker"
          "adbusers"
          "plugdev"
        ];
        home = "/home/vivian";
        createHome = true;
        useDefaultShell = true;
        hashedPassword = builtins.readFile ./secrets/vivian_password_hash;
      };
    };
  };

  security.sudo.wheelNeedsPassword = true;
  security.polkit.enable = true;

  virtualisation.docker.enable = true;

  # activationScripts and postBootCommands run just before
  # systemd is started, but after stage 1 has mounted the root filesystem
  # an adequate way to test if you're running at boot or not, is to test
  # the presence of systemd using pidof

  boot.postBootCommands = ''
    echo "Running Post-Boot Commands"
  '';

  environment.etc."os-release".text = lib.mkForce ''
    NAME="Matrix Sidekick"
    ID="matrix-sidekick"
    HOME_URL="https://matrix.ai/"
  '';

}

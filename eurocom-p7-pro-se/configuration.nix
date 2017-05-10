# This system configuration is designed for 2015 Eurocom P7 Pro SE
# We are expecting a E3 Xeon, Nvidia 965M, 2 M.2 SSDs and 2 HDDs, 32 GiB Non-ECC RAM

# Defines a configuration function that takes any attribute set, as long as it has config and pkgs, it ignores the rest
{ config, lib, pkgs, ... }:

let 
    # need to convert all the other configuration to deal with storageGeometry layout
    storageGeometry = import ./storageGeometry.nix;
    esp = {
        mountPath = "/boot";
        checksumPath = "/var/tmp/espsum";
        efiLabelPrefix = "Matrix EFI";
    };
in 
    {

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
                device = "/dev/disk/by-id/ata-PLEXTOR_PX-G128M6e_P02445180196-part1";
                fsType = "vfat";
                options = [ "umask=0022" ];
            };
        };

        swapDevices = [];

        # Enable all firmware
        # Max compatibility! 
        hardware.enableAllFirmware = true;

	# CPU microcode
        hardware.cpu.intel.updateMicrocode = true;

        # Bluetooth
        hardware.bluetooth.enable = true;

        # Video codec acceleration
        # https://wiki.archlinux.org/index.php/Hardware_video_acceleration
 	hardware.opengl.driSupport = true;
        hardware.opengl.driSupport32Bit = true;
	hardware.opengl.extraPackages = [ pkgs.vaapiVdpau ];

        # Audio
        sound.enable = true;
  	sound.mediaKeys.enable = true;
        hardware.pulseaudio.enable = true;
        hardware.pulseaudio.support32Bit = true;
        hardware.pulseaudio.package = pkgs.pulseaudioFull;

        # Bootloader
        boot.loader.systemd-boot.enable = true;
        boot.loader.timeout = null; # menu can be shown if space key is pressed at boot
        boot.loader.efi.canTouchEfiVariables = false;
        boot.loader.efi.efiSysMountPoint = esp.mountPath;

        # Kernel command line parameters on boot
        # Make ZFS ignore the hostId and force import
        boot.kernelParams = [ "zfs_force=1" ];

        # Autoload kernel modules by scanning hardware
        boot.hardwareScan = true;

        # Sets the linux kernel version
        boot.kernelPackages = pkgs.linuxPackages_4_9;

        # Kernel modules available for loading for stage 1 boot
        boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" ];

        # Kernel modules that must be loaded for stage 1 boot
        # Loop is needed in order to decrypt a raw file /luks_key.img as a block device
        boot.initrd.kernelModules = [ "loop" ];

	# ZFS for stage 1 boot
        boot.initrd.supportedFilesystems = [ "zfs" ];

        # Encrypted LUKS key will be stored as a gzipped cpio archive image
        # This allows us to use single password unlock
        boot.initrd.prepend = [ "${./secrets/luks_key.img.cpio.gz}" ];

        # make sure to decrypt our luks-key.img virtual block device first
        boot.initrd.luks.devices = 
            [
                {
                    device = "/luks-key.img";
                    name = "luks-key-encrypted";
                    keyFile = null;
                    allowDiscards = false;
                }
            ] ++ (
                storageGeometry.methods.extractStorageDevices 
                    (block: block.luksEncrypted) 
                    (block: {
                        device = block.path;
                        name = block.luksName;
                        keyFile = block.luksKeyFile;
                        allowDiscards = block.rotational;
                    }) 
                    storageGeometry.disks
            );

	# Network for stage 1 boot
	# Only supports ethernet, not WiFi
	# Allows SSH in stage 1
	boot.initrd.network = {
            enable = true;
            ssh = {
                enable = true;
                hostRSAKey = ./secrets/host.key;
                authorizedKeys = [ (builtins.readFile ./identity.pub) ];
                port = 22;
                shell = "/bin/ash";
            };
	};

        boot.initrd.preDeviceCommands = ''
           echo "Running Pre-Device Commands"
        '';

        # close the luks-key loopback device after decrypting all other drives
        boot.initrd.postDeviceCommands = ''
            echo "Running Post-Device Commands"
            ${pkgs.cryptsetup}/bin/cryptsetup luksClose luks-key-encrypted
        '';

        boot.initrd.postMountCommands = '' 
            echo "Running Post-Mount Commands"
        '';

        # during gummiboot, ESP is /
        # during stage 1, initrd is /
        # during stage 2, rpool is /
        # after that, systemd is started
        # at no point is the ESP ever available to the kernel, unless it mounts it directly
        # the ESP is only accessed by the UEFI firmware to load the gummiboot bootloader, which sets it up as /

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
            hostName = "matrix-central";
            hostId = (builtins.readFile ./secrets/hostid);
            enableIPv6 = true;
            useNetworkd = true;
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
            "nixos-config=/etc/nixos/eurocom-p7-pro-se/configuration.nix"
        ];
        nix.maxJobs = 8; # maximum of 8 build jobs for 8 cores
        nix.buildCores = 0; # use all available cores for parallel buildable packages
        nix.useSandbox =  true;
        nix.readOnlyStore = true; 
        nix.extraOptions = ''
            auto-optimise-store = true
            fsync-metadata = true
        '';

        # packages required for system functionality, including everything used by xmonad
        # all other packages should be part of the user profile
        environment.systemPackages = with pkgs; [
            coreutils     # basic shell utilities
            gnused        # sed
            gnugrep       # grep
            gawk          # awk
            ncurses       # tput (terminal control)
            iw            # wireless configuration
            iproute       # ip, tc
            nettools      # hostname, ifconfig
            pciutils      # lspci, setpci
            utillinux     # linux system utilities
            cryptsetup    # luks
            mtools        # disk labelling
            smartmontools # disk monitoring
            lm_sensors    # fan monitoring
            procps        # ps, top, pidof, vmstat, slabtop, skill, w
            psmisc        # fuser, killall, pstree, peekfd
            shadow        # passwd, su
            mkpasswd      # mkpasswd
            efibootmgr    # efi management
            openssh       # ssh
            hdparm        # disk info
            git           # needed for content addressed nixpkgs
        ];

        nixpkgs.config.allowUnfree = true;

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

        services = {
            mingetty.greetingLine = ''[[[ \l @ \n (\s \r \m) ]]]''; # getty message
            gpm.enable = true;
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
                    interface=wlp6s0
                    bind-interfaces
                    dhcp-range=10.0.0.2,10.0.0.254
                '';
                resolveLocalQueries = true;
                servers = [ 
                    "192.231.203.132" 
                    "192.231.203.3" 
                    "8.8.8.8" 
                    "8.8.4.4"
                    "209.244.0.3" 
                    "209.244.0.4" 
                    "2001:44b8:1::1" 
                    "2001:44b8:2::2"
                    "2001:4860:4860::8888"
                    "2001:1608:10:25::1c04:b12f"
                ];
            };
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
                videoDrivers = [ "nvidia" ]; # a priority list of video drivers to drive X, it is possible to specify legacy driverslike: "nvidiaLegacy340"
		xrandrHeads = [ "DP-0" ];
                synaptics = {
                    enable = true;
                    minSpeed = "0.5";
                    maxSpeed = "2";
                    accelFactor = "0.008";
                    twoFingerScroll = true;
                    palmDetect = true; 
                    # ignoring palm & natural scrolling
                    additionalOptions = ''
                        Option "PalmMinWidth" "5"
                        Option "PalmMinZ" "70"
                        Option "VertScrollDelta" "-111"
                        Option "HorizScrollDelta" "-111"
                    '';
                };
                displayManager = {
                    sddm.enable = true;
                    hiddenUsers = [ "root" "nobody" ]; # cannot login to root
                };
                desktopManager = {
                    xterm.enable = false;
                };
                windowManager = {
                    default = "xmonad";
                    xmonad.enable = true;
                    xmonad.enableContribAndExtras = true; # automatically brings in xmonad-contrib and xmonad-extras
                    xmonad.extraPackages = haskellPackages: [ # more packages available from haskellPackages, made available to when compiling ~/.xmonad/xmonad.hs
                        haskellPackages.xmobar
                    ];
                };
            };
            # this may not work, but if it does, it replaces getty to produce a high resolution terminal
            # not sure how this affects the mingetty line
            kmscon.enable = true;
            kmscon.hwRender = true;
            dbus.enable = true;
            haveged.enable = true;
            locate.enable = true;
            cron.enable = false;
        };

        users = {
            defaultUserShell = "/run/current-system/sw/bin/zsh"; # set the default shell to ZSH instead of bash
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
                    extraGroups = [ "wheel" "users" "networkmanager" ];
                    home = "/home/cmcdragonkai";
                    createHome = true;
                    useDefaultShell = true;
                    hashedPassword = builtins.readFile ./secrets/operator_password_hash;
                    openssh.authorizedKeys.keyFiles = [ ./identity.pub ];
                };
            };
        };

        security.sudo.wheelNeedsPassword = true;

        # activationScripts and postBootCommands run just before 
        # systemd is started, but after stage 1 has mounted the root filesystem
        # an adequate way to test if you're running at boot or not, is to test 
        # the presence of systemd using pidof

        boot.postBootCommands = ''
            echo "Running Post-Boot Commands"
        '';

        system.activationScripts.diskScheduler = ''

            zfs_disks=(${
                lib.concatStringsSep 
                    " " 
                    (storageGeometry.methods.extractStorageDevicesOnlyDisks (disk: 
                        disk.zfs || lib.any (part: part.zfs) disk.partitions
                    ) (disk: disk.path) storageGeometry.disks)
            })

            for path in "''${zfs_disks[@]}"; do
                echo noop >/sys/block/$(
                    ${pkgs.coreutils}/bin/basename $(
                        ${pkgs.coreutils}/bin/readlink -f $path
                    )
                )/queue/scheduler
            done

        '';


	# Everything below should be replaced by the new EFI grub cloning functionality
	# if things fail... oh well too bad, that's why you have 2 boots!

        system.activationScripts.efibootmgr = ''

            # TODO: make this script only run at rebuilds
            # it does only run at rebuilds right now, but that's because we test if systemd is available
            # it would be better to have exact hooks for this inside nixos

            if ${pkgs.procps}/bin/pidof -s systemd >/dev/null; then
                
                # efibootmgr places the last entry at the highest boot order, so we reverse our diskPaths list first
                esp_disk_paths=(${
                    lib.concatStringsSep 
                        " " 
                        (lib.reverseList 
                            (storageGeometry.methods.extractStorageDevicesOnlyDisks (disk: 
                                disk.esp || lib.any (part: part.esp) disk.partitions
                            ) (disk: disk.path) storageGeometry.disks)
                        )
                })

                # making this script idempotent
                ${pkgs.efibootmgr}/bin/efibootmgr \
                | ${pkgs.gnugrep}/bin/grep -Po '(?<=Boot)\d{4}(?=.*${esp.efiLabelPrefix})' \
                | ${pkgs.findutils}/bin/xargs -I{} ${pkgs.efibootmgr}/bin/efibootmgr -b {} -B -q

                for i in "''${!esp_disk_paths[@]}"; do

                    # because the array has been reversed
                    # to preserve the ordering labels 
                    # we have to reverse the label index $j

                    j=$((''${#esp_disk_paths[@]} - $i))
                    
                    ${pkgs.efibootmgr}/bin/efibootmgr \
                        --create \
                        --gpt \
                        --disk ''${esp_disk_paths[$i]} \
                        --part 1 \
                        --label "${esp.efiLabelPrefix} $j" \
                        --loader /EFI/Boot/BOOTX64.efi \
                        --quiet
                
                done

            fi

        '';

        systemd.services.espCloning = {
            description = "Cloning the current ESP partition to redundant ESP partitions after a successful boot.";
            path = [ pkgs.coreutils pkgs.utillinux pkgs.mtools pkgs.findutils pkgs.gnugrep ];
            wantedBy = [ "multi-user.target" ]; 
            unitConfig = {
                RequiresMountsFor = esp.mountPath;
            };
            serviceConfig = {
                Type = "oneshot";
            };
            script = ''

                # we are only running this after a successful boot to allow for redundant ESPs
                # it does mean we may have out-of-sync ESPs but it's good tradeoff for redundant ESPs
                # in case we clobber our main ESP
                # we will have the main ESP setup according to storageGeometry order

                clone_esp () {

                    esp_disk_part_paths=(${
                        lib.concatStringsSep 
                            " " 
                            (storageGeometry.methods.extractStorageDevices 
                                (block: block.esp) 
                                (block: block.path) 
                                storageGeometry.disks
                            )
                    })

                    current_esp_disk_part_path=$(df --output=source '${esp.mountPath}' | tail -n 1)

                    # filter out the paths equivalent to current esp disk part path
                    readarray -t esp_disk_part_paths < <(
                        for d in "''${esp_disk_part_paths[@]}"; do
                            if [[ $(readlink -f "$d") !=  "$current_esp_disk_part_path" ]]; then
                                echo "$d"
                            fi
                        done
                    )

                    echo "Cloning ESP $current_esp_disk_part_path to ''${esp_disk_part_paths[@]}"

                    # clone from current esp to all other esp partitions
                    # 128M is usually faster than the default block size
                    for part_path in "''${esp_disk_part_paths[@]}"; do

                        # cloning disks results in duplicate UUIDs, we want to prevent this
                        # check if the target disk is already a vfat filesystem, if so, preserve existing UUID
                        # if not, generate a new random uuid
                        if [ "$(lsblk --noheadings --nodeps --output FSTYPE "$part_path")" == "vfat" ]; then 
                            
                            esp_uuid=$(lsblk --noheadings --nodeps --output UUID "$part_path")
                            esp_uuid=$(tr --delete "-" <<< "$esp_uuid")

                            dd if="$current_esp_disk_part_path" of="$part_path" bs=128M status=none

                            MTOOLSRC=<(echo "drive a: file=\"$part_path\"") \
                            MTOOLS_SKIP_CHECK=1 \
                            mlabel -N $esp_uuid a:

                        else

                            dd if="$current_esp_disk_part_path" of="$part_path" bs=128M status=none

                            MTOOLSRC=<(echo "drive a: file=\"$part_path\"") \
                            MTOOLS_SKIP_CHECK=1 \
                            mlabel -n a:

                        fi
                        
                    done

                }

                espsum=$(
                    find '${esp.mountPath}' -type f -print0 \
                    | LC_ALL=C sort -z \
                    | xargs -0 ${pkgs.coreutils}/bin/md5sum \
                    | md5sum
                )

                if [ ! -f '${esp.checksumPath}' -o ! -s '${esp.checksumPath}' ]; then 
                    
                    echo "Proceeding to clone ESP because checksum doesn't exist."
                    clone_esp
                    echo "$espsum" >'${esp.checksumPath}'
                
                elif ! grep --fixed-strings --line-regexp --quiet "$espsum" '${esp.checksumPath}'; then 
                    
                    echo "Proceeding to clone ESP because checksum is different from cache."
                    clone_esp
                    echo "$espsum" >'${esp.checksumPath}'
                
                fi

            '';
        };

        environment.etc."os-release".text = lib.mkForce ''
            NAME="Matrix Central"
            ID="matrix-central"
            HOME_URL="https://matrix.ai/"
        '';

    }

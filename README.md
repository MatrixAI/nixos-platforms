NixOS Platforms
===============

This repository contains NixOS configuration for various platforms used by Matrix AI.

It is currently organised by platform labels. However in the future, this may need to be updated with a platform generator that generates platform configuration by first gathering telemetry from the platform. It could also use the Matrix hardware database when it is ready.

Credentials and security related keys are not stored in this repository.

This repository still requires automation tools for hardware setup. It currently assumes you already have specific disk layout setup. Preferably it can be done from bare metal. Options include a prebuilt image designed to be put into a USB, and automatically run unattended, or boot from Network image.

Prior to setting this up you need to acquire a content-addressed NixPkgs into the OS.

Read this for more information: http://matrix.ai/2017/03/13/intro-to-nix-channels-and-reproducible-nixos-environment/

```
sudo --login

rm --recursive /nix/nixpkgs
git clone https://github.com/nixos/nixpkgs /nix/nixpkgs
pushd /nix/nixpkgs
git remote add channels https://github.com/nixos/nixpkgs-channels  
git fetch --all  
git checkout -B channels-nixos-17.03 channels/nixos-17.03
popd

# bring in luks-key.img.cpio.gz into the platform directory

rm --recursive --force /etc/nixos
git clone https://github.com/MatrixAI/nixos-platforms.git /etc/nixos
nixos-rebuild -I nixpkgs=/nix/nixpkgs -I nixos-config=/etc/nixos/<PLATFORM>/configuration.nix boot --install-bootloader
```

Make sure to enter the correct `<PLATFORM>`.

---

To setup ZFS at USB boot. you will need to set `boot.supportedFilesystems = [ "zfs" ];` to your `/etc/nixos/configuration.nix` and then run `nixos-rebuild switch`.

Generating `secrets/hostid`:

```sh
head -c4 /dev/urandom | od -A none -t x4 | tr -d ' \n' > secrets/hostid
```

Generating `secrets/operator_password_hash`:

```sh
mkpasswd -m sha-512 | tr -d ' \n' > secrets/operator_password_hash
```

When running nixos-install. Use `NIXOS_CONFIG="etc/nixos/<PLATFORM>/configuration.nix" nixos-install`.

Running `nixos-install` multiple times is not truly idempotent. I recommend you to delete the `/boot`, and `/etc` except for `/etc/nixos` and `/etc/zfs/zpool.cache`. Otherwise certain files will be left there and unchanged.

# use wwn names in the future!
{
    disks = [
        rec {
            path = "/dev/disk/by-id/ata-ST2000LM003_HN-M201RAD_S321J9BFB03123";
            rotational = true;
            esp = false;
            zfs = false;
            luksEncrypted = false;
            luksName = null;
            luksKeyFile = null;
            partitions = [
                {
                    path = path + "-part1"; # rec allows mutually recursive attribute sets, reference to current scope
                    rotational = rotational;
                    esp = false;
                    zfs = true;
                    luksEncrypted = true;
                    luksName = "main-encrypted-ata-ST2000LM003_HN-M201RAD_S321J9BFB03123-part1";
                    luksKeyFile = "/dev/mapper/luks-key-encrypted";
                }
            ];
        } 
        rec {
            path = "/dev/disk/by-id/ata-ST2000LM003_HN-M201RAD_S321J9BFB03122";
            rotational = true;
            esp = false;
            zfs = false;
            luksEncrypted = false;
            luksName = null;
            luksKeyFile = null;
            partitions = [
                {
                    path = path + "-part1";
                    rotational = rotational;
                    esp = false;
                    zfs = true;
                    luksEncrypted = true;
                    luksName = "main-encrypted-ata-ST2000LM003_HN-M201RAD_S321J9BFB03122-part1";
                    luksKeyFile = "/dev/mapper/luks-key-encrypted";
                }
            ];
        } 
        rec {
            path = "/dev/disk/by-id/ata-PLEXTOR_PX-G128M6e_P02445180196";
            rotational = false;
            esp = false;
            zfs = false;
            luksEncrypted = false;
            luksName = null;
            luksKeyFile = null;
            partitions = [
                {
                    path = path + "-part1"; 
                    rotational = rotational;
                    esp = true;
                    zfs = false;
                    luksEncrypted = false;
                    luksName = null;
                    luksKeyFile = null;
                } 
                {
                    path = path + "-part2";
                    rotational = rotational;
                    esp = false;
                    zfs = true;
                    luksEncrypted = true;
                    luksName = "zil-encrypted-ata-PLEXTOR_PX-G128M6e_P02445180196-part2";
                    luksKeyFile = "/dev/mapper/luks-key-encrypted";
                } 
                {
                    path = path + "-part3";
                    rotational = rotational;
                    esp = false;
                    zfs = true;
                    luksEncrypted = true;
                    luksName = "l2arc-encrypted-ata-PLEXTOR_PX-G128M6e_P02445180196-part3";
                    luksKeyFile = "/dev/mapper/luks-key-encrypted";
                }
            ];
        }
        rec {
            path = "/dev/disk/by-id/ata-PLEXTOR_PX-G128M6e_P02445180209";
            rotational = false;
            esp = false;
            zfs = false;
            luksEncrypted = false;
            luksName = null;
            luksKeyFile = null;
            partitions = [
                {
                    path = path + "-part1"; 
                    rotational = rotational; 
                    esp = true;
                    zfs = false;
                    luksEncrypted = false;
                    luksName = null;
                    luksKeyFile = null;
                } 
                {
                    path = path + "-part2"; 
                    rotational = rotational; 
                    esp = false;
                    zfs = true;
                    luksEncrypted = true;
                    luksName = "zil-encrypted-ata-PLEXTOR_PX-G128M6e_P02445180209-part2";
                    luksKeyFile = "/dev/mapper/luks-key-encrypted";
                } 
                {
                    path = path + "-part3"; 
                    rotational = rotational; 
                    esp = false;
                    zfs = true;
                    luksEncrypted = true;
                    luksName = "l2arc-encrypted-ata-PLEXTOR_PX-G128M6e_P02445180209-part3";
                    luksKeyFile = "/dev/mapper/luks-key-encrypted";
                }
            ];
        }
    ];
    methods = with {
        # inherit basically means as if these were defined in the current attribute set
        # while with means take this attribute set, and make its contents available in the subsequent expression scope
        # rather than using inherit inside the rec, this way we make sure that these functions are not accessible from here
        inherit (builtins) map filter; # bring map and filter into the scope of the methods attribute set
        inherit ((import <nixpkgs> {}).lib) concatMap; # bring concatMap into the scope of methods attribute set
    }; 
    rec {
        extractStorageDevicesOnlyDisks = blockFilter: blockExtract: disks: 
            map blockExtract (filter blockFilter disks);
        extractStorageDevicesOnlyParts = blockFilter: blockExtract: disks:  
            concatMap (disk: map blockExtract (filter blockFilter disk.partitions)) disks;
        extractStorageDevices = blockFilter: blockExtract: disks: 
            extractStorageDevices' blockFilter blockExtract disks 
                (disk: extractedPartitions: 
                    if blockFilter disk then 
                        [ (blockExtract disk) ] ++ extractedPartitions
                    else
                        extractedPartitions
                ); 
        extractStorageDevicesPreferDisks = blockFilter: blockExtract: disks: 
            extractStorageDevices' blockFilter blockExtract disks 
                (disk: extractedPartitions: 
                    if blockFilter disk then 
                        [ (blockExtract disk) ]
                    else
                        extractedPartitions
                );
        extractStorageDevicesPreferParts = blockFilter: blockExtract: disks: 
            extractStorageDevices' blockFilter blockExtract disks 
                (disk: extractedPartitions: 
                    if (length extractedPartitions == 0) && (blockFilter disk) then
                        [ (blockExtract disk) ]
                    else 
                        extractedPartitions
                ); 
        extractStorageDevices' = blockFilter: blockExtract: disks: blockCombine: 
            concatMap (disk: blockCombine disk (map blockExtract (filter blockFilter disk.partitions))) disks;
    };
}
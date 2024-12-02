{ config, lib, options, pkgs, ... }:

let
  cfg = config.virtualisation;
  hostPkgs = cfg.host.pkgs;
  driveOpts = { ... }: {
    options = {
      file = lib.mkOption {
        type = lib.types.str;
        description = "The file image used for this drive";
      };

      backingFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "";
        example = "./backing-file";
        description = "The backing file used for the COW image";
      };

      serial = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "The serial number for the ubd device";
      };

      read-only = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "Open ubd file read only";
      };

      sync = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "Open ubd files with the sync option set, this makes the host save changes to the disk as they are written";
      };

      no-cow = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "Ignore COW detection and open the drive directly";
      };

      shared = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "Treat the file as being shared between multiple instances and disable file locking";
      };

      no-trim = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "Disable trim/discard support on the device";
      };
    };
  };

  mkFlags = drive: lib.concatStrings [
    (lib.optionalString drive.read-only "r")
    (lib.optionalString drive.sync "s")
    (lib.optionalString drive.no-cow "d")
    (lib.optionalString drive.shared "c")
    (lib.optionalString drive.no-trim "t")
  ];

  driveCmdline = lib.imap0 (index: drive: "ubd${toString index}${mkFlags drive}=${drive.file}"
    + lib.optionalString (lib.isString drive.backingFile || lib.isString drive.serial) ",${toString drive.backingFile}"
    + lib.optionalString (lib.isString drive.serial) ",${drive.serial}"
  ) cfg.uml.drives;

  # Use well-defined and persistent filesystem labels to identify block devices.
  rootFilesystemLabel = "nixos";

  rootDriveSerialAttr = "root";

in

{
  options = {
    virtualisation = {
      uml = {
        drives = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule driveOpts);
          description = "The ubd drives used for User-Mode Linux";
        };
        kernelPackages = options.boot.kernelPackages // {
          default =  pkgs.linuxPackages_uml;
        };
        initrd = lib.mkOption {
          type = lib.types.str;
          default = "${config.system.build.toplevel}/${config.system.boot.loader.initrdFile}";
          defaultText = "\${config.system.build.initialRamdisk}/\${config.system.boot.loader.initrdFile}";
          description = ''
            When using User-Mode Linux, you may want to change the initrd
          '';
        };
        options = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "con1=xterm" ];
          description = ''
            Command line parameters passed to the User-Mode Linux kernel
          '';
        };
      };
    };
  };
  config = {
    boot = {
      loader = {
        grub = {
          enable = lib.mkForce false;
        };
      };
      kernelPackages = lib.mkVMOverride cfg.uml.kernelPackages;
    };
    system = {
      boot = {
        loader = {
          kernelFile = "vmlinux";
        };
      };
      build = {
        uml-loader =
          hostPkgs.writeShellScriptBin "run-${config.system.name}" ''
            export PATH=${lib.makeBinPath [hostPkgs.coreutils]}''${PATH:+:}$PATH

            set -e

            createEmptyFilesystemImage() {
              local name=$1
              local size=$2
              ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L ${rootFilesystemLabel} "$name" "$size"
            }

            NIX_DISK_IMAGE=$(readlink -f "''${NIX_DISK_IMAGE:-${toString config.virtualisation.diskImage}}") || test -z "$NIX_DISK_IMAGE"

            if test -n "$NIX_DISK_IMAGE" && ! test -e "$NIX_DISK_IMAGE"; then
              echo "Disk image does not exist, creating the virtualisation disk image..."
              ${if cfg.useDefaultFilesystems then
                ''
                  createEmptyFilesystemImage "$NIX_DISK_IMAGE" "${toString cfg.diskSize}M"
                ''
              else ''
                fallocate -l "${toString cfg.diskSize}M" "$NIX_DISK_IMAGE"
              ''
              }
            fi

            if [ -z "$TMPDIR" ] || [ -z "$USE_TMPDIR" ]; then
              TMPDIR=(mktemp -d nix-vm.XXXXXXXXXX --tmpdir)
            fi

            export PATH=${pkgs.uml-utilities.lib}/lib/uml:$PATH

            export UML_PORT_HELPER=${pkgs.uml-utilities.lib}/lib/uml/port-helper

            exec ${config.system.build.toplevel}/kernel \
              ${lib.concatStringsSep " \\\n  " config.virtualisation.uml.options} \
              "$@"
          '';
      };
    };
    # Unlike a non user-mode kernel, in User-Mode Linux, tty0 (con0) is a normal console and the default
    systemd.targets.getty.wants = ["getty@tty0.service"];
    virtualisation = {
      fileSystems = lib.mapAttrs' (tag: share: {
        name = share.target;
        value.fsType = lib.mkForce "hostfs";
      }) config.virtualisation.sharedDirectories // {
        "/tmp/xchg" = {
          neededForBoot = lib.mkForce false;
          options = [ "noauto" ];
        };
        "/tmp/shared" = {
          neededForBoot = lib.mkForce false;
          options = [ "noauto" ];
        };
      };
      uml = {
        drives = lib.mkMerge [
          (lib.mkIf (cfg.diskImage != null) [
            {
              serial = rootDriveSerialAttr;
              file = ''"$NIX_DISK_IMAGE"'';
            }
          ])
          (lib.mkIf cfg.useNixStoreImage [
            {
              file = ''"$TMPDIR"/store.img'';
            }
          ])
          (lib.imap0 (idx: _: {
            file = "$(pwd)/empty${toString idx}.qcow2";
          }) cfg.emptyDiskImages)
        ];
        options = [
          "initrd=${config.virtualisation.uml.initrd}"
          "mem=${toString config.virtualisation.memorySize}M"
          "$(cat ${config.system.build.toplevel}/kernel-params) init=${config.system.build.toplevel}/init"
        ] ++ driveCmdline;
      };
    };
  };
}

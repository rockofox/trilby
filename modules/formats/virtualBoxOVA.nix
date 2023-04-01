{ inputs, lib, ... }:

{
  boot.loader.grub.device = lib.mkForce "/dev/sda";
  imports = [
    inputs.self.nixosModules.nixos.virtualisation.virtualbox-image
  ];
}

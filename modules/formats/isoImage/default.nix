{ inputs, trilby, lib, pkgs, ... }:

{
  imports = [
    inputs.self.nixosModules.nixos.installer.cd-dvd.installation-cd-base
  ];
  isoImage = {
    volumeID = with builtins; concatStringsSep "-" (filter (s: s != null && s != "") [
      trilby.name
      trilby.edition
      trilby.release
      trilby.hostSystem.cpu.name
      trilby.variant
    ]);
    squashfsCompression = "zstd";
    grubTheme = pkgs.trilby-grub2-theme;
    splashImage = pkgs.runCommand "bios-boot.png"
      {
        buildInputs = with pkgs; [ imagemagick ];
      } ''
      convert ${../../../overlays/trilby-grub2-theme/bios-boot.svg} $out
    '';
  };
  environment.etc.trilby.source = ../../..;
  services.xserver.displayManager = {
    gdm.autoSuspend = false;
    autoLogin = {
      enable = true;
      user = "trilby";
    };
  };
  # Automatically log in at the virtual consoles.
  services.getty = {
    autologinUser = lib.mkForce "trilby";
    helpLine = lib.mkForce "";
  };

  users.motd = builtins.readFile ./motd.txt;
  boot.initrd = {
    luks.devices = { };
    systemd.enable = false;
  };
  users.groups.trilby.gid = 1000;
  users.users.trilby = {
    uid = 1000;
    isNormalUser = true;
    name = "trilby";
    home = "/home/trilby";
    createHome = true;
    group = "trilby";
    extraGroups = [ "wheel" "networkmanager" "video" ];
    initialPassword = "trilby";
  };
  home-manager.users.trilby = { ... }: {
    programs.home-manager.enable = false;
    home = {
      username = "trilby";
      homeDirectory = "/home/trilby";
      stateVersion = trilby.release;
    };
    imports = [
      inputs.self.nixosModules.trilby.home
    ];
  };
}

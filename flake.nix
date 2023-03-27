{
  inputs = {
    "nixpkgs-22.05".url = "github:nixos/nixpkgs/nixos-22.05";
    "nixpkgs-22.11".url = "github:nixos/nixpkgs/nixos-22.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-monitored = {
      url = "github:ners/nix-monitored";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = inputs:
    with builtins;
    let
      lib = import ./lib { inherit inputs; };
      buildPlatforms = attrNames inputs.nixpkgs-unstable.legacyPackages;
      configurations = {
        name = [ "trilby" ];
        edition = attrNames (lib.findModules ./modules/trilby/editions);
        format = attrNames (lib.findModules ./modules/trilby/formats);
        hostSystem = lib.pipe ./modules/trilby/hostPlatforms [
          lib.findModules
          attrNames
          (map lib.systems.parse.mkSystemFromString)
        ];
        variant = [ null "musl" ];
        channel = [ "unstable" "22.11" "22.05" ];
      };
      configurationName = c: concatStringsSep "-" (filter (s: s != null && s != "") [
        c.name
        c.edition
        c.channel
        c.hostSystem.cpu.name
        c.variant
        c.format
      ]);
      foreach = xs: f: lib.foldr lib.recursiveUpdate { } (map f xs);
      foreachAttrs = attrs: foreach (lib.cartesianProductOfSets attrs);
    in
    {
      nixosModules = lib.findModules ./modules;
    } // foreach buildPlatforms (buildPlatform:
      let
        pkgs = inputs.nixpkgs-unstable.legacyPackages.${buildPlatform};
      in
      {
        formatter.${buildPlatform} = pkgs.nixpkgs-fmt;

        devShells.${buildPlatform}.default = pkgs.mkShell {
          packages = with pkgs; [ nixpkgs-fmt ];
        };

        packages.${buildPlatform} = foreachAttrs configurations (c:
          let
            trilby = c // {
              configurationName = configurationName c;
            };
            nixos = inputs.self.nixosConfigurations.${trilby.configurationName};
          in
          {
            "${trilby.configurationName}" = nixos.config.system.build.${trilby.format};
          }
        );

        nixosConfigurations = foreachAttrs configurations (c:
          let
            trilby = c // {
              configurationName = configurationName c;
              inherit buildPlatform;
              hostPlatform = lib.systems.parse.doubleFromSystem c.hostSystem;
              inherit (nixpkgs.lib.trivial) release;
            };
            nixpkgs = inputs."nixpkgs-${trilby.channel}";
            hostPkgs = import nixpkgs {
              system = trilby.hostPlatform;
              overlays = [
                (self: super: {
                  parsedSystem = self.lib.systems.parse.mkSystemFromString self.system;
                  unstable = import inputs.nixpkgs-unstable {
                    system = trilby.hostPlatform;
                    config.allowUnfree = true;
                  };
                })
              ];
            };
            pkgs =
              if trilby.variant == "musl" then
                hostPkgs.pkgsMusl
              else
                hostPkgs;
          in
          {
            "${trilby.configurationName}" = nixpkgs.lib.nixosSystem {
              specialArgs = {
                inherit inputs trilby lib;
              };
              modules = with inputs.self.nixosModules.trilby; [
                formats.${trilby.format}
                editions.${trilby.edition}
                hostPlatforms.${trilby.hostPlatform}
                inputs.disko.nixosModules.disko
                users
                {
                  nixpkgs = {
                    inherit pkgs;
                  } // lib.optionalAttrs (trilby.buildPlatform != trilby.hostPlatform) {
                    inherit (trilby) buildPlatform hostPlatform;
                  };
                }
              ];
            };
          }
        );
      }
    );
}

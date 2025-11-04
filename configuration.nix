{ config, lib, pkgs, ... }:

{
	imports = [
		./hardware-configuration.nix
	];

	boot.loader.systemd-boot.enable = true;
	boot.loader.efi.canTouchEfiVariables = true;

	boot.kernelPackages = pkgs.linuxPackages_latest;

	virtualisation.docker.enable = true;

	networking.networkmanager.enable = true;

	# Set your time zone.
	time.timeZone = "Australia/Brisbane";

	users.users.jones = {
		isNormalUser = true;
		extraGroups = [ "wheel" ];
		packages = with pkgs; [
			tree
		];
	};

	environment.systemPackages = with pkgs; [
		wget
		git
	];

	nix.settings.experimental-features = [ "nix-command" "flakes" ];

	services.openssh.enable = true;

	networking.interfaces.enp1s0.ipv4.addresses = [
		{
			address = "103.1.215.91";
			prefixLength = 31;
		}
	];

	networking.defaultGateway = "103.1.215.90";
	networking.nameservers = [ "8.8.8.8" ];

	system.stateVersion = "25.05";

	virtualisation.quadlet = let
        inherit (config.virtualisation.quadlet) networks pods volumes;
    in {
        containers = {
			homepage = {
				containerConfig = {
					image = "ghcr.io/gethomepage/homepage:latest";
					networks = [ networks.internal.ref ];
					volumes = [ 
						"${volumes.homepageConfig.ref}:/app/config"
						"${volumes.homepageImages.ref}:/app/public/images"
					];
					environments = {
						HOMEPAGE_ALLOWED_HOSTS = "dash.jonesaus.com";
					};
					healthCmd = "none";
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			cloudflared = {
				containerConfig = {
					image = "cloudflare/cloudflared:latest";
					networks = [ networks.internal.ref ];
					exec = "tunnel --no-autoupdate run --token eyJhIjoiZDBkZmFhYWE3OTdjYjE1ZWRmNDQxZjE2N2JlYzhjNDMiLCJ0IjoiYjljMTNhODAtN2VkNi00NzUwLWE5ZjgtY2JhYTYwOTU4NjgyIiwicyI6Ik4yRXhNV1E0TTJRdE1qQTJZaTAwT0RKaUxUa3pZVFF0TkdVMlpqSmlZMkpqWVRZdyJ9";
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
        };
        networks = {
            internal.networkConfig.subnets = [ "10.0.0.0/24" ];
        };
		volumes = {
			homepageConfig = {
				volumeConfig = {
					name = "homepage-config";
					labels = {
						app = "homepage";
					};
				};
			};
			homepageImages = {
				volumeConfig = {
					name = "homepage-images";
					labels = {
						app = "homepage";
					};
				};
			};
		};
    };

	systemd.services.homepage-config-sync = {
		description = "Sync homepage configuration to Docker volume";
		wantedBy = [ "multi-user.target" ];
		before = [ "podman-homepage.service" ];
		serviceConfig = {
			Type = "oneshot";
			RemainAfterExit = true;
		};
		script = ''
			# Create a temporary container to access the volumes
			${pkgs.podman}/bin/podman run --rm \
				-v homepage-config:/config \
				-v homepage-images:/images \
				-v /etc/nixos/homepage:/source:ro \
				${pkgs.busybox}/bin/busybox \
				sh -c "cp /source/*.yaml /config/ 2>/dev/null || true; cp /source/*.jpg /images/ 2>/dev/null || true"
		'';
	};
}


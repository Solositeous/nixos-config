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

	# Ensure /s3data directory exists for s3fs container
	systemd.tmpfiles.rules = [
		"d /s3data 0755 root root -"
	];

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
			# Core Containers
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
			portainer = {
				containerConfig = {
					image = "portainer/portainer-ce:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/var/run/podman/podman.sock:/var/run/docker.sock:ro"
						"${volumes.portainerData.ref}:/data"
					];
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			s3fs = {
				containerConfig = {
					image = "efrecon/s3fs:latest";
					networks = [ networks.internal.ref ];
					environments = {
						AWS_S3_URL = "s3.ap-southeast-2.wasabisys.com";
						AWS_S3_ACCESS_KEY_ID = "SACUZBT3E97W1ZAXUF7A";
						AWS_S3_SECRET_ACCESS_KEY = "FKS8NX0MAujoNGIQ9CVjKenNbQ9V0lLogHdBSbRW";
						AWS_S3_BUCKET = "jonesausfiles";
					};
					volumes = [
						"/s3data:/opt/s3fs/bucket:rshared"
					];
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			mariaDB = {
				containerConfig = {
					image = "mariadb:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/mariadb:/var/lib/mysql:Z"
					];
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			homarr = {
				containerConfig = {
					image = "ghcr.io/homarr-labs/homarr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/configs/homarr:/appdata:Z"
						"/var/run/podman/podman.sock:/var/run/docker.sock:ro"
					];
					environments = {
						SECRET_ENCRYPTION_KEY = "024484ba50bbd92f8c408c4bfb61e40d2890fda6ab59e3eb2645afbba6949f9a";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			# Media Containers
			jellyfin = {
				containerConfig = {
					image = "linuxserver/jellyfin:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/configs/jellyfin:/config:Z"
						"/s3data/media:/media:Z"
					];
					devices = [
						"/dev/dri:/dev/dri"
					];
					environments = {
						PUID = "1000";
						PGID = "1000";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			sonarr = {
				containerConfig = {
					image = "linuxserver/sonarr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/configs/sonarr:/config:Z"
						"/s3data/media:/media:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					environments = {
						PUID = "1000";
						PGID = "1000";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			radarr = {
				containerConfig = {
					image = "linuxserver/radarr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/configs/radarr:/config:Z"
						"/s3data/media:/media:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					environments = {
						PUID = "1000";
						PGID = "1000";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			readarr = {
				containerConfig = {
					image = "blampe/rreading-glasses:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/configs/readarr:/config:Z"
						"/s3data/media:/media:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					environments = {
						PUID = "1000";
						PGID = "1000";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			prowlarr = {
				containerConfig = {
					image = "linuxserver/prowlarr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/configs/prowlarr:/config:Z"
					];
					environments = {
						PUID = "1000";
						PGID = "1000";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			jellyseerr = {
				containerConfig = {
					image = "jellyseerr/jellyseerr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/configs/jellyseerr:/app/config:Z"
						"/s3data/media:/media:Z"
					];
					environments = {
						PUID = "1000";
						PGID = "1000";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			transmission = {
				containerConfig = {
					image = "linuxserver/transmission:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data/configs/transmission:/config:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					environments = {
						PUID = "1000";
						PGID = "1000";
						TZ = "Australia/Brisbane";
					};
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
			portainerData = {
				volumeConfig = {
					name = "portainer-data";
					labels = {
						app = "portainer";
					};
				};
			};
			downloads = {
				volumeConfig = {
					name = "downloads";
					labels = {
						app = "media";
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
		};
		script = ''
			# Create a temporary container to access the volumes
			${pkgs.podman}/bin/podman run --rm \
				-v homepage-config:/config \
				-v homepage-images:/images \
				-v ${./homepage}:/source:ro \
				docker.io/busybox:latest \
				sh -c "cp /source/*.yaml /config/ 2>/dev/null || true; cp /source/*.jpg /images/ 2>/dev/null || true"
		'';
		restartTriggers = [ 
			(builtins.readFile ./homepage/settings.yaml)
			(builtins.readFile ./homepage/services.yaml)
			(builtins.readFile ./homepage/docker.yaml)
		];
	};

	systemd.services.podman-homepage = {
		restartTriggers = [ 
			(builtins.readFile ./homepage/settings.yaml)
			(builtins.readFile ./homepage/services.yaml)
			(builtins.readFile ./homepage/docker.yaml)
		];
	};
}


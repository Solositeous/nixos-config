{ config, lib, pkgs, ... }:

{
	imports = [
		./hardware-configuration.nix
	];

	boot.loader.systemd-boot.enable = true;
	boot.loader.efi.canTouchEfiVariables = true;

	boot.kernelPackages = pkgs.linuxPackages_latest;
	boot.kernelModules = [ "fuse" ];

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
		mariadb
		python
	];

	nix.settings.experimental-features = [ "nix-command" "flakes" ];

	services.openssh.enable = true;

	# Ensure /s3data directory exists for s3fs container
	systemd.tmpfiles.rules = [
		"d /s3data 0755 root root -"
		"d /configs 0755 root root -"
		"d /configs/jellyfin 0755 root root -"
		"d /configs/sonarr 0755 root root -"
		"d /configs/radarr 0755 root root -"
		"d /configs/readarrdb 0755 root root -"
		"d /configs/readarrapi 0755 root root -"
		"d /configs/readarr 0755 root root -"
		"d /configs/prowlarr 0755 root root -"
		"d /configs/jellyseerr 0755 root root -"
		"d /configs/transmission 0755 root root -"
		"d /configs/mariadb 0755 root root -"
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
		autoEscape = true;
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
			s3fs = {
				containerConfig = {
					image = "efrecon/s3fs:1.92";
					networks = [ networks.internal.ref ];
					environments = {
						AWS_S3_URL = "https://s3.ap-southeast-2.wasabisys.com";
						AWS_S3_ACCESS_KEY_ID = "SACUZBT3E97W1ZAXUF7A";
						AWS_S3_SECRET_ACCESS_KEY = "FKS8NX0MAujoNGIQ9CVjKenNbQ9V0lLogHdBSbRW";
						AWS_S3_BUCKET = "jonesausfiles";
					};
					volumes = [
						"/s3data:/opt/s3fs/bucket:rshared"
					];
					devices = [
						"/dev/fuse"
					];
					addCapabilities = [
						"SYS_ADMIN"
					];
					securityLabelDisable = true;
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			s3fsHealthcheck = {
				containerConfig = {
					image = "python:3-alpine";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data:/s3data:ro"
						"/etc/nixos/scripts/s3fsHealthCheck.py:/healthcheck.py:ro"
					];
					exec = "python3 /healthcheck.py";
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			mariadbHealthcheck = {
				containerConfig = {
					image = "python:3-alpine";
					networks = [ networks.internal.ref ];
					volumes = [
						"/etc/nixos/scripts/mariadbHealthCheck.py:/healthcheck.py:ro"
					];
					exec = ''sh -c "apk add --no-cache mariadb-client && python3 /healthcheck.py"'';
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
					After = [ "mariaDB.service" ];
					Requires = [ "mariaDB.service" ];
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
			dashdot = {
				containerConfig = {
					image = "mauricenino/dashdot:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/var/run/podman/podman.sock:/var/run/docker.sock:ro"
					];
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
				};
			};
			dev = {
				containerConfig = {
					image = "reverie89/vscode-tunnel";
					hostname = "jones-dev";
					networks = [ networks.internal.ref ];
					volumes = [
						"/s3data:/s3data:Z"
						"/home/jones:/home/jones"
						"${volumes.vscode.ref}:/root"
					];
				};
				serviceConfig = {
					TimeoutStartSec = "300";
					Restart = "unless-stopped";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			mariaDB = {
				containerConfig = {
					image = "mariadb:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/mariadb:/var/lib/mysql:Z"
					];
					environments = {
						MYSQL_ROOT_PASSWORD = "oWFKLOgqTlNw25it0ih3";
					};
					publishPorts = [ "3306:3306" ];
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
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			# Media Containers
			jellyfin = {
				containerConfig = {
					image = "linuxserver/jellyfin:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/jellyfin:/config:Z"
						"/s3data/media:/media:Z"
					];
					devices = [
						"/dev/dri:/dev/dri"
					];
					environments = {
						PUID = "0";
						PGID = "0";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "300";
					TimeoutStopSec = "120";
					Restart = "unless-stopped";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			sonarr = {
				containerConfig = {
					image = "linuxserver/sonarr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/sonarr:/config:Z"
						"/s3data/media:/media:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					environments = {
						PUID = "0";
						PGID = "0";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "unless-stopped";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			radarr = {
				containerConfig = {
					image = "linuxserver/radarr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/radarr:/config:Z"
						"/s3data/media:/media:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					environments = {
						PUID = "0";
						PGID = "0";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "unless-stopped";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			readarrdb = {
				containerConfig = {
					image = "postgres:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/readarrdb:/var/lib/postgresql:Z"
					];
					environments = {
						POSTGRES_USER = "readarr";
						POSTGRES_PASSWORD = "zpNH4w3rjD05siRRzLID!";
						POSTGRES_DB = "readarr";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "always";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			readarrapi = {
				containerConfig = {
					image = "blampe/rreading-glasses:hardcover";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/readarrapi:/config:Z"
						"/s3data/media:/media:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					entrypoint = "/main";
					exec = [ "serve" "--verbose" ];
					environments = {
						HARDCOVER_AUTH = "Bearer eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJIYXJkY292ZXIiLCJ2ZXJzaW9uIjoiOCIsImp0aSI6ImQxOTNiMjY4LTdmMTAtNDUyOC1iYWU1LTNiMTU2ODFmOTdhNSIsImFwcGxpY2F0aW9uSWQiOjIsInN1YiI6IjUzNTQ3IiwiYXVkIjoiMSIsImlkIjoiNTM1NDciLCJsb2dnZWRJbiI6dHJ1ZSwiaWF0IjoxNzYyNDMxMDA3LCJleHAiOjE3OTM5NjcwMDcsImh0dHBzOi8vaGFzdXJhLmlvL2p3dC9jbGFpbXMiOnsieC1oYXN1cmEtYWxsb3dlZC1yb2xlcyI6WyJ1c2VyIl0sIngtaGFzdXJhLWRlZmF1bHQtcm9sZSI6InVzZXIiLCJ4LWhhc3VyYS1yb2xlIjoidXNlciIsIlgtaGFzdXJhLXVzZXItaWQiOiI1MzU0NyJ9LCJ1c2VyIjp7ImlkIjo1MzU0N319.LoMGWbqbbbqMJN2PhU7-7WV60HmdWxcyEdp99r55dI8";
						POSTGRES_HOST = "readarrdb";
						POSTGRES_DATABASE = "readarr";
						POSTGRES_USER = "readarr";
						POSTGRES_PASSWORD = "zpNH4w3rjD05siRRzLID!";
						PUID = "0";
						PGID = "0";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "unless-stopped";
					After = [ "s3fs.service" "readarrdb.service" ];
					Requires = [ "s3fs.service" "readarrdb.service" ];
				};
			};
			readarr = {
				containerConfig = {
					image = "ghcr.io/pennydreadful/bookshelf:hardcover";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/readarr:/config:Z"
						"/s3data/media:/media:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					environments = {
						METADATA_URL = "http://readarrapi:8788";
						PUID = "0";
						PGID = "0";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "unless-stopped";
					After = [ "s3fs.service" "readarrapi.service" ];
					Requires = [ "s3fs.service" "readarrapi.service" ];
				};
			};
			prowlarr = {
				containerConfig = {
					image = "linuxserver/prowlarr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/prowlarr:/config:Z"
					];
					environments = {
						PUID = "0";
						PGID = "0";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "unless-stopped";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			jellyseerr = {
				containerConfig = {
					image = "fallenbagel/jellyseerr:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/jellyseerr:/app/config:Z"
						"/s3data/media:/media:Z"
					];
					environments = {
						PUID = "0";
						PGID = "0";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "unless-stopped";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
			transmission = {
				containerConfig = {
					image = "linuxserver/transmission:latest";
					networks = [ networks.internal.ref ];
					volumes = [
						"/configs/transmission:/config:Z"
						"${volumes.downloads.ref}:/downloads"
					];
					environments = {
						PUID = "0";
						PGID = "0";
						TZ = "Australia/Brisbane";
					};
				};
				serviceConfig = {
					TimeoutStartSec = "60";
					Restart = "unless-stopped";
					After = [ "s3fs.service" ];
					Requires = [ "s3fs.service" ];
				};
			};
        };
        networks = {
            internal.networkConfig.subnets = [ "10.0.0.0/24" ];
        };
		volumes = {
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
			vscode = {
				volumeConfig = {
					name = "vscode-data";
					labels = {
						app = "devcontainer";
					};
				};
			};
		};
    };
}


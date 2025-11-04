{ config, pkgs, ... }:

{
	home.username = "jones";
	home.homeDirectory = "/home/jones";
	programs.git.enable = true;
	home.stateVersion = "25.05";
	programs.bash = {
		enable = true;
		shellAliases = {
			btw = "echo I use Nixos";
		};
	};
}

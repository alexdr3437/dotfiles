# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.blueman.enable = true;

  # Set your time zone.
  time.timeZone = "America/Toronto";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
  };




  # --- shell
  programs.zsh.enable = true;


  # --- enable hyprland

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
    GDK_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    WLR_NO_HARDWARE_CURSORS = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  hardware = {
    graphics.enable = true;
	nvidia = {
	  modesetting.enable = true;
	  package = config.boot.kernelPackages.nvidiaPackages.stable;
	};
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true; # Enable open source nvidia driver



  # --- desktop portals (links between apps, screen share, opening links etc.)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };



  # --- Configure keymap in X11
  services.xserver.xkb.layout = "us";



  # --- Enable CUPS to print documents.
  services.printing.enable = true;



  # --- Enable sound.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };



  # --- Define a user account. 
  users.users.alex = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
    shell = pkgs.zsh;
  };



  # --- run nixos-rebuild with no password
  security.sudo.extraRules = [
    {
      users = [ "alex" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];



  # --- packages !
  programs.firefox.enable = true;

  # file manager
  programs.thunar.enable = true;
  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # games
  programs.steam.enable = true;

  nixpkgs.config = {
	allowUnfree = true;

	segger-jlink = {
	  acceptLicense = true;
	};
	permittedInsecurePackages = [ "segger-jlink-qt4-810" ];
 };

  environment.systemPackages = with pkgs; [
    inputs.neovim-nightly-overlay.packages.${pkgs.system}.default
    kitty
    wget
    walker
    zellij
    pulseaudio
    pavucontrol
    mako
    libnotify
    networkmanagerapplet
    dunst
    discord
    git
    stow
    gnumake
    gcc
    cargo
    unzip
    fzf
    ripgrep
    nodejs
    zoxide
    lazygit
    hyprpaper
    waybar
    hyprpicker
    hyprlock
    pywal
    blueman
    bluez
    yay
    obsidian
    neofetch
    ydiff
	wl-clipboard
    xclip
    parallel
    fftw
    wireshark
    gjs
	clang-tools
    arandr 
	bitwarden-desktop      
	socat
    jq 
	udev
    slack 
    tldr 
    gimp 
	brave
	nrf-command-line-tools
	segger-jlink
    picocom 
    openocd 
	powerstat
	inputs.rust-workspace.packages.${pkgs.system}.foo
  ];
     
  fonts.packages = with pkgs; [ nerd-fonts.droid-sans-mono nerd-fonts.agave nerd-fonts.fira-code ];

  services.udev.extraRules = ''
	SUBSYSTEM=="usb", MODE="0666", TAG+="uaccess"
  '';


	# this skips the login manager and starts Hyprland directly
	services.greetd = {
	  enable = true;

	  # rec makes `initial_session` visible to `default_session`
	  settings = rec {
		initial_session = {
		  user    = "alex";
		  command = "${pkgs.hyprland}/bin/Hyprland";
		};

		# now this works
		default_session = initial_session;
	  };

	  # avoid auto-restarting or you’ll relogin endlessly
	  restart = false;
	};


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;


  systemd.services = {
	ssh-tunnel = {
		description = "remote access tunnel to mesomat@";
		after = [ "network.target" ];
		wants = [ "network.target" ];
		wantedBy = [ "multi-user.target" ];

		serviceConfig = let
		  port = if config.fileSystems."/".device == "/dev/disk/by-uuid/b5484f30-5c3c-47be-8e06-d7f85896dd50" then 40202 # home desktop
				 else 40101; # work laptop
			in {
			  ExecStart = ''
				${pkgs.openssh}/bin/ssh \
				  -o ServerAliveInterval=60 \
				  -o ServerAliveCountMax=3 \
				  -N -R ${toString port}:localhost:22 mesomat@104.248.105.107
			  '';
			  Restart = "always";
			  RestartSec = 5;
			  User = "alex";
		};
	 };

	  data-saver-daemon = {
		description = "Data Saver Daemon";
		after = [ "network.target" ];
		wantedBy = [ "multi-user.target" ];

		serviceConfig = {
		  ExecStart = "${inputs.rust-workspace.packages.${pkgs.system}.foo}/bin/data-saver-daemon";
		  Restart = "always";
		  RestartSec = 5;
		  User = "alex"; # or a custom user if needed
		};
	  };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}

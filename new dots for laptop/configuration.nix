# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
 { config, pkgs,lib, ... }:

 let
  fetchFlake = builtins.getFlake "github:areofyl/fetch";
in
{ 
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
  ];
# garbage collecting boi
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "-d";
};


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.


hardware.graphics = {
  enable = true;
  enable32Bit = true; # for gaming/steam etc.
};

services.xserver.videoDrivers = [ "nvidia" ];
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
   networking.firewall.checkReversePath = false;
  # Set your time zone.
  time.timeZone = "Australia/Sydney";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_AU.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

#steam controller
environment.etc."bluetooth/input.conf".text = lib.mkForce ''
 [General]
 ClassicBondedOnly=false 
'';
hardware.steam-hardware.enable = true;
services.udev.packages = [ pkgs.game-devices-udev-rules ];
boot.blacklistedKernelModules = [ "hid_nintendo" ];
boot.extraModprobeConfig = "options bluetooth disable_ertm=1";
services.udev.extraRules = ''
  KERNEL=="hidraw*", KERNELS=="*0E6F:0186*", MODE="0666"
'';
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."jamie" = {
    isNormalUser = true;
    description = "Jamie";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    #  thunderbird
    ];
  };

hardware.bluetooth = {
  enable = true;
  powerOnBoot = true; 
};

# Optional: provides blueman-applet and blueman-manager for a system tray GUI
services.blueman.enable = true; 

 

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  #notis
services.dunst.enable = true;


#services.displayManager.defaultSession = "hyprland";
programs.hyprland.enable = true;

   # Flatpak
services.flatpak.enable = true;

#emojis
i18n.inputMethod = {
  enable = false;
  type = "ibus";
};




  # Fonts for Waybar icons (workspace glyphs, volume/network/battery
  # symbols) — these are icon-font glyphs, not emoji, so they need one of
  # these installed and referenced by name in ~/.config/waybar/style.css.
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
  ];
  fonts.fontconfig.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
hyprland
hyprpaper
waybar
rofi
nwg-look
vim
fastfetch
kitty
figlet
vesktop
bibata-cursors
btop
quickshell
pavucontrol
cava
cmatrix
lavat
tty-clock
ani-cli
nautilus
mpvpaper
mpv
hyprlock
grim
slurp
wine
linux-wallpaperengine
afetch
bfetch
pfetch
fetchFlake.packages.${pkgs.system}.default
firefox
usbutils
unrar
noto-fonts-color-emoji
emote
dunst
proton-vpn
wireguard-tools
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}


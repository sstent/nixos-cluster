{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  services.samba.openFirewall = true;

  #services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  networking.firewall.allowedTCPPorts = [
    5357 # wsdd
  ];
  networking.firewall.allowedUDPPorts = [
    3702 # wsdd
  ];

  systemd.tmpfiles.rules = [
    "d /shares/Public 0777 root root - -"
  ];

  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = smbnix
      netbios name = smbnix
      disable netbios = yes
      security = user
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      hosts allow = 192.168.1. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
    '';
    shares = {
      public = {
        path = "/shares/Public";
        browseable = "no";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "samba-guest";
        "force group" = "samba-guest";
      };
    };
  };

  users.users.samba-guest = {
    isSystemUser = true;
    description = "Residence of our Samba guest users";
    group = "samba-guest";
    home = "/var/empty";
    createHome = false;
    shell = pkgs.shadow;
  };
  users.groups.samba-guest = {};
}

{ lib, pkgs, config, inputs,  ... }: {


systemd.services.setleds = {
  script = ''
    echo "Setting Odroid LEDs"
    echo none > /sys/class/leds/blue\:heartbeat/trigger
    cat /sys/class/leds/blue\:heartbeat/trigger
  '';
  wantedBy = [ "multi-user.target" ];
};

}
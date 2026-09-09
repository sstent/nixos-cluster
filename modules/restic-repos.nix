# Cluster-wide resticprofile repository mixins.
# Import this module on any host that should have access to the cluster backup repos.
# Each host then selects which repos to use by defining `custom.resticprofile.profiles`
# with `inherit = "repo-<name>"`.
{
  config,
  lib,
  ...
}: {
  # Expose both cluster repo passwords as sops secrets.
  # Only the repo mixins a host actually uses will be referenced, but having
  # the secrets available on all cluster nodes is harmless and simplifies the
  # module boundary.
  sops.secrets."restic_password" = {};
  sops.secrets."restic_password_odroid7" = {};

  custom.resticprofile.repositories = {
    # Restserver running on the PR2100 NAS
    repo-pr2100 = {
      repository = "rest:http://192.168.4.109:8888";
      password-file = config.sops.secrets."restic_password".path;
      retention = {
        keep-daily = 7;
        keep-weekly = 4;
        keep-monthly = 12;
        group-by = "host,paths";
      };
    };

    # Local SFTP target on odroid7's external USB drive
    repo-odroid7 = {
      repository = "sftp:root@192.168.4.227:/mnt/EXTDrive1/_RESTICDATA";
      password-file = config.sops.secrets."restic_password_odroid7".path;
      retention = {
        keep-daily = 7;
        keep-weekly = 4;
        keep-monthly = 12;
        group-by = "host,paths";
      };
    };
  };
}

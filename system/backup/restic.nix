{ ... }:

{
  systemd.tmpfiles.rules = [
    "z /etc/secrets/restic-password 0600 root root"
    "z /etc/secrets/restic.env 0600 root root"
  ];

  services.restic.backups.server = {
    repository = "s3:https://tsiru-pet-backups.us-east-1.linodeobjects.com";

    environmentFile = "/etc/secrets/restic.env";

    passwordFile = "/etc/secrets/restic-password";

    initialize = true;

    paths = [
      "/etc/secrets"

      "/var/backup/stalwart"

      "/var/lib/bulwark/admin"
      "/var/lib/bulwark/state"

      "/srv/calibre"
      "/var/lib/calibre-server"
      "/var/lib/calibre-web"

      "/var/lib/linkstack"

      "/var/backup/vaultwarden"
    ];

    pruneOpts = [
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 12"
    ];

    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}

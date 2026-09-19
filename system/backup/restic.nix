{ pkgs, ... }:

{
  services.restic.backups.server = {
    repository = "s3:https://us-east-1.linodeobjects.com/tsiru-pet-backups";

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

  systemd.services.restic-backups-server = {
    requires = [ "stalwart-backup.service" ];
    after = [ "stalwart-backup.service" ];

    unitConfig = {
      OnSuccess = "restic-kuma-success.service";
      OnFailure = "restic-kuma-failure.service";
    };
  };

  systemd.services.restic-kuma-success = {
    description = "Report successful Restic backup to Uptime Kuma";

    serviceConfig = {
      Type = "oneshot";
      LoadCredential = [
        "push-token:/etc/secrets/uptime-kuma-restic-token"
      ];
    };

    script = ''
      token="$(cat "$CREDENTIALS_DIRECTORY/push-token")"

      ${pkgs.curl}/bin/curl \
        --fail \
        --silent \
        --show-error \
        --get \
        --data-urlencode "status=up" \
        --data-urlencode "msg=Backup completed successfully" \
        "http://127.0.0.1:3001/api/push/$token"
    '';
  };

  systemd.services.restic-kuma-failure = {
    description = "Report failed Restic backup to Uptime Kuma";

    serviceConfig = {
      Type = "oneshot";
      LoadCredential = [
        "push-token:/etc/secrets/uptime-kuma-restic-token"
      ];
    };

    script = ''
      token="$(cat "$CREDENTIALS_DIRECTORY/push-token")"

      ${pkgs.curl}/bin/curl \
        --fail \
        --silent \
        --show-error \
        --get \
        --data-urlencode "status=down" \
        --data-urlencode "msg=Backup failed" \
        "http://127.0.0.1:3001/api/push/$token"
    '';
  };

  systemd.tmpfiles.rules = [
    "z /etc/secrets/uptime-kuma-restic-token 0600 root root"

    "z /etc/secrets/restic-password 0600 root root"
    "z /etc/secrets/restic.env 0600 root root"
  ];
}

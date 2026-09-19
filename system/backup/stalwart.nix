{ pkgs, lib, domain, ... }:

let
  backupDir = "/var/backup/stalwart";
  accounts = [
    "tsiru@${domain}"
    "jordanaq@${domain}"
    "vault@${domain}"
  ];
in {
  systemd.tmpfiles.rules = [
    "d ${backupDir} 0700 root root -"
  ];

  systemd.services.stalwart-backup = {
    description = "Back up Stalwart data";

    after = [ "stalwart.service" ];
    requires = [ "stalwart.service" ];

    serviceConfig = {
      Type = "oneshot";
      LoadCredential = [
        "password:/etc/secrets/stalwart-admin-password"
      ];
    };

    script = ''
      set -euo pipefail

      export VANDELAY_PASSWORD = "$(cat "CREDENTIALS_DIRECTORY/password")"

      ${lib.concatMapStringsSep "\n" (account: ''
      ${pkgs.stalwart-vandelay}/bin/vandelay import jmap \
        --url "https://mail.${domain}" \
        --auth-basic admin \
        --account-name "${account}" \
        "/var/backup/stalwart/${builtins.head (lib.splitString "@" account)}.sqlite"
    '') accounts}
    '';
  };
}

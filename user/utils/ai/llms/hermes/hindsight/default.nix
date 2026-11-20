{ config, lib, pkgs, ... }:

let
  # Hindsight memory provider (local-embedded daemon) runs from a user venv,
  # since the Nix-store Hermes package is read-only and cannot pip-install
  # hindsight-all into its own site-packages. That venv is Python 3.12 while
  # the Hermes runtime is Python 3.14, so it must NEVER be added to a Hermes
  # process's PYTHONPATH — see the note in the hermes-gateway service below.
  # The venv is still referenced directly (pg0 CLI, standalone tooling) by
  # absolute path, which is version-safe.
  # hindsight-all pulls in torch/tokenizers which need Nix's libstdc++/zlib on
  # the linker path (same class of fix as AGENT_BROWSER_EXECUTABLE_PATH).
  hindsightVenv = "${config.home.homeDirectory}/.local/share/hermes-hindsight-venv";
  hindsightLdLibraryPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc
    pkgs.zlib
  ];

  # Hindsight's local-embedded daemon uses pg0-embedded, a dynamically-linked
  # generic-Linux CLI that NixOS refuses to exec (stub-ld interpreter). Worse,
  # the `pg0 start` it drives spawns the real PostgreSQL 18.1 server binaries
  # (initdb/pg_ctl/postgres/psql) which are the same class of generic ELF.
  # buildFHSEnv provides a real /lib64/ld-linux-x86-64.so.2 and the shared
  # libs pg0+postgres need (verified empirically: glibc, zstd, lz4, openssl,
  # krb5, zlib, tzdata for the zoneinfo dir, readline for psql). runScript is
  # the real pg0 ELF (copied to pg0.real by hindsightPg0Fhs activation) so
  # args pass straight through to it inside the FHS namespace; its child
  # postgres/psql processes inherit the namespace and find the libs too.
  # N.B. runScript must NOT be the pg0 symlink itself, or it recurses.
  pg0RealBin = "${hindsightVenv}/lib/python3.12/site-packages/pg0/bin/pg0.real";
  pg0Fhs = pkgs.buildFHSEnv {
    name = "pg0-fhs";
    targetPkgs = p: [
      p.glibc
      p.zstd
      p.lz4
      p.openssl
      p.krb5
      p.zlib
      p.tzdata
      p.readline
    ];
    runScript = pg0RealBin;
  };
in {
  # Point Hindsight's embedded-Postgres launcher (pg0) at the FHS wrapper so
  # the pg0 python package's `_find_pg0()` picks it up. `_find_pg0()` always
  # prefers the bundled `pg0/bin/pg0`, so we (1) back up that real ELF to
  # pg0.real and (2) symlink pg0 → the buildFHSEnv wrapper. pg0Fhs.runScript
  # execs pg0.real (never the symlink), avoiding recursion. Idempotent: only
  # copies once (when pg0.real is absent and pg0 is still a real ELF), and the
  # `ln -sfn` is harmless on re-runs.
  home.activation.hindsightPg0Fhs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    pg0_bin_dir="${hindsightVenv}/lib/python3.12/site-packages/pg0/bin"
    if [ -f "$pg0_bin_dir/pg0" ] && [ ! -e "$pg0_bin_dir/pg0.real" ]; then
      cp "$pg0_bin_dir/pg0" "$pg0_bin_dir/pg0.real"
    fi
    if [ -e "$pg0_bin_dir/pg0.real" ]; then
      ln -sfn "${pg0Fhs}/bin/pg0-fhs" "$pg0_bin_dir/pg0"
    fi
  '';

  home.packages = [
    # uv/uvx: needed by Hindsight's local-embedded daemon which launches via
    # `uvx hindsight-api@<version> --daemon`. Installed in the user profile so
    # both interactive shells and the gateway service (which inherits
    # ~/.nix-profile/bin on PATH) can find uvx.
    pkgs.uv
    # FHS-wrapped pg0 (Hindsight's embedded Postgres launcher) — exposed on
    # PATH so the wrapper can be smoke-tested by hand. The bundled
    # pg0/bin/pg0 symlink also points here via the hindsightPg0Fhs activation.
    pg0Fhs
  ];

  home.file.".hermes/hindsight/config.json".source = ./config.json;

  systemd.user.services.hermes-gateway.Service.Environment = lib.mkAfter [
    # NOTE: do NOT put the hindsight venv on this service's PYTHONPATH.
    # The venv is Python 3.12; the Hermes runtime is Python 3.14 (since the
    # 2026-10-01 hermes-agent bump). PYTHONPATH is prepended ahead of the
    # runtime's own site-packages, so shared pure-Python packages resolve to
    # their 3.12 copies and compiled extensions fail to load — e.g.
    # `ModuleNotFoundError: No module named 'pydantic_core._pydantic_core'`,
    # which killed every agent-mode cron job (all jobs failed at OpenAI
    # client init for ~10 days). The hindsight memory plugin was also
    # uninstalled from ~/.hermes/plugins, so nothing needs this path.
    # If hindsight is reinstalled, rebuild the venv on the SAME Python
    # version as the runtime (python3.14) instead of re-adding PYTHONPATH.
    # hindsight-all (torch/tokenizers) needs Nix's libstdc++/zlib on the
    # linker path to import on NixOS.
    "LD_LIBRARY_PATH=${hindsightLdLibraryPath}"
  ];
}

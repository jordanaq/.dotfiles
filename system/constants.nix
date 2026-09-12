# Shared constants exposed to every system module via `_module.args`.
# Imported once from system/configuration.nix; any module may then take
# `domain` (or `uname`) as a function argument, e.g. `{ domain, ... }:`.
{ ... }:

{
  _module.args.domain = "tsiru.pet";
  _module.args.uname = "tsiru";
}

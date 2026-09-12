# Shared constants exposed to every system module via `_module.args`.
# Imported once from system/configuration.nix; any module may then take
# `domain` as a function argument, e.g. `{ domain, ... }:`.
{ ... }:

{
  _module.args.domain = "tsiru.pet";
}

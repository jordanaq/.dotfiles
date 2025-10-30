{ config, pkgs, nixvirt, ... }:
{
  virtualisation.libvirt.connections."qemu:///session".domains = [
    {
      definition = nixvirt.lib.domain.writeXML (
          nixvirt.lib.domain.templates.linux {
            name = "NixEqEmuVM";
            uuid = "01234567-89ab-cdef-0123-456789abcdef";
            memory = { count = 4; unit = "GiB"; };
            vcpu = 2;
            storage_vol = { pool = "UserPool"; volume = "NixEqEmuVM.qcow2"; };
            backing_vol = /home/tsiru/VMBases/nixos-base.qcow2;
          }
        );
      active = true;
      restart = true;
    }
  ];
}

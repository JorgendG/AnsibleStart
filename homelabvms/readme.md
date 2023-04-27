# homelabvms

Create VM defined in a yml file

```yaml
vms:
  - name: answin1101
    cpu: 2
    memory: 4096MB
    diskpath: c:\vhdx\answin1101.vhdx
    unattend: installwin11ans.xml
    vmhost: hyperdrive
    network_switch: External

  - name: answin1102
    cpu: 2
    memory: 4096MB
    diskpath: c:\vhdx\answin1102.vhdx
    unattend: installwin11ans.xml
    vmhost: nuc12
    network_switch: External
```

The VMs are created on the vmhost and a WDS registration/Prestaged Device is created. The WDS registration points to a unattended file which selects the desired OS.
Starting the VM makes it start the WDS deployment. The VM should be running in about 5 minutes.

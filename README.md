# meta-readonly-overlayfs
This yocto layer provides a readonly overlay filesystem, without the need of an initrd or initramfs image. First the kernel mounts the default (root) filesystem, which is later mounted as lower layer. The readonly and writeable root is mounted on a tmpfs, which will be unmounted at the end of the init script. After the overlayfs has been mounted, the previous mounts are cleaned up or moved to the new root. Finally, the root is switched (pivot_root) over to the overlay filesystem.

# Setup
add path to build/conf/bblayers.conf
  `path/to/meta-readonly-overlayfs` 
  
add recipe to your image
  `IMAGE_INSTALL_append = "init-readonly-overlayfs"`
  
modify your kernel command line like this \
  `init=/sbin/init-readonly-overlayfs overlay.mount=/dev/ubi0_7`\
or set filesystem type \
  `init=/sbin/init-readonly-overlayfs overlay.mount=ubi0:volume overlay.type=ubifs`

# Parameter
 * `overlay.mount=` holds the upper file system mount and is mandatory. Fallback to tmpfs is currently not supported
 * `overlay.type=` optional parameter which specifies the filefystem type. If not set `overlay.mount` should be a device.
 * `overlay.factorydefault=` pass script to factory default variable which is able to clear the upper layer. One should implement the function `factory_default` in the passed script.

# References
The code in this layer is based on the following projects:
* https://www.linuxquestions.org/questions/linuxquestions-org-member-success-stories-23/a-readonly-rootfs-with-a-writeable-overlay-without-an-initramfs-4175639487/
* https://github.com/kernelconcepts/meta-readonly-rootfs-overlay
* https://github.com/josepsanzcamp/root-ro
* https://gist.github.com/niun/34c945d70753fc9e2cc7


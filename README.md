# meta-readonly-overlayfs
This yocto layer provides a readonly overlay filesystem, without the need of initrd/initramfs image.

# Setup
add path to build/conf/bblayers.conf
  `path/to/meta-readonly-overlayfs` 
  
add recipe to your image
  `IMAGE_INSTALL_append = "init-readonly-overlayfs"`
  
modify your kernel command line
  `init=/sbin/init-readonly-overlayfs overlay.mount=/dev/ubi0_7`

# References
The code in this layer is based on the following projects:
* https://www.linuxquestions.org/questions/linuxquestions-org-member-success-stories-23/a-readonly-rootfs-with-a-writeable-overlay-without-an-initramfs-4175639487/
* https://github.com/kernelconcepts/meta-readonly-rootfs-overlay
* https://github.com/josepsanzcamp/root-ro
* https://gist.github.com/niun/34c945d70753fc9e2cc7


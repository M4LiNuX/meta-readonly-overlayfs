SUMMARY = "Read only rootfs with overlay init script"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "file://init-readonly-overlayfs.sh \
          "

S = "${WORKDIR}"

DEPENDS = "virtual/kernel"

do_install() {
    install -d ${D}/${base_sbindir}
    install -m 0744 ${WORKDIR}/init-readonly-overlayfs.sh ${D}/${base_sbindir}/init-readonly-overlayfs
    install -d ${D}/mnt/ro
    install -d ${D}/mnt/rw
}

FILES_${PN} = "${base_sbindir} /mnt"

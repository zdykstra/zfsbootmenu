#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

version="${1?ERROR: no release version specified}"
TEMP="${2?ERROR: no temporary directory specified}"

if [ ! -d /usr/lib/dracut ]; then
  echo "ERROR: missing /usr/lib/dracut"
  exit 1
fi

DRACUTBIN="$( command -v dracut )"
if [ ! -x "${DRACUTBIN}" ]; then
  echo "ERROR: missing dracut script"
  exit 1
fi

echo "Creating images in ${TEMP}"

cp -a /usr/lib/dracut "${TEMP}"
cp "${DRACUTBIN}" "${TEMP}/dracut"

_dracut_mods="${TEMP}/dracut/modules.d"
test -d "${_dracut_mods}" && rm -rf "${_dracut_mods}/90zfsbootmenu"
ln -s "$(realpath -e 90zfsbootmenu)" "${_dracut_mods}"

ln -s "$(realpath -e bin/generate-zbm)" "${TEMP}/generate-zbm"

yamlconf="${TEMP}/local.yaml"
cp etc/zfsbootmenu/config.yaml "${yamlconf}"

yq-go eval ".Components.Enabled = false" -i "${yamlconf}"
yq-go eval ".EFI.Enabled = true" -i "${yamlconf}"
yq-go eval ".EFI.Versions = false" -i "${yamlconf}"
yq-go eval ".EFI.ImageDir = \"${TEMP}/release\"" -i "${yamlconf}"
yq-go eval ".Global.ManageImages = true" -i "${yamlconf}"
yq-go eval ".Global.DracutConfDir = \"${TEMP}/dracut.conf.d\"" -i "${yamlconf}"
yq-go eval ".Global.DracutFlags = [ \"--local\" ]" -i "${yamlconf}"
yq-go eval "del(.Global.BootMountPoint)" -i "${yamlconf}"

(
  "${TEMP}/generate-zbm" \
    --version "${version}" \
    --config "${yamlconf}" \
    --cmdline="zbm.import_policy=hostid zbm.set_hostid rd.hostonly=0 loglevel=4 nomodeset"
) >/dev/null 2>&1

mv "${TEMP}/release/vmlinuz.EFI" "${TEMP}/release/zfsbootmenu-${version}.EFI"

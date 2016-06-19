#!/bin/bash

# Uncomment to debug
set -xe

# Kalabox things
KBOX_VERSION=$(node -pe 'JSON.parse(process.argv[1]).version' "$(cat package.json)")
INSTALLER_VERSION="$KBOX_VERSION"
KALABOX_CLI_VERSION="$KBOX_VERSION"
KALABOX_GUI_VERSION="0.12.16"
KALABOX_IMAGE_VERSION="v0.12"

# Docker things
DOCKER_MACHINE_VERSION="0.7.0"
DOCKER_COMPOSE_VERSION="1.7.1"
BOOT2DOCKER_ISO_VERSION="1.11.2"

# VirtualBox Things
VBOX_VERSION="5.0.20"
VBOX_REVISION="106931"

# Syncthing things
SYNCTHING_VERSION="0.11.26"

# Start up our build directory and go into it
mkdir -p build/installer
cd build/installer

# Get our Kalabox dependencies
cp -rf "../../dist/cli/kbox-osx-x64-v${KALABOX_CLI_VERSION}" kbox
curl -fsSL -o /tmp/kalabox-gui.tar.gz "https://github.com/kalabox/kalabox-ui/releases/download/v$KALABOX_GUI_VERSION/kalabox-ui-osx64-v$KALABOX_GUI_VERSION.tar.gz" && \
  tar -xzf /tmp/kalabox-gui.tar.gz && \
  cp -rf Kalabox/Kalabox.app Kalabox.app && \
  rm -rf Kalabox
curl -fsSL -o services.yml "https://raw.githubusercontent.com/kalabox/kalabox-cli/$KALABOX_IMAGE_VERSION/plugins/kalabox-services-kalabox/kalabox-compose.yml"
curl -fsSL -o syncthing.yml "https://raw.githubusercontent.com/kalabox/kalabox-cli/$KALABOX_IMAGE_VERSION/plugins/kalabox-sharing/kalabox-compose.yml"
chmod +x kbox

# Get our Docker dependencies
curl -fsSL -o docker-compose "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-Darwin-x86_64"
curl -fsSL -o docker-machine "https://github.com/docker/machine/releases/download/v$DOCKER_MACHINE_VERSION/docker-machine-Darwin-x86_64"
curl -fsSL -o boot2docker.iso "https://github.com/boot2docker/boot2docker/releases/download/v$BOOT2DOCKER_ISO_VERSION/boot2docker.iso"
chmod +x docker-compose
chmod +x docker-machine

# Get Virtualbox
curl -fsSL -o vbox.dmg "http://download.virtualbox.org/virtualbox/$VBOX_VERSION/VirtualBox-$VBOX_VERSION-$VBOX_REVISION-OSX.dmg" && \
  mkdir -p /tmp/kalabox/vb && \
  hdiutil attach -mountpoint /tmp/kalabox/vb vbox.dmg && \
  cp -rf /tmp/kalabox/vb/VirtualBox.pkg /tmp/VirtualBox.pkg && \
  xar -xf /tmp/VirtualBox.pkg && \
  hdiutil detach -force /tmp/kalabox/vb && \
  rm -f vbox.dmg && \
  rm -rf Resources

# Download the syncthing parts
curl -fsSL -o config.xml "https://raw.githubusercontent.com/kalabox/kalabox-cli/$KALABOX_IMAGE_VERSION/plugins/kalabox-sharing/dockerfiles/syncthing/config.xml"
curl -fsSL -o /tmp/syncthing.tar.gz "http://archive.syncthing.net/v$SYNCTHING_VERSION/syncthing-macosx-amd64-v$SYNCTHING_VERSION.tar.gz" && \
  tar -xzvf /tmp/syncthing.tar.gz && \
  chmod +x syncthing-macosx-amd64-v$SYNCTHING_VERSION/syncthing && \
  cp -rf syncthing-macosx-amd64-v$SYNCTHING_VERSION/syncthing syncthing && \
  rm -rf syncthing-macosx-amd64-v$SYNCTHING_VERSION

# Start to assemble the package
mkdir -p mpkg
mv *.pkg mpkg/

# Add Distrib file
cp -rf osx/mpkg/Distribution mpkg/Distribution

# Add dockermachine.pkg
cp -rf osx/mpkg/dockermachine.pkg mpkg/dockermachine.pkg
cd mpkg/dockermachine.pkg && \
  mkdir rootfs && \
  cd rootfs && \
  mkdir -p tmp && \
  mv ../../../docker-machine tmp/ && \
  ls -al tmp/ && \
  find . | cpio -o --format odc | gzip -c > ../Payload && \
  mkbom . ../Bom && \
  sed -i "" \
    -e "s/%DOCKERMACHINE_NUMBER_OF_FILES%/`find . | wc -l`/g" \
    ../PackageInfo && \
  sed -i "" \
    -e "s/%DOCKERMACHINE_INSTALL_KBYTES%/`du -sk | cut -f1`/g" \
    ../PackageInfo ../../Distribution && \
  sed -i "" \
    -e "s/%DOCKERMACHINE_VERSION%/$DOCKER_MACHINE_VERSION/g" \
    ../PackageInfo ../../Distribution && \
  cd .. && \
  rm -rf rootfs && \
  cd ../..

# Add dockercompose.pkg
cp -rf osx/mpkg/dockercompose.pkg mpkg/dockercompose.pkg
cd mpkg/dockercompose.pkg && \
  mkdir rootfs && \
  cd rootfs && \
  mkdir -p tmp && \
  mv ../../../docker-compose tmp/ && \
  ls -al tmp/ && \
  find . | cpio -o --format odc | gzip -c > ../Payload && \
  mkbom . ../Bom && \
  sed -i "" \
    -e "s/%DOCKERCOMPOSE_NUMBER_OF_FILES%/`find . | wc -l`/g" \
    ../PackageInfo && \
  sed -i "" \
    -e "s/%DOCKERCOMPOSE_INSTALL_KBYTES%/`du -sk | cut -f1`/g" \
    ../PackageInfo ../../Distribution && \
  sed -i "" \
    -e "s/%DOCKERCOMPOSE_VERSION%/$DOCKER_COMPOSE_VERSION/g" \
    ../PackageInfo ../../Distribution && \
  cd .. && \
  rm -rf rootfs && \
  cd ../..

# Add boot2dockeriso.pkg
cp -rf osx/mpkg/boot2dockeriso.pkg mpkg/boot2dockeriso.pkg
cd mpkg/boot2dockeriso.pkg && \
  cd Scripts && find . | cpio -o --format odc | gzip -c > ../Scripts.bin && cd .. && \
  rm -r Scripts && mv Scripts.bin Scripts && \
  mkdir ./rootfs && \
  cd ./rootfs && \
  mv ../../../boot2docker.iso . && \
  find . | cpio -o --format odc | gzip -c > ../Payload && \
  mkbom . ../Bom && \
  sed -i "" \
    -e "s/%BOOT2DOCKER_ISO_NUMBER_OF_FILES%/`find . | wc -l`/g" \
    ../PackageInfo && \
  sed -i "" \
    -e "s/%BOOT2DOCKER_ISO_INSTALL_KBYTES%/`du -sk | cut -f1`/g" \
    ../PackageInfo ../../Distribution && \
  sed -i "" \
    -e "s/%BOOT2DOCKER_ISO_VERSION%/$BOOT2DOCKER_ISO_VERSION/g" \
    ../PackageInfo ../../Distribution && \
  cd .. && \
  rm -rf rootfs && \
  cd ../..

# engine.pkg
cp -rf osx/mpkg/engine.pkg mpkg/engine.pkg
cd mpkg/engine.pkg && \
  cd Scripts && find . | cpio -o --format odc | gzip -c > ../Scripts.bin && cd .. && \
  rm -r Scripts && mv Scripts.bin Scripts && \
  mkdir ./rootfs && \
  cd ./rootfs && \
  find . | cpio -o --format odc | gzip -c > ../Payload && \
  mkbom . ../Bom && \
  sed -i "" \
    -e "s/%ENGINE_NUMBER_OF_FILES%/`find . | wc -l`/g" \
    ../PackageInfo && \
  sed -i "" \
    -e "s/%ENGINE_INSTALL_KBYTES%/`du -sk | cut -f1`/g" \
    ../PackageInfo ../../Distribution && \
  sed -i "" \
    -e "s/%ENGINE_VERSION%/$BOOT2DOCKER_ISO_VERSION/g" \
    ../PackageInfo ../../Distribution && \
  cd .. && \
  rm -rf rootfs && \
  cd ../..

# services.pkg
cp -rf osx/mpkg/services.pkg mpkg/services.pkg
cd mpkg/services.pkg && \
  cd Scripts && find . | cpio -o --format odc | gzip -c > ../Scripts.bin && cd .. && \
  rm -r Scripts && mv Scripts.bin Scripts && \
  mkdir ./rootfs && \
  cd ./rootfs && \
  mkdir -p tmp && \
  mv ../../../syncthing.yml tmp/ && \
  mv ../../../services.yml tmp/ && \
  ls -al tmp/ && \
  find . | cpio -o --format odc | gzip -c > ../Payload && \
  mkbom . ../Bom && \
  sed -i "" \
    -e "s/%SERVICES_NUMBER_OF_FILES%/`find . | wc -l`/g" \
    ../PackageInfo && \
  sed -i "" \
    -e "s/%SERVICES_INSTALL_KBYTES%/`du -sk | cut -f1`/g" \
    ../PackageInfo ../../Distribution && \
  sed -i "" \
    -e "s/%SERVICES_VERSION%/$KALABOX_IMAGE_VERSION/g" \
    ../PackageInfo ../../Distribution && \
  cd .. && \
  rm -rf rootfs && \
  cd ../..

# kbox.pkg
cp -rf osx/mpkg/kbox.pkg mpkg/kbox.pkg
cp -rf osx/uninstall.sh uninstall.sh
cd mpkg/kbox.pkg && \
  mkdir rootfs && \
  cd rootfs && \
  mkdir -p usr/local/bin && \
  mv ../../../kbox usr/local/bin/ && \
  mv ../../../uninstall.sh usr/local/bin/kalabox-uninstall.sh && \
  ls -al /usr/local/bin/ && \
  find . | cpio -o --format odc | gzip -c > ../Payload && \
  mkbom . ../Bom && \
  sed -i "" \
    -e "s/%KBOXCLI_NUMBER_OF_FILES%/`find . | wc -l`/g" \
    ../PackageInfo && \
  sed -i "" \
    -e "s/%KBOXCLI_INSTALL_KBYTES%/`du -sk | cut -f1`/g" \
    ../PackageInfo ../../Distribution && \
  sed -i "" \
    -e "s/%KBOXCLI_VERSION%/$KALABOX_CLI_VERSION/g" \
    ../PackageInfo ../../Distribution && \
  cd .. && \
  rm -rf rootfs && \
  cd ../..

# kbox-gui.pkg
cp -rf osx/mpkg/kbox-gui.pkg mpkg/kbox-gui.pkg
cd mpkg/kbox-gui.pkg && \
  mkdir ./rootfs && \
  cd ./rootfs && \
  mv ../../../Kalabox.app . && \
  ls -al . && \
  find . | cpio -o --format odc | gzip -c > ../Payload && \
  mkbom . ../Bom && \
  sed -i "" \
    -e "s/%KBOXGUI_NUMBER_OF_FILES%/`find . | wc -l`/g" \
    ../PackageInfo && \
  sed -i "" \
    -e "s/%KBOXGUI_INSTALL_KBYTES%/`du -sk | cut -f1`/g" \
    ../PackageInfo ../../Distribution && \
  sed -i "" \
    -e "s/%KBOXGUI_VERSION%/$KALABOX_GUI_VERSION/g" \
    ../PackageInfo ../../Distribution && \
  cd .. && \
  rm -rf rootfs && \
  cd ../..

# syncthing.pkg
cp -rf osx/mpkg/syncthing.pkg mpkg/syncthing.pkg
cd mpkg/syncthing.pkg && \
  cd Scripts && find . | cpio -o --format odc | gzip -c > ../Scripts.bin && cd .. && \
  rm -r Scripts && mv Scripts.bin Scripts && \
  mkdir rootfs && \
  cd rootfs && \
  mkdir -p tmp && \
  mv ../../../syncthing tmp/ && \
  mv ../../../config.xml tmp/ && \
  ls -al tmp/ && \
  find . | cpio -o --format odc | gzip -c > ../Payload && \
  mkbom . ../Bom && \
  sed -i "" \
    -e "s/%SYNCTHING_NUMBER_OF_FILES%/`find . | wc -l`/g" \
    ../PackageInfo && \
  sed -i "" \
    -e "s/%SYNCTHING_INSTALL_KBYTES%/`du -sk | cut -f1`/g" \
    ../PackageInfo ../../Distribution && \
  sed -i "" \
    -e "s/%SYNCTHING_VERSION%/$SYNCTHING_VERSION/g" \
    ../PackageInfo ../../Distribution && \
  cd .. && \
  rm -rf rootfs && \
  cd ../..

# Copy the metas
cp -rf osx/mpkg/Resources mpkg/Resources
cp -rf osx/mpkg/Plugins mpkg/Plugins

# Add in more version info
sed -i "" -e "s/%INSTALLER_VERSION%/$INSTALLER_VERSION/g" mpkg/Resources/en.lproj/welcome.rtfd/TXT.rtf
sed -i "" -e "s/%VBOX_VERSION%/$VBOX_VERSION/g" Distribution
sed -i "" -e "s/%VBOX_VERSION%/$VBOX_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings
sed -i "" -e "s/%DOCKERMACHINE_VERSION%/$DOCKER_MACHINE_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings
sed -i "" -e "s/%DOCKERCOMPOSE_VERSION%/$DOCKER_COMPOSE_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings
sed -i "" -e "s/%BOOT2DOCKER_ISO_VERSION%/$BOOT2DOCKER_ISO_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings
sed -i "" -e "s/%KBOXCLI_VERSION%/$KALABOX_CLI_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings
sed -i "" -e "s/%KBOXGUI_VERSION%/$KALABOX_GUI_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings
sed -i "" -e "s/%SYNCTHING_VERSION%/$SYNCTHING_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings
sed -i "" -e "s/%ENGINE_VERSION%/$SYNCTHING_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings
sed -i "" -e "s/%SERVICES_VERSION%/$KALABOX_IMAGE_VERSION/g" mpkg/Resources/en.lproj/Localizable.strings

# Build the package
mkdir -p dmg && mkdir -p dist && \
  xar -c --compression=none -f dmg/KalaboxInstaller.pkg mpkg/ && \
  cp -rf osx/uninstall.sh dmg/uninstall.sh && \
  cp -rf osx/kalabox.icns dmg/.VolumeIcon.icns
  cp -rf ../../README.md dmg/README.md && \
  cp -rf ../../TERMS.md dmg/TERMS.md && \
  cp -rf ../../LICENSE.md dmg/LICENSE.md && \
  cp -rf ../../ORACLE_VIRTUALBOX_LICENSE dmg/ORACLE_VIRTUALBOX_LICENSE && \
  cp -rf ../../SYNCTHING_LICENSE dmg/SYNCTHING_LICENSE && \
  hdiutil create -volname Kalabox -srcfolder dmg -ov -format UDZO dist/kalabox.dmg
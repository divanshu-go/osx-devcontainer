#!/bin/bash
set -e

# Ensure BaseSystem.img exists
if ! [[ -e "${BASESYSTEM_IMAGE:-BaseSystem.img}" ]]; then
    echo "No BaseSystem.img available, downloading ${SHORTNAME}"
    make
    qemu-img convert BaseSystem.dmg -O qcow2 -p -c "${BASESYSTEM_IMAGE:-BaseSystem.img}"
    rm ./BaseSystem.dmg
fi

echo "${BOILERPLATE}"

[[ "${TERMS_OF_USE}" = i_agree ]] || exit 1

echo "Disk is being copied between layers... Please wait a minute..."
sudo touch /dev/kvm /dev/snd "${IMAGE_PATH}" "${BOOTDISK}" "${ENV}" 2>/dev/null || true
sudo chown -R "$(id -u):$(id -g)" /dev/kvm /dev/snd "${IMAGE_PATH}" "${BOOTDISK}" "${ENV}" 2>/dev/null || true

if [[ "${NOPICKER}" == true ]]; then
    sed -i '/^.*InstallMedia.*/d' Launch.sh
    export BOOTDISK="${BOOTDISK:=/home/arch/OSX-KVM/OpenCore/OpenCore-nopicker.qcow2}"
else
    export BOOTDISK="${BOOTDISK:=/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2}"
fi

if [[ "${GENERATE_UNIQUE}" == true ]]; then
    ./Docker-OSX/osx-serial-generator/generate-unique-machine-values.sh \
        --master-plist-url="${MASTER_PLIST_URL}" \
        --count 1 \
        --tsv ./serial.tsv \
        --bootdisks \
        --width "${WIDTH:-1920}" \
        --height "${HEIGHT:-1080}" \
        --output-bootdisk "${BOOTDISK}" \
        --output-env "${ENV}" || exit 1
fi

if [[ "${GENERATE_SPECIFIC}" == true ]]; then
    source "${ENV}" 2>/dev/null || true
    ./Docker-OSX/osx-serial-generator/generate-specific-bootdisk.sh \
        --master-plist-url="${MASTER_PLIST_URL}" \
        --model "${DEVICE_MODEL}" \
        --serial "${SERIAL}" \
        --board-serial "${BOARD_SERIAL}" \
        --uuid "${UUID}" \
        --mac-address "${MAC_ADDRESS}" \
        --width "${WIDTH:-1920}" \
        --height "${HEIGHT:-1080}" \
        --output-bootdisk "${BOOTDISK}" || exit 1
fi

if [[ "${DISPLAY}" = ':99' ]] || [[ "${HEADLESS}" == true ]]; then
    nohup Xvfb :99 -screen 0 1920x1080x16 &
    until xrandr --query 2>/dev/null; do sleep 1; done
fi

stat "${IMAGE_PATH}"
echo "Large image is being copied between layers, please wait a minute..."
./enable-ssh.sh

if ! [[ -e ~/.ssh/id_docker_osx ]]; then
    ssh-keygen -t rsa -f ~/.ssh/id_docker_osx -q -N ""
    chmod 600 ~/.ssh/id_docker_osx
fi

/bin/bash -c ./Launch.sh &

echo "Booting Docker-OSX in the background. Please wait..."
until sshpass -p"${PASSWORD:-alpine}" ssh-copy-id -f -i ~/.ssh/id_docker_osx.pub -p 10022 "${USERNAME:-user}@127.0.0.1"; do
    echo "Disk is being copied between layers. Repeating until able to copy SSH key into OSX..."
    sleep 1
done

if ! grep -q id_docker_osx ~/.ssh/config; then
    cat >>~/.ssh/config <<EOF
Host 127.0.0.1
    User ${USERNAME:-user}
    Port 10022
    IdentityFile ~/.ssh/id_docker_osx
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
fi

echo 'Default username: user'
echo 'Default password: alpine'
echo 'Change it immediately using the command: passwd'
ssh -i ~/.ssh/id_docker_osx "${USERNAME:-user}@127.0.0.1" -p 10022 "${OSX_COMMANDS}"

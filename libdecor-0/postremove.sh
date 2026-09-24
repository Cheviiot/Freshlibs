#!/bin/bash

# Stapler maps this script to RPM %postun. RPM runs it on a final removal AND
# as part of an upgrade, when the previous version is erased after the new one
# is installed; the argument is the number of instances still installed, so it
# is 0 only on a real removal.
#
# rpm runs this through /bin/sh regardless of the shebang; POSIX-safe only.
#
# No `set -e`: see postinstall.sh.
set -u

remaining="${1:-0}"

if command -v ldconfig >/dev/null 2>&1; then
	ldconfig || echo "Предупреждение: не удалось обновить кэш загрузчика (ldconfig)." >&2
fi

if [ "${remaining}" != 0 ]; then
	exit 0
fi

# This package replaces the system libdecor, so a removal can leave the machine
# with no libdecor at all — and xorg-xwayland and mesa-gears link against it.
# Rather than guessing, check whether some libdecor is still present: apt may
# have reinstalled the ALT one in the same transaction.
for libdir in /usr/lib64 /usr/lib; do
	if [ -e "${libdir}/libdecor-0.so.0" ]; then
		exit 0
	fi
done

cat <<'MSG'
Внимание: libdecor удалён полностью, в системе не осталось ни одной версии.
От libdecor-0.so.0 зависят установленные пакеты, в частности xorg-xwayland
и mesa-gears. Верните системную версию из репозиториев ALT:
    apt-get install libdecor-0 libdecor-devel
MSG

exit 0

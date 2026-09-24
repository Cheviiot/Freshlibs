#!/bin/bash
# Stapler maps this script to RPM %postun. RPM runs it on a final removal AND
# while an upgrade erases the previous version; the argument is the number of
# instances still installed, so it is 0 only on a real removal.
#
# rpm runs this through /bin/sh regardless of the shebang; POSIX-safe only.
# No `set -e`: cleanup must never abort a transaction.
set -u

remaining="${1:-0}"

# ALT's rpm refreshes /etc/ld.so.cache by itself for packages carrying shared
# libraries, so this is only an idempotent safety net for installs made outside
# apt.
if command -v ldconfig >/dev/null 2>&1; then
	ldconfig || echo "Предупреждение: не удалось обновить кэш загрузчика (ldconfig)." >&2
fi

if [ "${remaining}" != 0 ]; then
	exit 0
fi

state_dir=/var/lib/freshlibs
list=${state_dir}/libdecor-restore.list
runner=${state_dir}/libdecor-restore

cleanup() {
	rm -f "${list}" "${runner}" 2>/dev/null
	rmdir "${state_dir}" 2>/dev/null
}

# `apt-get install libdecor-0 libdecor-devel` swaps this package for the ALT
# one inside a single transaction, and rpm installs before it erases — so a
# libdecor is already back in place here and there is nothing to restore.
for libdir in /usr/lib64 /usr/lib; do
	if [ -e "${libdir}/libdecor-0.so.0" ]; then
		cleanup
		exit 0
	fi
done

if [ ! -r "${list}" ]; then
	echo "Freshlibs: libdecor удалён, списка для восстановления нет." >&2
	echo "Freshlibs: верните системную версию: apt-get install libdecor-0 libdecor-devel" >&2
	exit 0
fi

# The whole recorded set is handed over as-is, without checking here what is
# still installed: this runs inside the rpm transaction, where the erase order
# is not defined, so a package apt is about to remove can still look installed
# from here. The runner drops what is actually present once the transaction is
# over.
pkgs=$(cat "${list}" 2>/dev/null)

if [ -z "${pkgs}" ]; then
	cleanup
	exit 0
fi

# This scriptlet runs inside the rpm transaction and holds the rpm database
# lock, so it cannot call apt itself. The restore is handed to a transient
# systemd unit that starts after the transaction is over.
if [ -x "${runner}" ] && command -v systemd-run >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
	if systemd-run --collect \
		--unit=freshlibs-restore-libdecor \
		--description='Freshlibs: restore the ALT libdecor' \
		--on-active=10s \
		/bin/sh "${runner}" ${pkgs} >/dev/null 2>&1; then
		echo "Freshlibs: через 10 секунд системные пакеты будут восстановлены: ${pkgs}"
		echo "Freshlibs: ход восстановления — journalctl -u freshlibs-restore-libdecor"
		exit 0
	fi
	echo "Freshlibs: не удалось поставить восстановление в очередь systemd." >&2
fi

echo "Freshlibs: автоматическое восстановление недоступно, выполните вручную:" >&2
echo "    apt-get install ${pkgs}" >&2
exit 0

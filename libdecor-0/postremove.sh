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

# Safety valve on the size of the automatic transaction. Measured envelope for
# libdecor on ALT p11: the reverse-dependency closure over the whole repository
# — every package of p11 installed at once — is 45 packages over 6 levels, and
# only 5 packages depend on the soname directly. A list well past that means
# something this recipe was never measured against (third-party repositories
# with their own libdecor consumers), so the restore stops being automatic and
# hands the decision over instead of running a huge apt transaction unattended.
restore_limit=60
pkg_count=$(printf '%s\n' ${pkgs} | grep -c .)

if [ "${pkg_count}" -gt "${restore_limit}" ]; then
	echo "Freshlibs: восстановление затронуло бы пакетов: ${pkg_count} (порог ${restore_limit}) — автоматически не делаю." >&2
	echo "Freshlibs: список в ${list}, проверьте и выполните вручную:" >&2
	echo "    apt-get install \$(cat ${list})" >&2
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
		/bin/sh "${runner}" restore ${pkgs} >/dev/null 2>&1; then
		echo "Freshlibs: через 10 секунд системные пакеты будут восстановлены: ${pkgs}"
		echo "Freshlibs: ход восстановления — journalctl -u freshlibs-restore-libdecor"
		exit 0
	fi
	echo "Freshlibs: не удалось поставить восстановление в очередь systemd." >&2
fi

echo "Freshlibs: автоматическое восстановление недоступно, выполните вручную:" >&2
echo "    apt-get install ${pkgs}" >&2
exit 0

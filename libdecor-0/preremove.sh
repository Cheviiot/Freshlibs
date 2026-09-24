#!/bin/bash
# Stapler maps this script to RPM %preun: it runs before the package's files
# are removed, while the rpm database still describes the whole system. RPM
# passes the number of instances that will remain: 0 on a real removal, 1 while
# an upgrade erases the previous version.
#
# rpm runs scriptlets through /bin/sh regardless of this shebang, so nothing
# here uses bash-only syntax. No `set -e` either: bookkeeping must never abort
# a transaction.
set -u

remaining="${1:-0}"
if [ "${remaining}" != 0 ]; then
	exit 0
fi

state_dir=/var/lib/freshlibs
list=${state_dir}/libdecor-restore.list
runner_src=/usr/libexec/freshlibs/libdecor-restore
runner=${state_dir}/libdecor-restore

if [ -e /etc/freshlibs/no-auto-restore ]; then
	echo "Freshlibs: автовосстановление отключено (/etc/freshlibs/no-auto-restore)."
	echo "Freshlibs: после удаления в системе не останется libdecor — вернуть: apt-get install libdecor-0 libdecor-devel"
	exit 0
fi

# Everything installed that transitively needs libdecor. `apt-get remove` on
# this package takes that whole set down with it (measured on p11: mesa-gears
# and xorg-xwayland directly, then gnome-session-wayland and i586-steam
# through xorg-xwayland), so that set is exactly what has to come back.
# Breadth-first over rpm's reverse dependencies; the depth cap guards against
# a dependency cycle.
found=""
current='libdecor-0.so.0()(64bit)'
depth=0
while [ -n "${current}" ] && [ "${depth}" -lt 8 ]; do
	depth=$((depth + 1))
	next=""
	for capability in ${current}; do
		for pkg in $(rpm -q --whatrequires "${capability}" --qf '%{NAME}\n' 2>/dev/null); do
			# Skip libdecor itself: this package and the ALT ones it replaces.
			case "${pkg}" in
			libdecor-0 | libdecor-devel | libdecor-0+stplr-*)
				continue
				;;
			esac
			case " ${found} " in
			*" ${pkg} "*)
				continue
				;;
			esac
			found="${found}${pkg} "
			next="${next}${pkg} "
		done
	done
	current="${next}"
done

if ! mkdir -p "${state_dir}" 2>/dev/null; then
	echo "Freshlibs: не удалось создать ${state_dir}, автовосстановление не сработает." >&2
	exit 0
fi

printf 'libdecor-0 libdecor-devel %s\n' "${found}" >"${list}" 2>/dev/null || {
	echo "Freshlibs: не удалось записать ${list}, автовосстановление не сработает." >&2
	exit 0
}

# The runner must outlive this package's own files, which rpm removes next.
if [ -r "${runner_src}" ]; then
	cp -f "${runner_src}" "${runner}" 2>/dev/null && chmod 755 "${runner}" 2>/dev/null
fi

cat <<MSG
Freshlibs: этот пакет заменяет системный libdecor, поэтому его удаление
оставляет систему без libdecor вообще. После завершения операции будут
восстановлены системные пакеты:
    libdecor-0 libdecor-devel ${found}
Вернуться на системную версию без этого круга можно одной командой —
она делает обмен в одной транзакции и ничего не ломает:
    apt-get install libdecor-0 libdecor-devel
Отключить автовосстановление: touch /etc/freshlibs/no-auto-restore
MSG
exit 0

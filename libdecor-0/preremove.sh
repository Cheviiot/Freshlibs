#!/bin/bash
# Stapler maps this script to RPM %preun: it runs before the package's files
# are removed. RPM passes the number of instances that will remain: 0 on a real
# removal, 1 while an upgrade erases the previous version.
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
helper=/usr/libexec/freshlibs/libdecor-restore
runner=${state_dir}/libdecor-restore

if [ -e /etc/freshlibs/no-auto-restore ]; then
	rm -f "${list}" 2>/dev/null
	echo "Freshlibs: автовосстановление отключено (/etc/freshlibs/no-auto-restore)."
	echo "Freshlibs: после удаления в системе не останется libdecor — вернуть: apt-get install libdecor-0 libdecor-devel"
	exit 0
fi

# `apt-get install libdecor-0 libdecor-devel` swaps this package for the ALT
# one in a single transaction, and rpm performs installs before erasures — so
# on that path the system libdecor is already back by now and there is nothing
# to warn about or restore. A file check cannot tell the difference here, since
# this package still owns /usr/lib64/libdecor-0.so.0 until rpm removes it.
if rpm -q libdecor-0 >/dev/null 2>&1; then
	rm -f "${list}" 2>/dev/null
	rmdir "${state_dir}" 2>/dev/null
	exit 0
fi

if ! mkdir -p "${state_dir}" 2>/dev/null; then
	echo "Freshlibs: не удалось создать ${state_dir}, автовосстановление не сработает." >&2
	exit 0
fi

# %post recorded the set of libdecor consumers while the system was intact;
# that recording is the one that matters, because `apt-get remove` erases those
# packages before this scriptlet gets to run. A fresh scan is merged in anyway,
# to pick up anything installed after the last upgrade that rpm has not erased
# yet in this transaction.
recorded=""
if [ -r "${list}" ]; then
	recorded=$(cat "${list}" 2>/dev/null)
fi

fresh=""
if [ -x "${helper}" ]; then
	fresh=$("${helper}" consumers 2>/dev/null)
fi

merged=""
for pkg in libdecor-0 libdecor-devel ${recorded} ${fresh}; do
	case " ${merged} " in
	*" ${pkg} "*)
		continue
		;;
	esac
	merged="${merged}${pkg} "
done

printf '%s\n' "${merged}" >"${list}" 2>/dev/null || {
	echo "Freshlibs: не удалось записать ${list}, автовосстановление не сработает." >&2
	exit 0
}

# The helper must outlive this package's own files, which rpm removes next.
if [ -r "${helper}" ]; then
	cp -f "${helper}" "${runner}" 2>/dev/null && chmod 755 "${runner}" 2>/dev/null
fi

# The closure is bounded (45 packages worst case across all of p11), but that
# is still too much to print; show a handful and point at the file.
count=$(printf '%s\n' ${merged} | grep -c .)
shown=$(printf '%s\n' ${merged} | head -8 | tr '\n' ' ')
if [ "${count}" -gt 8 ]; then
	shown="${shown}… и ещё $((count - 8))"
fi

cat <<MSG
Freshlibs: этот пакет заменяет системный libdecor, поэтому его удаление
оставляет систему без libdecor вообще. После завершения операции будут
восстановлены системные пакеты (${count}), список в ${list}:
    ${shown}
Вернуться на системную версию без этого круга можно одной командой —
она делает обмен в одной транзакции и ничего не ломает:
    apt-get install libdecor-0 libdecor-devel
Отключить автовосстановление: touch /etc/freshlibs/no-auto-restore
MSG
exit 0

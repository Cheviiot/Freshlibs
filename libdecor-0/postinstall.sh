#!/bin/bash
# Stapler maps this script to RPM %post, which runs on a first install and on
# every upgrade alike. RPM passes the resulting number of installed instances:
# 1 on a first install, 2 or more on an upgrade.
#
# rpm runs scriptlets through /bin/sh regardless of this shebang (bash 5.2 in
# POSIX mode on ALT), so nothing here relies on bash-only syntax.
#
# No `set -e`: a failing notification must never abort an rpm transaction that
# has already put the files in place.
set -u

transaction_count="${1:-1}"

state_dir=/var/lib/freshlibs
list=${state_dir}/libdecor-restore.list
helper=/usr/libexec/freshlibs/libdecor-restore

# ALT's rpm refreshes /etc/ld.so.cache by itself for packages carrying shared
# libraries — measured on this very package before these scriptlets existed
# (cache mtime moved one second after the install, with no %post at all), and
# ALT's own library packages ship no scriptlets for that reason. The call is
# kept only as an idempotent safety net for installs done outside apt.
if command -v ldconfig >/dev/null 2>&1; then
	ldconfig || echo "Предупреждение: не удалось обновить кэш загрузчика (ldconfig)." >&2
fi

# Record what needs libdecor while the whole system is still intact, and
# refresh it on every upgrade. It cannot be left to %preun: an `apt-get remove`
# of this package erases the dependent packages BEFORE this package's own
# scriptlets run — measured in a container, where rpm removed mesa-gears and
# xorg-xwayland first and %preun then saw an already empty reverse-dependency
# set. %preun still merges in anything it can see, as a second chance.
if [ -x "${helper}" ] && mkdir -p "${state_dir}" 2>/dev/null; then
	consumers=$("${helper}" consumers 2>/dev/null)
	printf 'libdecor-0 libdecor-devel %s\n' "${consumers}" >"${list}" 2>/dev/null ||
		echo "Предупреждение: не удалось записать ${list}, автовосстановление не сработает." >&2
fi

if [ "${transaction_count}" = 1 ]; then
	cat <<'MSG'
libdecor 0.2.5 установлен вместо системных libdecor-0 и libdecor-devel.
Доступны оба плагина декораций: cairo и GTK — GTK-плагина в ALT p11 не было,
и libdecor предпочитает именно его, так что Wayland-приложения без своих
декораций (в том числе на SDL) получат заголовок в стиле GTK/GNOME.
Плагин выбирается при запуске приложения — уже открытые нужно перезапустить.
Вернуться на системную версию — одной командой: она делает обмен в одной
транзакции и не удаляет ничего лишнего:
    apt-get install libdecor-0 libdecor-devel
MSG
else
	echo "libdecor обновлён до 0.2.5. Перезапустите Wayland-приложения, чтобы они подхватили новую библиотеку."
fi

exit 0

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

# ALT's rpm refreshes /etc/ld.so.cache by itself for packages carrying shared
# libraries — measured on this very package before these scriptlets existed
# (cache mtime moved one second after the install, with no %post at all), and
# ALT's own library packages ship no scriptlets for that reason. The call is
# kept only as an idempotent safety net for installs done outside apt.
if command -v ldconfig >/dev/null 2>&1; then
	ldconfig || echo "Предупреждение: не удалось обновить кэш загрузчика (ldconfig)." >&2
fi

if [ "${transaction_count}" = 1 ]; then
	cat <<'MSG'
libdecor 0.2.5 установлен вместо системных libdecor-0 и libdecor-devel.
Доступны оба плагина декораций: cairo и GTK — GTK-плагина в ALT p11 не было,
и libdecor предпочитает именно его, так что Wayland-приложения без своих
декораций (в том числе на SDL) получат заголовок в стиле GTK/GNOME.
Плагин выбирается при запуске приложения — уже открытые нужно перезапустить.
Вернуть системную версию:
    stplr remove libdecor-0 && apt-get install libdecor-0 libdecor-devel
MSG
else
	echo "libdecor обновлён до 0.2.5. Перезапустите Wayland-приложения, чтобы они подхватили новую библиотеку."
fi

exit 0

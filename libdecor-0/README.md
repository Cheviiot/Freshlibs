<h1 align="center">libdecor</h1>

<p align="center">
  Клиентские оконные декорации для Wayland — с GTK-плагином
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-7188f5?style=for-the-badge" alt="Лицензия"></a>
  <img src="https://img.shields.io/badge/version-1%3A0.2.5-19bfc8?style=for-the-badge" alt="1:0.2.5">
  <img src="https://img.shields.io/badge/arch-amd64%20%7C%20arm64-2ea043?style=for-the-badge" alt="amd64, arm64">
</p>

---

## Установка

```bash
sudo stplr install libdecor-0
```

Заменяет системные `libdecor-0` и `libdecor-devel`: устанавливает и рантайм, и
заголовки с `pkgconfig`-файлом, потому что дистрибутивный devel-пакет владеет
теми же путями и не может стоять рядом.

## Зачем

[libdecor](https://gitlab.freedesktop.org/libdecor/libdecor) рисует заголовок и
рамку за Wayland-клиента. Композитору под Wayland декорации не принадлежат:
приложение либо рисует их само, либо просит об этом libdecor. Плагин выбирается
по приоритету при инициализации.

В ALT p11 лежит `0.1.1` от 2023 года, собранная **только с cairo-плагином**.
Cairo-плагин — минималистичный фолбэк: простая рамка, не совпадающая с темой
рабочего стола. GTK-плагин, который рисует декорации средствами GTK3 и потому
выглядит как остальные окна GNOME, в дистрибутивной сборке отсутствует.

Эта сборка даёт оба плагина:

```
/usr/lib64/libdecor/plugins-1/libdecor-cairo.so
/usr/lib64/libdecor/plugins-1/libdecor-gtk.so
```

Приоритет GTK-плагина — `1000` против `100` у cairo, поэтому под GNOME
libdecor выбирает именно его. Приложения на SDL3, GLFW и прочие
Wayland-клиенты без своих декораций получают заголовок в стиле рабочего стола.
Плагин загружается при инициализации, так что уже открытые окна нужно
перезапустить.

Заодно приходят два с половиной года upstream-исправлений и `libdecor.h` с
новым API (`0.2.x`).

## Проверка

```bash
pkg-config --modversion libdecor-0        # 0.2.5
ls /usr/lib64/libdecor/plugins-1/         # libdecor-cairo.so + libdecor-gtk.so
rpm -q libdecor-0+stplr-freshlibs
```

Какой плагин подхватило приложение, видно по его картам памяти:

```bash
grep -o '/usr/lib64/libdecor.*' /proc/$(pidof your-app)/maps | sort -u
```

## Совместимость

Soname остаётся `libdecor-0.so.0`: в upstream `libdecor_soversion` не менялся,
а set-version-зависимость, которую ALT-овый `find-provides` генерирует для
этой сборки, совпадает с дистрибутивной `0.1.1` побайтово. Поэтому
`xorg-xwayland`, `mesa-gears` и прочие обратные зависимости p11 продолжают
работать без пересборки.

Пакет предоставляет системные имена и версионно, и без версии:

```
libdecor-0, libdecor-0 = 1:0.2.5
libdecor-devel, libdecor-devel = 1:0.2.5
libdecor, libdecor-cairo, libdecor-gtk (+ версионные)
pkgconfig(libdecor-0) = 0.2.5
```

## Что не работает

- **32-битный мультилиб.** `i586-libdecor-0` и `i586-libdecor-devel` требуют
  64-битные пакеты по точной версии-релизу
  (`libdecor-0 = 0.1.1-alt1:p11+348849.100.1.1`), поэтому вместе с этой сборкой
  не встанут. В типовой системе они не установлены; если нужен 32-битный
  libdecor — эта замена не подходит.
- **Зависимости по точной версии-релизу ALT.** Сборка в hasher пакета, который
  требует `libdecor-devel = 0.1.1-alt1:p11+…`, не пройдёт: здесь
  `libdecor-devel = 1:0.2.5` без ALT-релиза. Зависимости по soname и по `>=`
  разрешаются нормально.

## Откат

```bash
sudo apt-get install libdecor-0 libdecor-devel
```

Обмен в одной транзакции. Про прямое удаление и автоматическое восстановление
зависимых пакетов — в [README репозитория](../README.md#-откат).

## Ссылки

- [Upstream](https://gitlab.freedesktop.org/libdecor/libdecor) · [`0.2.5`](https://gitlab.freedesktop.org/libdecor/libdecor/-/tree/0.2.5)
- [Рецепт](Staplerfile) · [скриптлеты](postinstall.sh) · [помощник восстановления](libdecor-restore)

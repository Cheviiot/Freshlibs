<h1 align="center">Freshlibs</h1>

<p align="center">
  <a href="https://stplr.dev/docs/intro/"><img src="https://img.shields.io/badge/Stapler-v0.1.1-8b5cf6?style=flat-square" alt="Stapler v0.1.1"></a>
  <img src="https://img.shields.io/badge/packages-1-19bfc8?style=flat-square" alt="1 пакет">
  <img src="https://img.shields.io/badge/ALT-p11-52d99b?style=flat-square" alt="ALT p11">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-7188f5?style=flat-square" alt="MIT License"></a>
</p>

<p align="center">
  Свежие системные библиотеки для ALT Linux p11 —<br>
  те, что в дистрибутиве устарели или собраны без нужных плагинов.
</p>

<p align="center">
  <a href="#-быстрый-старт">Быстрый старт</a> ·
  <a href="#-каталог">Каталог</a> ·
  <a href="#-совместимость">Совместимость</a> ·
  <a href="#-откат">Откат</a> ·
  <a href="CONTRIBUTING.md">Участие в проекте</a>
</p>

<p align="center"><strong>1 пакет</strong> · <code>ALT p11</code> · <code>amd64</code>, <code>arm64</code></p>

> [!IMPORTANT]
> Пакеты Freshlibs **вытесняют одноимённые пакеты базовой системы** — это их
> назначение, а не побочный эффект. Совместимость по ABI сохраняется, возврат
> на дистрибутивную версию делается одной командой: [Откат](#-откат).

Прикладные программы живут отдельно, в
[Nivora](https://github.com/Cheviiot/Nivora). Freshlibs — только библиотеки.

## ✦ Почему Freshlibs

| Замена, а не второй экземпляр | Совместимость по ABI | Обратимость |
|:--|:--|:--|
| Пакет носит имя системного, объявляет на него `Provides`/`Obsoletes` и занимает те же пути. Никаких параллельных сборок в `/opt` и трюков с `LD_LIBRARY_PATH`. | Soname и set-version-зависимости совпадают с системными, поэтому установленные пакеты p11 продолжают работать без пересборки. | Откат — одна команда. Прямое удаление пакета не оставит систему без библиотеки: зависимые пакеты восстанавливаются автоматически. |

## ⚡ Быстрый старт

Нужен [Stapler](https://stplr.dev/docs/intro/) `v0.1.1` или новее.

```bash
# 1. Подключить Freshlibs
sudo stplr repo add freshlibs https://github.com/Cheviiot/Freshlibs.git

# 2. Загрузить индекс
sudo stplr refresh

# 3. Изучить и установить пакет
stplr info libdecor-0
sudo stplr install libdecor-0
```

Имя репозитория попадает в имя пакета суффиксом: установленный пакет
называется `libdecor-0+stplr-freshlibs`.

## ◈ Каталог

<table>
  <tr>
    <td width="50%" valign="top">
      <!-- package-card:libdecor-0 -->
      <strong><a href="libdecor-0/README.md">libdecor</a></strong><br>
      <sub>Клиентские оконные декорации для Wayland</sub><br><br>
      <code>1:0.2.5</code> · <code>amd64</code> <code>arm64</code><br>
      <sub>в p11: <code>0.1.1</code> без GTK-плагина</sub><br><br>
      <code>stplr install libdecor-0</code>
    </td>
    <td width="50%" valign="middle"><em>Декорации окон для приложений, которые рисуют их сами: SDL3, GLFW, клиенты на wlroots.</em></td>
  </tr>
</table>

## ◎ Совместимость

Репозиторий **только для ALT Linux p11**. Рецепты опираются на имена пакетов и
раскладку каталогов ALT, `compatible_with` ограничен `altlinux`.

| Уровень | Что означает | Архитектуры |
|:--|:--|:--|
| 🟢 `verified` | Сборка, установка, удаление с восстановлением, обмен, обновление и опт-аут проверены в одноразовом контейнере ALT p11. | `amd64` |
| 🔵 `declared` | Архитектура объявлена рецептом, но не собиралась и не проверялась. | `arm64` |

## ↻ Обновление

```bash
sudo stplr refresh
sudo stplr upgrade
```

`apt-get dist-upgrade` не вернёт дистрибутивную версию: установленный пакет
конфликтует с системным и объявляет его устаревшим. `epoch` страхует линию
версий самого Freshlibs.

## ⟲ Откат

Возврат на системную версию — **одна команда**, а не удаление:

```bash
sudo apt-get install libdecor-0 libdecor-devel
```

apt делает обмен в одной транзакции: снимает пакет Freshlibs, ставит
дистрибутивные `0.1.1`, больше ничего не трогает.

Прямое удаление ведёт себя иначе: apt каскадом уносит всё, что зависит от
библиотеки — для libdecor это `xorg-xwayland`, `mesa-gears`,
`gnome-session-wayland` и `i586-steam`. Пакет от этого защищён и
восстанавливает снесённое сам, одноразовой службой systemd после транзакции.

```bash
journalctl -u freshlibs-restore-libdecor    # ход восстановления
touch /etc/freshlibs/no-auto-restore        # выключить восстановление
```

Устройство механизма и его границы —
[в руководстве контрибьютора](CONTRIBUTING.md#восстановление-состояния).

Отключить репозиторий целиком:

```bash
sudo stplr repo remove freshlibs
```

## ◉ Безопасность и доверие

- Рецепты и скриптлеты открыты для проверки до установки: `stplr info libdecor-0`, исходники — в каталоге пакета.
- Загрузки закреплены SHA-256; сумма фиксируется после проверки, что источник действительно опубликован.
- Пакеты не подписаны: Stapler собирает их локально, на машине пользователя.
- Замена библиотеки базовой системы — осознанный риск. Проверка в контейнере не обещает, что это безопасно в любой конфигурации.

## Код и участие

Хотите добавить библиотеку или поправить рецепт — начните с
[руководства контрибьютора](CONTRIBUTING.md): правила упаковки под ALT, схема
восстановления состояния, порядок проверки в контейнере.

Рецепты — [MIT](LICENSE). Лицензии самих библиотек остаются за их авторами.

---

<p align="center">
  <strong>Freshlibs</strong> · системные библиотеки без ожидания следующей платформы<br>
  <sub>MIT © 2026 Cheviiot</sub>
</p>

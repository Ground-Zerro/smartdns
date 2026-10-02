# smartdns для Hydra Route

Сборка [smartdns](https://github.com/pymumu/smartdns) 48.4 с патчем Hydra Route для роутеров Keenetic с Entware. Её скачивает веб-интерфейс Hydra Route при включении «Службы DNS» и запускает как `/opt/sbin/hrweb-dns`, отдельно ставить её не нужно.

Ссылка на файл: `https://raw.githubusercontent.com/Ground-Zerro/smartdns/main/bin/<папка>/smartdns`.

## Файлы

| Файл | Процессор | Размер | SHA-256 |
|---|---|---|---|
| `bin/mipselsf-k3.4/smartdns` | MIPS little-endian, soft-float (MT7621 и др.) | 4 122 828 Б | `5179ef80cf62d1f571289f67cbe0a5efebf40610f84d66ae47608716c326555f` |
| `bin/mipssf-k3.4/smartdns` | MIPS big-endian, soft-float | 4 120 012 Б | `c0b0bbacfc55d9559b0865f9d9931bc759b0538758888905a64dbfe13cbeaba4` |
| `bin/aarch64-k3.10/smartdns` | ARM64 | 4 046 784 Б | `cb5aff88b37ac63dadfdda70344ab6fa9ad543e7afc92b29466743e104d70907` |

- Статические исполняемые файлы (musl, static-pie, без отладочных символов): от библиотек Entware не зависят.
- OpenSSL 3.5.8 встроен и урезан до нужного DNS-клиенту: без TLS 1.0/1.1, устаревших шифров и неиспользуемых алгоритмов. Без zlib.
- Версия: `smartdns -v` → `smartdns 48.4-hrweb4`.
- Сертификаты сборка не содержит: для DoT и DoH в конфиге нужен `ca-file`, например `ca-file /opt/etc/ssl/certs/ca-certificates.crt` (пакет Entware `ca-certificates`).
- Сборки `48.4-hrweb1` и `48.4-hrweb2` не могли прочитать `ca-file` (OpenSSL был собран без stdio) и не запускались с серверами DoT и DoH — используйте `48.4-hrweb3` и новее; Hydra Route требует `48.4-hrweb4`.

## Что добавляет патч

Hydra Route Neo (hrneo) держит в памяти домены правил маршрутизации и отвечает на вопросы о них через Unix-сокет (`MATCH <имя>` → `OK <цель> <ранг> <ключ>` или `NO`). Патч учит smartdns выбирать группу DNS-серверов по этому ответу, без своей копии правил:

| Ответ hrneo | Куда уходит запрос |
|---|---|
| `OK <цель> …` | в группу, заданную для цели строкой `hrneo-target`; цели там нет — в группу по умолчанию. Правила `nameserver` и `domain-set` для этого имени не проверяются: hrneo главнее |
| `NO` | обычная логика smartdns: `nameserver`, `domain-set`, группа по умолчанию |
| hrneo не запущен или не ответил за 100 мс | то же, что `NO` |
| имя DNS-сервера, которое резолвер разрешает через `-bootstrap-dns` | группа `bootstrap-dns`, hrneo не спрашивается |

Новые параметры конфига:

| Параметр | Значение |
|---|---|
| `hrneo-socket <путь>` | сокет hrneo, обычно `/var/run/hrneo.sock`. Без этого параметра патч выключен и smartdns работает как обычная сборка 48.4 |
| `hrneo-target <цель> <группа>` | группа серверов для цели hrneo (имя политики Keenetic или интерфейса). Имя группы — не длиннее 31 символа, иначе конфиг не загрузится |
| `edns-client-subnet-strip yes` | не передавать серверам подсеть (ECS), которую прислало устройство; по умолчанию `no` — передаётся, как в обычной сборке |

Пример:

```
bind [::]:53
ca-file /opt/etc/ssl/certs/ca-certificates.crt
server 9.9.9.9
server-tls 94.140.14.14:853 -host-name dns.adguard-dns.com -group r1 -exclude-default-group
hrneo-socket /var/run/hrneo.sock
hrneo-target HydraRoute r1
speed-check-mode none
```

Домены правил политики `HydraRoute` разрешает AdGuard DNS по DoT, остальные — `9.9.9.9`.

Работа с hrneo:
- соединение одно и постоянное; ответ ждётся до 100 мс;
- после таймаута или ошибки — пауза 1 с, затем новая попытка; если hrneo перезапустился, smartdns переподключается сразу при следующем запросе;
- имена с пробелами и переводами строк в hrneo не отправляются;
- в журнале smartdns — строки `hrneo connected` и `hrneo disconnected`;
- кэш smartdns хранит ответы раздельно по группе серверов, поэтому после смены правил в hrneo ответ чужой группы не отдаётся.

Серверы по имени (`-bootstrap-dns`), с `48.4-hrweb4`:
- имя сервера разрешают только серверы `-bootstrap-dns`, hrneo о нём не спрашивается — иначе имя сервера, попавшее в правило, разрешали бы серверы этого правила;
- группа, в которой ещё нет серверов (имя не разрешилось), отвечает отказом (SERVFAIL), а не группой по умолчанию: домены правила не уходят в общий DNS;
- неразрешённое имя повторяется каждые 2 с без ограничения числа попыток — резолвер переживает старт роутера без сети; сервер появляется через ~2 с после запуска;
- адрес сервера разрешается один раз; новый адрес резолвер узнает после перезапуска.

Ограничения:
- Группа выбирается по запрошенному имени. Имя, которое попадает в правило только через цепочку CNAME, разрешает обычная логика smartdns; маршрутизацию hrneo это не ломает.
- Выбор группы рассчитан на один поток smartdns: не включайте `prefetch-domain` — предзагрузка обращается к выбору группы из потока таймеров.
- Задавая серверы по имени, задайте и хотя бы один сервер `-bootstrap-dns`: без него smartdns разрешает имена серверов системным резолвером — если это он сам, получится петля.

## Совместимость

Новые параметры конфига только добавляются: конфиг, рассчитанный на `48.4-hrwebN`, работает и на следующих сборках. Hydra Route проверяет минимальную версию по `smartdns -v`.

## Исходники и сборка

- smartdns: https://github.com/pymumu/smartdns, тег `Release48.4`;
- OpenSSL: https://github.com/openssl/openssl/releases/tag/openssl-3.5.8;
- патч Hydra Route: `src/smartdns/smartdns-48.4-hrweb.patch`;
- скрипт сборки: `src/smartdns/build.sh` — скачивает исходники, накладывает патч, собирает OpenSSL и smartdns статически.

```
cd src/smartdns
TRIM=1 ARCHS="mipsel mips aarch64" TC=/путь/к/тулчейнам ./build.sh
```

Тулчейны — musl-cross-make (GCC 11.2.1), папки `mipsel-linux-muslsf-cross`, `mips-linux-muslsf-cross`, `aarch64-linux-musl-cross` в каталоге `TC`. Готовые файлы — в `src/smartdns/release/` с той же раскладкой, что у этого репозитория. `ARCHS=x86_64 ./build.sh` собирает версию для ПК (динамическую, с системным OpenSSL) — для проверок.

## Лицензии

- smartdns и патч Hydra Route — GNU GPL v3, текст — `LICENSE`.
- OpenSSL — Apache License 2.0, текст — `LICENSE.openssl`.

Исходники, из которых собраны файлы, — по ссылкам выше вместе с патчем и скриптом из `src/smartdns/`.

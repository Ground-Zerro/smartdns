# smartdns для Hydra Route

Сборка [smartdns](https://github.com/pymumu/smartdns) 48.4 с патчем Hydra Route для роутеров Keenetic с Entware. Её скачивает веб-интерфейс Hydra Route при включении «Службы DNS» и запускает как `/opt/sbin/hrweb-dns`, отдельно ставить её не нужно.

## Файлы

| Файл | Процессор | Размер | SHA-256 |
|---|---|---|---|
| `keenetic/bin/mipselsf-k3.4/smartdns` | MIPS little-endian, soft-float (MT7621 и др.) | 4 101 976 Б | `0b882bde57081e91e837738cbedd7a13d00bfcb5607131ca2241b47796f747b3` |
| `keenetic/bin/mipssf-k3.4/smartdns` | MIPS big-endian, soft-float | 4 099 384 Б | `c425ff67a487e416c1c2cb78f971503196b6666092319b0a1b1b23861f5d7407` |
| `keenetic/bin/aarch64-k3.10/smartdns` | ARM64 | 4 030 360 Б | `c4b817a5ad49d6a103a1617a1bc6e066ffbd72d8f53f8d494e6d67fb841eaf54` |

- Статические исполняемые файлы (musl, static-pie, без отладочных символов): от библиотек Entware не зависят.
- OpenSSL 3.5.8 встроен и урезан до нужного DNS-клиенту: без TLS 1.0/1.1, устаревших шифров и неиспользуемых алгоритмов. Без zlib.
- Версия: `smartdns -v` → `smartdns 48.4-hrweb1`.
- Сертификаты сборка не содержит: для DoT и DoH в конфиге нужен `ca-file`, например `ca-file /opt/etc/ssl/certs/ca-certificates.crt` (пакет Entware `ca-certificates`).

## Что добавляет патч

Hydra Route Neo (hrneo) держит в памяти домены правил маршрутизации и отвечает на вопросы о них через Unix-сокет (`MATCH <имя>` → `OK <цель> <ранг> <ключ>` или `NO`). Патч учит smartdns выбирать группу DNS-серверов по этому ответу, без своей копии правил:

| Ответ hrneo | Куда уходит запрос |
|---|---|
| `OK <цель> …` | в группу, заданную для цели строкой `hrneo-target`; цели там нет — в группу по умолчанию. Правила `nameserver` и `domain-set` для этого имени не проверяются: hrneo главнее |
| `NO` | обычная логика smartdns: `nameserver`, `domain-set`, группа по умолчанию |
| hrneo не запущен или не ответил за 100 мс | то же, что `NO` |

Новые параметры конфига:

| Параметр | Значение |
|---|---|
| `hrneo-socket <путь>` | сокет hrneo, обычно `/var/run/hrneo.sock`. Без этого параметра патч выключен и smartdns работает как обычная сборка 48.4 |
| `hrneo-target <цель> <группа>` | группа серверов для цели hrneo (имя политики Keenetic или интерфейса). Имя группы — не длиннее 31 символа, иначе конфиг не загрузится |

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
- после таймаута или ошибки — пауза 5 с, затем новая попытка; если hrneo перезапустился, smartdns переподключается сразу при следующем запросе;
- имена с пробелами и переводами строк в hrneo не отправляются;
- в журнале smartdns — строки `hrneo connected` и `hrneo disconnected`;
- кэш smartdns хранит ответы раздельно по группе серверов, поэтому после смены правил в hrneo ответ чужой группы не отдаётся.

Ограничения:
- Группа выбирается по запрошенному имени. Имя, которое попадает в правило только через цепочку CNAME, разрешает обычная логика smartdns; маршрутизацию hrneo это не ломает.
- Выбор группы рассчитан на один поток smartdns: не включайте `prefetch-domain` и не задавайте серверы по имени (бутстрап) — эти функции обращаются к выбору группы из других потоков.

## Совместимость

Новые параметры конфига только добавляются: конфиг, рассчитанный на `48.4-hrwebN`, работает и на следующих сборках. Hydra Route проверяет минимальную версию по `smartdns -v`.

## Исходники и сборка

- smartdns: https://github.com/pymumu/smartdns, тег `Release48.4`;
- OpenSSL: https://github.com/openssl/openssl/releases/tag/openssl-3.5.8;
- патч Hydra Route: `smartdns-48.4-hrweb.patch` в этой папке;
- скрипт сборки: `build.sh` в этой папке — скачивает исходники, накладывает патч, собирает OpenSSL и smartdns статически.

```
TRIM=1 ARCHS="mipsel mips aarch64" TC=/путь/к/тулчейнам ./build.sh
```

Тулчейны — musl-cross-make (GCC 11.2.1), папки `mipsel-linux-muslsf-cross`, `mips-linux-muslsf-cross`, `aarch64-linux-musl-cross` в каталоге `TC`. Готовые файлы — `release/keenetic/bin/<папка>/smartdns`. `ARCHS=x86_64 ./build.sh` собирает версию для ПК (динамическую, с системным OpenSSL) — для проверок.

## Лицензии

- smartdns и патч Hydra Route — GNU GPL v3, текст — `LICENSE`.
- OpenSSL — Apache License 2.0, текст — `LICENSE.openssl`.

Исходники, из которых собраны файлы, — по ссылкам выше вместе с патчем и скриптом из этой папки.

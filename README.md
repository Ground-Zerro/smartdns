# smartdns для Hydra Route

Сборка [smartdns](https://github.com/pymumu/smartdns) с патчем для Hydra Route — DNS-резолвер для роутеров Keenetic с Entware. Файлы для mipsel, mips и aarch64 лежат в каталоге `bin/`; их скачивает веб-интерфейс Hydra Route при включении «Службы DNS», отдельно устанавливать ничего не нужно.

Текущая версия: **48.4-hrweb6** (`smartdns -v`).

## Исходники и лицензии

- smartdns — https://github.com/pymumu/smartdns, тег `Release48.4`; лицензия GNU GPL v3 (`LICENSE`).
- OpenSSL 3.5.8 — https://github.com/openssl/openssl/releases/tag/openssl-3.5.8; лицензия Apache 2.0 (`LICENSE.openssl`).
- Патч Hydra Route и скрипт сборки — `src/smartdns/`.

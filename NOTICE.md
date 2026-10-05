# Происхождение и лицензии

hrdns в целом распространяется на условиях **GNU GPL v3** (`LICENSE`). Исходники публикуются рядом с бинарниками. Заголовки авторства в файлах сохранены.

| Компонент | Откуда | Лицензия | Где в проекте |
|---|---|---|---|
| smartdns Release48.4 (`21c940edc65520849ba03544c5cf8d9cf326e680`) © Ruilin Peng (Nick) | https://github.com/pymumu/smartdns | GPL-3.0 | `core/` — снимок каталога `src/` с применённым патчем Hydra Route; дальше правится напрямую |
| smartdns-webui (`1c06fee693434ec7c71f06010d3f87416baba9f0`) © Ruilin Peng (Nick) | https://github.com/pymumu/smartdns-webui | MIT (`LICENSES/MIT-smartdns-webui.txt`) | `ui/frontend/` — снимок с применёнными изменениями Hydra Route; текст лицензии вшивается в `ui/backend/www/LICENSE` |
| OpenSSL 3.5.8 | https://github.com/openssl/openssl | Apache-2.0 (`LICENSES/Apache-2.0-openssl.txt`) | собирается статически в бинарник `hrdns`, в репозитории не лежит |
| Зависимости фронтенда | npm, `ui/frontend/package-lock.json` | MIT, Apache-2.0, ISC, BSD (по пакетам) | в статику `ui/backend/www/` попадают собранными |

Футера smartdns во фронтенде нет: уведомление MIT — в `LICENSES/MIT-smartdns-webui.txt` и `ui/backend/www/LICENSE`. hrweb с hrdns не линкуется и лицензию не меняет.

Это справка проекта, а не юридическая консультация.

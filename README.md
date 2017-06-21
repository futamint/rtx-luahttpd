# rtx-luahttpd

YAMAHA RTX シリーズの lua スクリプト実行機能で動作する HTTP サーバです。
RTX 自体の GUI 設定とは異なるポートで動かすことが可能です。

デフォルトのポート番号は 11111 です。

## 導入方法

### RTX

lua スクリプトを tftp で RTX に転送する。

* tftp host <PCのIPアドレス>

### PC

* tftp <ルーターのIPアドレス> put luahttpd.lua /luahttpd.lua/<ルーターの admin パスワード>

### RTX

* lua luahttpd.lua
* terminate lua file luahttpd.lua

## HTTP サーバの叩き方

サンプルとして show 系のコマンドを取れるようにしています。
コマンドのスペースをスラッシュに置換してください。(例：show config → show/config)

* http://<ルーターのIPアドレス>:11111/show/status/dhcp
* http://<ルーターのIPアドレス>:11111/show/environment

DHCPリーステーブルを json で取得できるようにしています。

* http://<ルーターのIPアドレス>:11111/show/status/dhcp/summary.json


[コンソールコマンド]
lo3 - lo3を実行します

[チャットコマンド]
!lo3 - lo3を実行します
!live - lo3を実行します(!lo3へのalias)
!restart - マッチ設定を無効化しラウンドをリスタートします
!menu - メニューを表示します
!swap - CTとTのスワップを実行します
!scramble - プレーヤーをCTとTにランダムに振り分けます
!ot - オーバータイムのコンフィグを読み込み、lo3を実行します
!pause - 試合を一時停止します(フリーズタイムのみ)
!unpause - 試合を再開します

[cvar]
ll_match_config "match_fb2.cfg"//lo3実行時に読み込まれるコンフィグ。match.cfgはESL準拠（FB１個)。match_fb2.cfgはFB２個
ll_enable_saycommand "1"//チャットコマンドを利用したlo3、リスタートコマンド実行を許可する・しない
ll_enable_respawn "1"//プレーヤーが死んだ時に自動でリスポーンする・しない
ll_live_type "0"//ライブの種類を選択 0=lo3 1=only one restart
ll_allow_toggle_sv_cheats "1"//1=sv_cheatsのトグルを許可 0=無効
これらの設定を変更する場合は、lo3loader.cfgを編集してください
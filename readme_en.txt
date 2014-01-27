
[console command]
lo3 - execute lo3

[say commands]
!lo3 - execute lo3
!live - execute lo3(alias !lo3)
!restart - disable match and restart games.then execute practice.cfg
!menu - choose game configs and toggle sv_cheats
!swap - swapping teams
!scramble - scramble teams
!ot - execute lo3(for overtime). then execute overtime.cfg
!pause - pause match(freeze time only)
!unpause - resume match

[cvar]
ll_match_config "match_fb2.cfg"//your match config name here. this config execute when lo3
ll_enable_saycommand "1"//enable say commands? 1=enable 0=disable
ll_enable_respawn "1"//auto respawn with $16000 when player is dead.1=enable 0=disable. this setting is auto disable when lo3.
ll_live_type "0"//choose restart types. 0=lo3 1=only one restart
ll_allow_toggle_sv_cheats "1"//allow toggle sv_cheats? 1=allow 0=deny

if you want change these settings,change lo3loader.cfg.
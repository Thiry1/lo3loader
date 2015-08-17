#include<sourcemod>
#include<cstrike>
#define PLUGIN_VERSION "1.2.8"
//#define DEBUG
//#ifdef DEBUG
//    #include "net/fiveSeven/sourcemod/csgo/debug/autoloader.sp"
//#endif
public Plugin:myinfo =
{
    name = "lo3loader for CS:GO",
    author = "Thiry",
    description = "live on 3 restarts command(Usage:type lo3 to server console OR say !lo3)",
    version = PLUGIN_VERSION,
    url = "http://blog.five-seven.net/"
};

new Handle:cvar_ll_enable_saycommand;
new Handle:cvar_ll_match_config;
new Handle:cvar_ll_enable_respawn;
new Handle:cvar_ll_live_type;
new Handle:cvar_ll_allow_toggle_sv_cheats;
new Handle:cvar_sv_coaching_enabled;
new Handle:panel;
new live_type;
new g_iAccount;
new String:LL_MATCH_CONFIG_DEFAULT[64];
new bool:saycommand_enable = false;
new bool:pauseStatus       = false;
new bool:pausable          = false;


/**
 * プラグインロード時にコールされる
 */
public OnPluginStart()
{
    RegServerCmd("lo3"      , Command_lo3);
    RegConsoleCmd("say"     , Command_Say);
    RegConsoleCmd("say_team", Command_Say);

    cvar_ll_enable_saycommand      = CreateConVar("ll_enable_saycommand"     , "1"        , "If non-zero, enable say hook. everyone can execute lo3 by say !lo3");
    cvar_ll_enable_respawn         = CreateConVar("ll_enable_respawn"        , "1"        , "If non-zero, enable auto respawn when player is dead");
    cvar_ll_match_config           = CreateConVar("ll_match_config"          , "esl5on5.cfg","execute configs on live");
    cvar_ll_live_type              = CreateConVar("ll_live_type"             , "0"        , "if zero, live type is lo3.non-zero is only one restart");
    cvar_ll_allow_toggle_sv_cheats = CreateConVar("ll_allow_toggle_sv_cheats", "1"        , "if non-zero, client can toggle sv_cheats");
    cvar_sv_coaching_enabled       = FindConVar("sv_coaching_enabled");
    g_iAccount                     = FindSendPropOffs("CCSPlayer"            , "m_iAccount");//money offset

    HookEvent("teamchange_pending"  , ev_teamchange_pending);
    HookEvent("player_death"        , ev_player_death);
    HookEvent("round_freeze_end"    , ev_round_freeze_end);
    HookEvent("round_end"           , ev_round_end);
    HookEvent("cs_match_end_restart", ev_cs_match_end_restart);

    GeneratePanel();//menuパネルの生成
}
/**
 * マップ開始時にコールされる
 */
public OnMapStart()
{
    //コンフィグの読み込み
    ServerCommand("exec lo3loader.cfg");

    //ll_match_configに指定されている値をデフォルト値として格納
    GetConVarString(cvar_ll_match_config, LL_MATCH_CONFIG_DEFAULT, sizeof(LL_MATCH_CONFIG_DEFAULT));

    //saycommandの設定
    if( !GetConVarInt(cvar_ll_enable_saycommand) )
    {
        saycommand_enable = false;
    }
    else
    {
        saycommand_enable = true;
    }

    //将来の拡張に備えてlive_typeはboolにしない
    if( !GetConVarInt(cvar_ll_live_type) )
    {
        live_type = 0;//lo3
    }
    else
    {
        live_type = 1;
    }
}
/**
 * ポップアップパネルを生成する
 */
stock GeneratePanel()
{
    panel = CreateMenu(onMenuSelect);
    SetMenuTitle(panel, "Lo3loader Menu");
    AddMenuItem(panel, "MATCH_CONFIG"   , "Exec Match Config");
    AddMenuItem(panel, "OVERTIME_CONFIG", "Exec Overtime Config");
    AddMenuItem(panel, "TOGGLE_CHEATS"  , "Toggle sv_cheats");
    AddMenuItem(panel, "SWAP_TEAMS"     , "Swap Team");
    AddMenuItem(panel, "SCRAMBLE_TEAMS" , "Scramble Team");
    AddMenuItem(panel, "RELOAD_CONFIG"  , "Reload lo3loader.cfg");
}
/**
 * クライアントがポップアップから選択した際にコールされる
 * @param menu
 * @param action イベントアクション
 * @param client パネルを選択したクライアント
 * @param param 選択されたパネルの番号
 */
public onMenuSelect(Handle:menu, MenuAction:action, client, param)
{
    if( action == MenuAction_Select )
    {
        new String:selected[64];
        GetMenuItem(menu, param, selected, sizeof(selected));

        if( StrEqual(selected, "MATCH_CONFIG", true) )//ESLのコンフィグを読み込む
        {
            pausable = true;
            SetConVarString(cvar_ll_match_config, LL_MATCH_CONFIG_DEFAULT);
            PrintToChatAll("match type: LL Match Config");
            ExecLo3();
        }
        else if( StrEqual(selected, "OVERTIME_CONFIG", true) )//overtimeのコンフィグを読み込む
        {
            pausable = true;
            SetConVarString(cvar_ll_match_config, "overtime.cfg");
            PrintToChatAll("match type: Overtime Match Config");
            ExecLo3();
            SetConVarString(cvar_ll_match_config, LL_MATCH_CONFIG_DEFAULT);
        }
        else if( StrEqual(selected, "TOGGLE_CHEATS", true) )//cheatsのトグル
        {
            if( GetConVarInt(cvar_ll_allow_toggle_sv_cheats) != 0 )//トグルが許可されていれば
            {
                new Handle:cvar_sv_cheats = FindConVar("sv_cheats");
                if( GetConVarInt(cvar_sv_cheats) )
                {
                    SetConVarInt(cvar_sv_cheats, 0);
                }
                else
                {
                    SetConVarInt(cvar_sv_cheats, 1);
                }
            }
            else
            {
                PrintToChatAll("[lo3loader]this command is not allowed.");
            }
        }
        else if( StrEqual(selected, "SWAP_TEAMS", true) )
        {
            SwapTeams();
        }
        else if( StrEqual(selected, "SCRAMBLE_TEAMS", true) )
        {
            ScrambleTeams();
        }
        else if( StrEqual(selected, "RELOAD_CONFIG", true) )
        {
            ServerCommand("exec lo3loader.cfg");
            PrintToChatAll("[lo3loader]reload config");
        }
    }
}
/**
 * lo3の実行処理
 */
public ExecLo3()
{
    SetConVarInt(cvar_ll_enable_respawn, 0);//読み込むマッチコンフィグにll_enable_respawnを無効化する記述がない場合でも問題なく動作するよう上書きする

    //ll_match_configに指定されたコンフィグ名を取得する
    new String:cfg[64];
    GetConVarString(cvar_ll_match_config, cfg, sizeof(cfg));
    //コンフィグの読み込み
    ServerCommand("exec %s", cfg);//なぜかServerCommand使ったほうがオーバーヘッドが少ない

    if( !live_type )//lo3
    {
        PrintToChatAll("[lo3loader]Live ON 3 Restarts");
        CreateTimer(0.8, restart);
        CreateTimer(3.0, restart);
        CreateTimer(5.0, restart);
        CreateTimer(7.0, live);
    }
    else//lo1
    {
        PrintToChatAll("[lo3loader] Live ON Restart");
        ServerCommand("mp_restartgame 1");
        CreateTimer(2.0, live);
    }
}
/**
 * lo3の最終テキストを表示する
 * @param timer
 */
public Action:live(Handle:timer)
{
    for(new i = 0; i <= 6; i++)
    {
        PrintToChatAll("[lo3loader] -=!Live!=-");
    }
    PrintToChatAll("[lo3loader] Match is now LIVE! \04[G]\01ood \04[L]\01uck \04[H]\01ave \04[F]\01un!");
}
/**
 * lo3のリスタート処理
 * @param timer
 */
public Action:restart(Handle:timer)
{
    static cnt = 1;
    PrintToChatAll("[lo3loader] Restart %d", cnt++);
    ServerCommand("mp_restartgame 1");

    if(cnt >= 4)
    {
        cnt = 1;
    }
}
/**
 * 試合の再開処理を行う
 * @param timer
 */
public Action:ResumeMatch(Handle:timer)
{
    static cnt = 3;
    PrintToChatAll("[lo3loader] Match will resume after %d second(s)", cnt--);

    if(cnt <= 0)
    {
        cnt = 3;
        PrintToChatAll("[lo3loader] Match is now LIVE! \04[G]\01ood \04[L]\01uck \04[H]\01ave \04[F]\01un!");
        ServerCommand("mp_unpause_match");
    }
    else
    {
        CreateTimer(1.0, ResumeMatch);//カウントが0になるまで再帰する
    }
}
/**
 * consoleコマンドでlo3が呼び出された時にコールされる
 * @param args
 */
public Action:Command_lo3(args)
{
    ExecLo3();
}
/**
 * プレーヤーをrewpanさせる実処理
 * @param timer
 * @param client 対象クライアント
 */
public Action:respawn(Handle:timer,any:client)
{
    new team = GetClientTeam(client);//0=connecting,1=spect,2=t,3=ct
    if( IsClientInGame(client) && !IsPlayerAlive(client) && team > 1 )//再度プレーヤーがサーバー上に適切な形で存在するか確認
    {
        GiveClientMoney(client);//プレーヤーの所持金を$16000に設定
        CS_RespawnPlayer(client);
    }
}
/**
 * プレーヤー死亡時の一定時間経過後にrespawn処理を呼び出す
 * @param client サーバ内のクライントのユニークID
 */
public RespawnClient(client)
{
    new team = GetClientTeam(client);//0=connecting,1=spect,2=t,3=ct
    if( IsClientInGame(client) && !IsPlayerAlive(client) && team > 1 )//プレーヤーがサーバー上に適切な形で存在するか確認
    {
        PrintToChat(client, "[lo3loader]you will be respawn after 2 seconds");
        CreateTimer(2.0, respawn, any:client);
    }
}

/* Game Events */
/**
 * 試合の終了時にコールされる
 * @param event
 * @param name
 * @param dontBroadcast
 */
public ev_cs_match_end_restart(Handle:event, const String:name[], bool:dontBroadcast)
{
    ServerCommand("exec lo3loader.cfg");//overtime.cfgなどで上書きされたコンフィグの初期化
}
/**
 * クライアント死亡時にコールされる
 * @param event
 * @param name
 * @param dontBroadcast
 */
public ev_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
    if( GetConVarInt(cvar_ll_enable_respawn) != 0 )//cvarが試合中などに変更される可能性があるためll_enable_respawnの値は保持せず毎回確認する。
    {
        RespawnClient(GetClientOfUserId(GetEventInt(event, "userid")));
    }
}
/**
 * ラウンド終了時にコールされる
 * @param event
 * @param name
 * @param dontBroadcast
 */
public ev_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
    pausable = true;//ポーズの呼び出しを許可する
}
/**
 * ラウンド開始(※クライアントが移動可能になった時)にコールされる
 * @param event
 * @param name
 * @param dontBroadcast
 */
public ev_round_freeze_end(Handle:event, const String:name[], bool:dontBroadcast)
{
    pausable = false;//ポーズの呼び出しを無効化する
}

/**
 *クライアントがチーム移動を要求した時にコールされる
 * @param event
 * @param name
 * @param dontBroadcast
 */
public ev_teamchange_pending(Handle:event, const String:name[], bool:dontBroadcast)
{
    //ラウンド終了を待たずにクライアントの移動を行う
    new team = GetEventInt(event, "toteam");//移動先チームの取得
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    ChangeClientTeam(client, team);//移動処理

    PrintToChat(client,"[lo3loader]Changing Team");
}
/**
 * プレーヤー発言時にコールされる
 * @param client
 * @param args 発言内容などが格納される
 */
public Action:Command_Say(client, args)
{
    //switchはSourcePawnの仕様で1コマンドしか実行できないので使用しない
    if( saycommand_enable )
    {
        new String:text[64];
        GetCmdArg(1, text, sizeof(text));//発言内容を取得

        if( (StrEqual(text, "!lo3", true)) || (StrEqual(text, "!live", true)) )
        {
            SetConVarString(cvar_ll_match_config, LL_MATCH_CONFIG_DEFAULT);//ll_match_configで指定されているコンフィグを設定
            pausable = true;
            ExecLo3();
        }
        else if( StrEqual(text, "!restart", true) )
        {
            pausable = true;
            ServerCommand("exec practice.cfg");
            ServerCommand("mp_restartgame 1");
        }
        else if(StrEqual(text, "!menu", true))
        {
            DisplayMenu(panel, client, MENU_TIME_FOREVER);
        }
        else if(StrEqual(text, "!scramble", true))
        {
            ScrambleTeams()
        }
        else if(StrEqual(text, "!swap", true))
        {
            SwapTeams();
        }
        else if(StrEqual(text, "!pause", true))
        {
            pause(client);
        }
        else if(StrEqual(text, "!unpause"))
        {
            unpause(client);
        }
        else if(StrEqual(text, "!ot"))
        {
            SetConVarString(cvar_ll_match_config, "overtime.cfg");
            ExecLo3();
        }
        else if(StrEqual(text, "!coach t"))
        {
            if( GetConVarInt(cvar_sv_coaching_enabled) != 1 ) {
                PrintToChat(client, "coach mode has disabled by server");
                return;
            }

            ClientCommand(client, "coach t");
        }
        else if(StrEqual(text, "!coach ct"))
        {
            if( GetConVarInt(cvar_sv_coaching_enabled) != 1 ) {
                PrintToChat(client, "coach mode has disabled by server");
                return;
            }

            ClientCommand(client, "coach ct");
        }
    }
}

/**
 * チームのスクランブルを行う
 */
stock ScrambleTeams()
{
    PrintToChatAll("[lo3loader]Scramble teams...");
    ServerCommand("mp_scrambleteams");
}

/**
 * チームのスワップを行う
 */
stock SwapTeams()
{
    PrintToChatAll("[lo3loader]Swapping teams...");
    ServerCommand("mp_swapteams");
}

/**
 * ポーズを行う
 * @param client
 */
stock pause(client)
{
    if( pausable )
    {
        new String:name[128];
        GetClientName(client, name, sizeof(name));
        PrintToChatAll("[lo3loader] Match is paused by %s", name);
        ServerCommand("mp_pause_match");
        pauseStatus = true;
    }
    else
    {
        PrintToChatAll("[lo3loader]This command is disallowed now")
    }
}

/**
 * ポーズの解除を行う
 * @param client
 */
stock unpause(client)
{
    if( pauseStatus )
    {
        new String:name[128];
        GetClientName(client, name, sizeof(name));
        PrintToChatAll("[lo3loader]Match is resumed by %s", name);
        pauseStatus = false;
        CreateTimer(0.0, ResumeMatch);
    }
    else
    {
        PrintToChatAll("[lo3loader]This command is disallowed now")
    }
}
/**
 * クライアントのmoneyにアクセスする
 * @param client
 */
stock GiveClientMoney(client)
{
    if( g_iAccount != -1 )//offsetが取得できていれば
    {
        SetEntData(client, g_iAccount, 16000);
    }
}

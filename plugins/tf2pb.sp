#include <socket>
#include <sourcemod>

new String:serverIP[64];
new disconnectedPlayers[32][2];
new lastTournamentStateUpdate = 0;
new String:port[16];
new String:server[16] = "dallas"; 
new tournamentState = 0;

public Plugin:myinfo =
{
	name = "TF2PB",
	author = "Jean-Denis Caron",
	description = "Server side management for the PUG system.",
	version = SOURCEMOD_VERSION,
	url = "http://github.com/550/tf2pb/"
};

public Action:Command_Say(client, args)
{
	decl String:userText[192];
    userText[0] = '\0';
	if (!GetCmdArgString(userText, sizeof(userText)))
	{
		return Plugin_Continue;
	}

    if(StrContains(userText, "\"!needsub") == 0)
    { 
        decl String:query[192];
        query = "";
        StripQuotes(userText);
        StrCat(query, 192, userText);
        StrCat(query, 192, " ");
        StrCat(query, 192, serverIP);
        StrCat(query, 192, ":");
        StrCat(query, 192, port);
        sendDataToBot(query);
    }
	
	return Plugin_Continue;	
}


public Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    PrintToChatAll("%i", GetEventInt(event, "userid"));
    new appendedValue = 0;
    new disconnectedCounter = 0;
    for(new i = 0; i < 32; i++)
    {
        PrintToServer("tttteeest");
        if(GetTime() - disconnectedPlayers[i][1] <= 1 * 60)
        {
            disconnectedCounter++;
        }else
        {
            disconnectedPlayers[i][0] = -1;
            disconnectedPlayers[i][1] = 0;
        }

        if(!appendedValue && disconnectedPlayers[i][0] == -1)
        {
            disconnectedPlayers[i][0] = GetEventInt(event, "userid");
            disconnectedPlayers[i][1] = GetTime();
            disconnectedCounter++;
            appendedValue = 1;
        }
    }

    PrintToServer("disconnectedCounter %i", disconnectedCounter);
    if(disconnectedCounter >= 2)
    {
        gameOver();
    }
}

public Event_TeamplayGameOver(Handle:event, const String:name[], bool:dontBroadcast)
{
    gameOver();
}

public Event_TeamplayRestartRound(Handle:event, const String:name[], bool:dontBroadcast)
{
    if((GetTime() - lastTournamentStateUpdate) <= 10)
    {
        decl String:record[64] = "tv_record ";
        decl String:time[64];
        FormatTime(time, 64, "%Y-%m-%d-%Hh%Mm");
        StrCat(record, 64, time);
        StrCat(record, 64, "_");
        StrCat(record, 64, server);
        StrCat(record, 64, port);
        ServerCommand("tv_stoprecord");
        ServerCommand(record);
        PrintToChatAll("%s", record);
    }
    PrintToChatAll("Round Restarted");
    tournamentState = 0;
}

public Event_TournamentStateupdate(Handle:event, const String:name[], bool:dontBroadcast)
{

    if(GetEventBool(event, "namechange") == false)
    {
        if(GetEventInt(event, "readystate") == 1)
        {
            tournamentState = tournamentState + 1;
            if(tournamentState >= 2)
            {
                lastTournamentStateUpdate = GetTime();
                PrintToChatAll("Match.cfg");
                ServerCommand("exec match.cfg");
            }
        }else{
            tournamentState = tournamentState - 1;
            PrintToChatAll("TF2DM.cfg");
            ServerCommand("exec tf2dm.cfg");
        }
        decl String:tournamentStateString[10];
        decl String:tournamentReadyState[10];
        IntToString(tournamentState, tournamentStateString, 10)
        IntToString(GetEventInt(event, "readystate"), tournamentReadyState, 10)
        PrintToChatAll("Event state : %s, Tournament state : %s", tournamentReadyState, tournamentStateString);
    }
}

public gameOver()
{
    ServerCommand("tv_stoprecord");
    tournamentState = 0;
    decl String:query[192];
    query = "";
    StrCat(query, 192, "!gameover");
    StrCat(query, 192, " ");
    StrCat(query, 192, serverIP);
    StrCat(query, 192, ":");
    StrCat(query, 192, port);
    sendDataToBot(query);
    PrintToChatAll("TF2 Game Over");
    ServerCommand("exec tf2dm.cfg");
}

public OnPluginStart()
{
    GetConVarString(FindConVar("ip"), serverIP, sizeof(serverIP));
    IntToString(GetConVarInt(FindConVar("hostport")), port, 10)
    lastTournamentStateUpdate = 0;

    for(new i = 32; i < 32; i++)
    {
        disconnectedPlayers[i][0] = -1;
        disconnectedPlayers[i][1] = 0;
    }

    HookEvent("player_disconnect", Event_PlayerDisconnect);
    HookEvent("teamplay_game_over", Event_TeamplayGameOver);
    HookEvent("teamplay_restart_round", Event_TeamplayRestartRound);
    HookEvent("tf_game_over", Event_TeamplayGameOver);
    HookEvent("tournament_stateupdate", Event_TournamentStateupdate);
    RegConsoleCmd("say", Command_Say);
}

public OnSocketConnected(Handle:socket, any:data){
    decl String:query[192];
    GetArrayString(data, 0, query, 192);
    SocketSend(socket, query);
}

public OnSocketDisconnected(Handle:socket, any:arg){
    CloseHandle(socket);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:arg){
    CloseHandle(socket);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:arg){
    return 0;
}

public OnSocketSendqueueEmpty(Handle:socket, any:arg){
    SocketDisconnect(socket);
    CloseHandle(socket);
}

public sendDataToBot(String:query[])
{
    new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
    new Handle:data = CreateArray(192);
    PushArrayString(data, query);
    SocketSetArg(socket, data);
    SocketSetSendqueueEmptyCallback(socket, OnSocketSendqueueEmpty);
    SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, "bot.tf2pug.org", 50007)
}

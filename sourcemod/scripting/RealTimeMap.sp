#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <system2>
#include <json>

#define CHARSPLIT "|"
#define NAMESPLIT "!@!"
#define MAXUTILITY 10

enum UtilityType {
    u_Smoke = 0,
    u_Flash = 1,
    u_Hegrenade = 2,
    u_Molotov = 3,
    u_Incgrenade = 4,
    u_Decoy = 5
}

int g_FlyingUtIds[MAXUTILITY + 1];
UtilityType g_UtType[MAXUTILITY + 1];

public Plugin:myinfo = {
    name = "Realtime map info sender",
    author = "CarOL",
    description = "WIP",
    url = "csgowiki.top"
};

public OnPluginStart() {
    HookEvent("hegrenade_detonate", Event_HegrenadeDetonate);
    HookEvent("flashbang_detonate", Event_FlashbangDetonate);
    HookEvent("smokegrenade_detonate", Event_SmokeDetonate);
    HookEvent("inferno_startburn", Event_MolotovDetonate);
    HookEvent("decoy_started", Event_DecoyStarted);
    
    HookEvent("player_say", Event_PlayerSay);
    CreateTimer(0.2, InfoSender, _, TIMER_REPEAT);
    CreateTimer(1.0, MsgGeter, _, TIMER_REPEAT);
}

public OnMapStart() {
    for (int idx = 0; idx <= MAXUTILITY; idx++) {
        g_FlyingUtIds[idx] = -1;
    }
    MapInfoSender();
}

public OnClientConnected(client) {
    MapInfoSender();
}

void removeFlyingUtId(entity) {
    bool success = false;
    for (int idx = 0; idx <= MAXUTILITY; idx++) {
        if (g_FlyingUtIds[idx] == entity) {
            g_FlyingUtIds[idx] = -1;
            success = true;
        }
    }
    if (!success) {
        for (int idx = 0; idx <= MAXUTILITY; idx++) {
            g_FlyingUtIds[idx] = -1;
        }
    }
}

public SpawnPost_Grenade(entity) {
    SDKUnhook(entity, SDKHook_SpawnPost, SpawnPost_Grenade);
    new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if (client != -1 && GetClientTeam(client) == CS_TEAM_CT) {
        for (int idx = 0; idx <= MAXUTILITY; idx++) {
            if (g_FlyingUtIds[idx] == entity) {
                g_UtType[idx] = u_Incgrenade;
            }
        }
    }
} 

void setFlyingUtId(entity, UtilityType utType) {
    bool success = false;
    for (int idx = 0; idx <= MAXUTILITY; idx++) {
        if (g_FlyingUtIds[idx] == -1) {
            success = true;
            g_FlyingUtIds[idx] = entity;
            g_UtType[idx] = utType;
            break;
        }
    }
    if (!success) {
        g_FlyingUtIds[0] = entity;
        g_UtType[0] = utType;
    }
}

public OnEntityCreated(entity, const String:classname[]) {
    if (StrEqual(classname, "smokegrenade_projectile", false)) {
        setFlyingUtId(entity, u_Smoke);
    }
    else if (StrEqual(classname, "flashbang_projectile", false)) {
        setFlyingUtId(entity, u_Flash);
    }
    else if (StrEqual(classname, "hegrenade_projectile", false)) {
        setFlyingUtId(entity, u_Hegrenade);
    }
    else if (StrEqual(classname, "molotov_projectile", false)) {
        setFlyingUtId(entity, u_Molotov);
        SDKHook(entity, SDKHook_SpawnPost, SpawnPost_Grenade)
    }
    else if (StrEqual(classname, "decoy_projectile", false)) {
        setFlyingUtId(entity, u_Decoy);
    }
}

public Action:Event_HegrenadeDetonate(Handle:event, const String:name[], bool:dontBroadcast) {
    int utid = GetEventInt(event, "entityid");
    float realX = GetEventFloat(event, "x");
    float realY = GetEventFloat(event, "y");
    char uttype[16] = "hegrenade";
    UtilitySender(utid, realX, realY, uttype);
    removeFlyingUtId(utid);
}

public Action:Event_FlashbangDetonate(Handle:event, const String:name[], bool:dontBroadcast) {
    int utid = GetEventInt(event, "entityid");
    float realX = GetEventFloat(event, "x");
    float realY = GetEventFloat(event, "y");
    char uttype[16] = "flashbang";
    UtilitySender(utid, realX, realY, uttype);
    removeFlyingUtId(utid);
}

public Action:Event_SmokeDetonate(Handle:event, const String:name[], bool:dontBroadcast) {
    int utid = GetEventInt(event, "entityid");
    float realX = GetEventFloat(event, "x");
    float realY = GetEventFloat(event, "y");
    char uttype[16] = "smokegrenade";
    UtilitySender(utid, realX, realY, uttype);
    removeFlyingUtId(utid);
}

public Action:Event_MolotovDetonate(Handle:event, const String:name[], bool:dontBroadcast) {
    int utid = GetEventInt(event, "entityid");
    float realX = GetEventFloat(event, "x");
    float realY = GetEventFloat(event, "y");
    char uttype[16] = "molotov";
    UtilitySender(utid, realX, realY, uttype);
    removeFlyingUtId(utid);
}

public Action:Event_DecoyStarted(Handle:event, const String:name[], bool:dontBroadcast) {
    int utid = GetEventInt(event, "entityid");
    float realX = GetEventFloat(event, "x");
    float realY = GetEventFloat(event, "y");
    char uttype[16] = "decoy";
    UtilitySender(utid, realX, realY, uttype);
    removeFlyingUtId(utid);
}

public Action:Event_PlayerSay(Handle:event, const String:name[], bool:dontBroadcast) {
    char name_[32];
    char message[48];
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    GetEventString(event, "text", message, sizeof(message));
    GetClientName(client, name_, sizeof(name_));
    msgSender(true, name_, message);
}

void msgSender(bool flag, char name[32], char message[48]) {
    System2HTTPRequest httpRequest = new System2HTTPRequest(
        msgSenderCallBack,
        "http://127.0.0.1:5000/server-api/msg"
    );
    if (flag)
        httpRequest.SetData("name=%s&msg=%s", name, message);
    else
        httpRequest.SetData("");
    httpRequest.POST();
}

void UtilitySender(int utid, float realX, float realY, char uttype[16]) {
    System2HTTPRequest httpRequest = new System2HTTPRequest(
        utSenderCallBack,
        "http://127.0.0.1:5000/server-api/utility"
    );
    httpRequest.SetData("utid=%d&realX=%f&realY=%f&uttype=%s", utid, realX, realY, uttype);
    httpRequest.POST();
}

void MapInfoSender() {
    char MapName[16];
    GetCurrentMap(MapName, sizeof(MapName));
    System2HTTPRequest httpRequest = new System2HTTPRequest(
        mapSenderCallBack,
        "http://127.0.0.1:5000/server-api/map"
    );
    httpRequest.SetData("mapname=%s", MapName);
    httpRequest.POST();
}

public Action:MsgGeter(Handle timer) {
    MapInfoSender();
    msgSender(false, "", "");
}

void PlayerMoveInfoSender() {
    char playerXs[96];
    char playerYs[96];
    char steam3ids[150];
    char names[150];
    char ids[20];
    int playerCount = 0;
    for (int client = 0; client <= MAXPLAYERS; client ++) {
        if (IsPlayer(client)) {
            char playerX[8];
            char playerY[8];
            float OriginPosition[3];
            char steam3id[16];
            char name[32];
            char id[2];
            GetClientAbsOrigin(client, OriginPosition);
            GetClientAuthId(client, AuthId_Steam3, steam3id, sizeof(steam3id));
            GetClientName(client, name, sizeof(name));
            FloatToString(OriginPosition[0], playerX, sizeof(playerX));
            FloatToString(OriginPosition[1], playerY, sizeof(playerY));
            IntToString(client, id, sizeof(id));
            if (playerCount != 0) {
                StrCat(playerXs, sizeof(playerXs), CHARSPLIT);
                StrCat(playerYs, sizeof(playerYs), CHARSPLIT);
                StrCat(steam3ids, sizeof(steam3ids), CHARSPLIT);
                StrCat(names, sizeof(names), NAMESPLIT);
                StrCat(ids, sizeof(ids), CHARSPLIT);
            }
            StrCat(playerXs, sizeof(playerXs), playerX);
            StrCat(playerYs, sizeof(playerYs), playerY);
            StrCat(steam3ids, sizeof(steam3ids), steam3id);
            StrCat(names, sizeof(names), name);
            StrCat(ids, sizeof(ids), id);
            playerCount++;
        }
    }
    System2HTTPRequest httpRequest = new System2HTTPRequest(
        senderCallBack,
        "http://127.0.0.1:5000/server-api/player"
    );
    httpRequest.SetData("playerXs=%s&playerYs=%s&steam3ids=%s&names=%s&ids=%s", 
        playerXs, playerYs, steam3ids, names, ids);
    httpRequest.POST();
}

void UtTraceInfoSender() {
    char utIds[55];
    char utTypes[130];
    char utXs[96];
    char utYs[96];
    int utCount = 0;
    for (int ut = 0; ut <= MAXUTILITY; ut++) {
        if (g_FlyingUtIds[ut] != -1) {
            char utType[16];
            float utXYZ[3];
            char utX[8];
            char utY[8];
            char utId[5];
            GetEntPropVector(g_FlyingUtIds[ut], Prop_Send, "m_vecOrigin", utXYZ);
            if (g_UtType[ut] == u_Smoke) StrCat(utType, sizeof(utType), "smokegrenade");
            if (g_UtType[ut] == u_Flash) StrCat(utType, sizeof(utType), "flashbang");
            if (g_UtType[ut] == u_Hegrenade) StrCat(utType, sizeof(utType), "hegrenade");
            if (g_UtType[ut] == u_Molotov) StrCat(utType, sizeof(utType), "molotov");
            if (g_UtType[ut] == u_Incgrenade) StrCat(utType, sizeof(utType), "incgrenade");
            if (g_UtType[ut] == u_Decoy) StrCat(utType, sizeof(utType), "decoy");
            FloatToString(utXYZ[0], utX, sizeof(utX));
            FloatToString(utXYZ[1], utY, sizeof(utY));
            IntToString(g_FlyingUtIds[ut], utId, sizeof(utId));
            if (utCount != 0) {
                StrCat(utTypes, sizeof(utTypes), CHARSPLIT);
                StrCat(utXs, sizeof(utXs), CHARSPLIT);
                StrCat(utYs, sizeof(utYs), CHARSPLIT);
                StrCat(utIds, sizeof(utIds), CHARSPLIT);
            }
            StrCat(utTypes, sizeof(utTypes), utType);
            StrCat(utXs, sizeof(utXs), utX);
            StrCat(utYs, sizeof(utYs), utY);
            StrCat(utIds, sizeof(utIds), utId);
            utCount ++;
        }
    }

    if (strlen(utTypes) == 0) return;
    System2HTTPRequest httpRequest = new System2HTTPRequest(
        utTraceCallBack,
        "http://127.0.0.1:5000/server-api/utility_trace"
    );
    httpRequest.SetData("utTypes=%s&utXs=%s&utYs=%s&utIds",
        utTypes, utXs, utYs, utIds)
    httpRequest.POST();
}

public Action:InfoSender(Handle timer) {
    PlayerMoveInfoSender();
    UtTraceInfoSender();
}

public utSenderCallBack(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
}

public senderCallBack(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
}

public mapSenderCallBack(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
}

public utTraceCallBack(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
}

public msgSenderCallBack(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
    if (success) {
        char[] content = new char[response.ContentLength + 1];
        char status[8];
        char ip[18], msg[48];
        response.GetContent(content, response.ContentLength + 1);
        JSON_Object json_obj = json_decode(content);
        json_obj.GetString("status", status, sizeof(status));
        if (StrEqual(status, "Good")) {
            json_obj.GetString("ip", ip, sizeof(ip));
            json_obj.GetString("msg", msg, sizeof(msg));
            PrintToChatAll("<\x05ip\x01:\x03%s\x01> \x0B%s\x01", ip, msg);
        }
    }
}

stock bool IsPlayer(int client) {
    return IsValidClient(client) && !IsFakeClient(client) && !IsClientSourceTV(client);
}

stock bool IsValidClient(int client) {
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}
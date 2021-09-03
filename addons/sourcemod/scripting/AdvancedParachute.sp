#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define PLUGIN_NAME "Advanced Parachute"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_AUTHOR "ESK0"

#define MAX_BUTTONS 25
#define TAG "[AdvancedParachute]"

#include "files/globals.sp"
#include "files/misc.sp"

public Plugin myinfo =
{
  name = PLUGIN_NAME,
  version = PLUGIN_VERSION,
  author = PLUGIN_AUTHOR,
  url = ""
};

bool ParachuteBool = true;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  g_hOnParachute = CreateGlobalForward("OnParachuteOpen", ET_Event, Param_Cell);
  RegPluginLibrary("AdvancedParachute");
  return APLRes_Success;
}

public void OnPluginStart()
{
  RegConsoleCmd("sm_parachute", Command_Parachute);
  BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "configs/AdvancedParachute.cfg");
  BuildPath(Path_SM, sDownloadFilePath, sizeof(sDownloadFilePath), "configs/AdvancedParachuteDownload.txt");
  arParachuteList = new ArrayList(256);
  smParachutes = new StringMap();

  HookEvent("player_death",Event_OnPlayerDeath);

  HookEvent("round_start", Event_OnRoundStart);
  HookEvent("round_end", Event_OnRoundEnd);

  g_iVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
  if(g_iVelocity == -1)
  {
    SetFailState("%s Can not find m_vecVelocity[0] offset",TAG);
  }

  g_hParachute = RegClientCookie("advanced_parachute_test", "Parachute clientprefs", CookieAccess_Private);

}
public void OnMapStart()
{
  g_iDefaultPar = -1;
  arParachuteList.Clear();
  smParachutes.Clear();
  AdvP_AddFilesToDownload();
  KeyValues kvFile = new KeyValues("AdvancedParachute");
  if(FileExists(sFilePath) == false)
  {
    SetFailState("%s Unable to find AdvancedParachute.cfg in %s",TAG, sFilePath);
    return;
  }
  kvFile.ImportFromFile(sFilePath);
  kvFile.GotoFirstSubKey();
  AdvP_AddParachute(kvFile);
  while(kvFile.GotoNextKey())
  {
    AdvP_AddParachute(kvFile);
  }
  if(g_iDefaultPar == -1)
  {
    SetFailState("%s Default parachute not found", TAG);
  }
  char sBuffer[64];
  arParachuteList.GetString(g_iDefaultPar, sBuffer ,sizeof(sBuffer));
  PrintToServer(sBuffer);
  delete kvFile;
}
public OnGameFrame()
{
  for(int client = 0; client <= MaxClients; client++)
  {
    if(IsValidClient(client, true))
    {
      if(g_iParachuteEnt[client] != 0)
      {
        float fVelocity[3];
      	float fFallspeed = 100 * (-1.0);
        GetEntDataVector(client, g_iVelocity, fVelocity);
        if(fVelocity[2] < 0.0)
        {
          if(fVelocity[2] >= fFallspeed)
          {
            fVelocity[2] = fFallspeed;
          }
          else
          {
            fVelocity[2] = fVelocity[2] + 50.0;
          }
          TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
          SetEntDataVector(client, g_iVelocity, fVelocity);
        }
      }
    }
  }
}
public Action Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  if(IsValidClient(client))
  {
    if(g_iParachuteEnt[client] != 0)
    {
      RemoveParachute(client);
    }
  }
  return Plugin_Continue;
}
public void OnClientPostAdminCheck(int client)
{
  if(IsValidClient(client))
  {
    g_iParachuteEnt[client] = 0;
    char sDefaultParachute[64];
    arParachuteList.GetString(g_iDefaultPar, sDefaultParachute , sizeof(sDefaultParachute));

    char sBuffer[64];
    char sParachute[512];
    char sParachuteExploded[2][512];
    GetClientCookie(client, g_hParachute, sBuffer, sizeof(sBuffer));
    smParachutes.GetString(sBuffer, sParachute, sizeof(sParachute));
    ExplodeString(sParachute, ";", sParachuteExploded, sizeof(sParachuteExploded), sizeof(sParachuteExploded[]));
    int iFlags = ReadFlagString(sParachuteExploded[1]);
    if(StrEqual(sBuffer, "", false))
    {
      SetClientCookie(client, g_hParachute, sDefaultParachute);
    }
    else
    {
      if(arParachuteList.FindString(sBuffer) == -1)
      {
        SetClientCookie(client, g_hParachute, sDefaultParachute);
      }
      else
      {
        if(CheckCommandAccess(client, "", iFlags, true) == false)
        {
          SetClientCookie(client, g_hParachute, sDefaultParachute);
        }
      }
    }
  }
}
public void OnClientDisconnect_Post(int client)
{
    g_LastButtons[client] = 0;
}

public Action Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ParachuteBool = false;
}

public Action Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ParachuteBool = true;
}

void OnButtonPress(int client, int button)
{
	if (ParachuteBool)
	{
		if (IsValidClient(client, true))
		{
			int cFlags = GetEntityFlags(client);
			if (button == IN_USE && g_iParachuteEnt[client] == 0 && IsInAir(client, cFlags))
			{
				AttachParachute(client);
			}
		}
	}
}

void OnButtonRelease(int client, int button)
{
  if(IsValidClient(client))
  {
    if(button == IN_USE && g_iParachuteEnt[client] != 0)
    {
      RemoveParachute(client);
    }
  }
}
public Action Command_Parachute(int client, int args)
{
  Menu menu = new Menu(h_parachutemenu);
  menu.SetTitle("Advanced Parachute");
  for(int i = 0 ; i < arParachuteList.Length; i++)
  {
    char sSectionName[64];
    char sBuffer[512];
    char sBufferExploded[2][512];
    arParachuteList.GetString(i, sSectionName, sizeof(sSectionName));
    smParachutes.GetString(sSectionName, sBuffer, sizeof(sBuffer));
    ExplodeString(sBuffer, ";", sBufferExploded, sizeof(sBufferExploded), sizeof(sBufferExploded[]));
    int iFlags = ReadFlagString(sBufferExploded[1]);
    char sClientPrefs[12];
    GetClientCookie(client, g_hParachute, sClientPrefs, sizeof(sClientPrefs));
    if(strlen(sBufferExploded[1]) != 0)
    {
      if(CheckCommandAccess(client, "", iFlags, true))
      {
        menu.AddItem(sSectionName, sSectionName, StrEqual(sSectionName, sClientPrefs, false) == true?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
      }
    }
    else
    {
      menu.AddItem(sSectionName, sSectionName, StrEqual(sSectionName, sClientPrefs, false) == true?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
    }
  }
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}
public int h_parachutemenu(Menu menu, MenuAction action, int client, int Position)
{
  if(IsValidClient(client))
  {
    if(action == MenuAction_Select)
    {
      char Item[64];
      menu.GetItem(Position, Item, sizeof(Item));
      SetClientCookie(client, g_hParachute, Item);
    }
    else if (action == MenuAction_End)
    {
      delete menu;
    }
  }
}

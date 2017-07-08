public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
  if(IsValidClient(client, true))
  {
    int cFlags = GetEntityFlags(client);
    if((IsInAir(client, cFlags) == false) && g_iParachuteEnt[client] != 0)
    {
      RemoveParachute(client);
    }
  }
  for (int i = 0; i < MAX_BUTTONS; i++)
  {
    int button = (1 << i);
    if ((buttons & button))
    {
      if (!(g_LastButtons[client] & button))
      {
        OnButtonPress(client, button);
      }
    }
    else if ((g_LastButtons[client] & button))
    {
      OnButtonRelease(client, button);
    }
  }
  g_LastButtons[client] = buttons;
  return Plugin_Continue;
}
stock bool IsValidClient(int client, bool alive = false)
{
  if(0 < client && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) == false && (alive == false || IsPlayerAlive(client)))
  {
    return true;
  }
  return false;
}

void AdvP_AddParachute(KeyValues kv)
{
  char sSectionName[64];
  char sBuffer[512];
  char sModelPath[PLATFORM_MAX_PATH];
  char sflag[32];
  kv.GetSectionName(sSectionName, sizeof(sSectionName));
  arParachuteList.PushString(sSectionName);
  kv.GetString("model", sModelPath, sizeof(sModelPath));
  if(FileExists(sModelPath) == false)
  {
    SetFailState("%s File: %s does not exists",TAG, sModelPath);
    return;
  }
  if(g_iDefaultPar == -1)
  {
    if(kv.GetNum("default", 0) != 1)
    {
      kv.GetString("flag", sflag, sizeof(sflag), "");
    }
    else
    {
      g_iDefaultPar = arParachuteList.Length-1;
    }
  }
  else
  {
    kv.GetString("flag", sflag, sizeof(sflag), "");
  }
  Format(sBuffer, sizeof(sBuffer), "%s;%s", sModelPath,sflag);
  smParachutes.SetString(sSectionName, sBuffer);
}
void AdvP_AddFilesToDownload()
{
  if(FileExists(sDownloadFilePath) == false)
  {
    SetFailState("%s Unable to find AdvancedParachuteDownload.txt in %s",TAG, sDownloadFilePath);
    return;
  }
  File hDownloadFile = OpenFile(sDownloadFilePath, "r");
  char sDownloadFile[PLATFORM_MAX_PATH];
  int iLen;
  while(hDownloadFile.ReadLine(sDownloadFile, sizeof(sDownloadFile)))
  {
    iLen = strlen(sDownloadFile);
    if(sDownloadFile[iLen-1] == '\n')
    {
      sDownloadFile[--iLen] = '\0';
    }
    TrimString(sDownloadFile);
    if(FileExists(sDownloadFile) == true)
    {
      int iNamelen = strlen(sDownloadFile) - 4;
      if(StrContains(sDownloadFile,".mdl",false) == iNamelen)
      {
      	PrecacheModel(sDownloadFile, true);
      }
      AddFileToDownloadsTable(sDownloadFile);
    }
    if(hDownloadFile.EndOfFile())
    {
      break;
    }
  }
  delete hDownloadFile;
}
void AttachParachute(int client)
{
  g_iParachuteEnt[client] = CreateEntityByName("prop_dynamic_override");
  if(IsValidEntity(g_iParachuteEnt[client]))
  {
    char sClientPrefs[64];
    char sBuffer[512];
    char sBufferExploded[2][512];
    GetClientCookie(client, g_hParachute, sClientPrefs, sizeof(sClientPrefs));
    smParachutes.GetString(sClientPrefs, sBuffer, sizeof(sBuffer));
    ExplodeString(sBuffer, ";", sBufferExploded, sizeof(sBufferExploded), sizeof(sBufferExploded[]));
    DispatchKeyValue(g_iParachuteEnt[client], "model", sBufferExploded[0]);
    SetEntProp(g_iParachuteEnt[client], Prop_Send, "m_usSolidFlags", 12);
    SetEntProp(g_iParachuteEnt[client], Prop_Data, "m_nSolidType", 6);
    SetEntProp(g_iParachuteEnt[client], Prop_Send, "m_CollisionGroup", 1);
    DispatchSpawn(g_iParachuteEnt[client]);
    float fOrigin[3];
    float fAngles[3];
    float fAdvP_Angles[3];
    GetClientAbsOrigin(client, fOrigin);
    GetClientAbsAngles(client, fAngles);
    fAdvP_Angles[1] = fAngles[1];
    TeleportEntity(g_iParachuteEnt[client], fOrigin, fAdvP_Angles, NULL_VECTOR);
    SetVariantString("!activator");
    AcceptEntityInput(g_iParachuteEnt[client], "SetParent", client);
    SetVariantString("idle");
    AcceptEntityInput(g_iParachuteEnt[client], "SetAnimation", -1, -1, 0);
  }
  else
  {
    g_iParachuteEnt[client] = 0;
  }
}
void RemoveParachute(int client)
{
  if(IsValidEntity(g_iParachuteEnt[client]))
  {
    AcceptEntityInput(g_iParachuteEnt[client], "KillHierarchy");
    g_iParachuteEnt[client] = 0;
  }
}
stock bool IsInAir(int client, int flags)
{
  return !(flags & FL_ONGROUND);
}

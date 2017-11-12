char sFilePath[PLATFORM_MAX_PATH];
char sDownloadFilePath[PLATFORM_MAX_PATH];
int g_LastButtons[MAXPLAYERS+1];

ArrayList arParachuteList;
StringMap smParachutes;

int g_iParachuteEnt[MAXPLAYERS+1];
int g_iDefaultPar = -1;

int g_iVelocity = -1;

Handle g_hParachute;

Handle g_hOnParachute;

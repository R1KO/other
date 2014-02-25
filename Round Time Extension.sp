#pragma semicolon 1
#include <sourcemod>

public Plugin:myinfo = 
{
	name = "Round Time Extension",
	author = "R1KO",
	version = "1.0"
};

public OnPluginStart()
{
	new Handle:hCvar = FindConVar("mp_roundtime"); 
	SetConVarBounds(hCvar, ConVarBound_Upper, true, 120.0); 
	CloseHandle(hCvar); 
}

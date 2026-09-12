#include "CampsManager.h"
#include "ScriptObjects.h"
#include "Player.h"
#include <cstring>

namespace
{
class CampsCommands : public AllCommandScript
{
public:
    CampsCommands() : AllCommandScript("camps_commands") {}
    bool CanExecuteCommand(ChatHandler* handler,char const* command,char const* args) override
    {
        if(std::strcmp(command,"camp")!=0) return true;
        Camps::Manager::Get().Handle(handler,args?args:"");
        return false;
    }
};
class CampsWorld : public WorldScript
{
public:
    CampsWorld() : WorldScript("camps_world",{WORLDHOOK_ON_STARTUP,WORLDHOOK_ON_AFTER_CONFIG_LOAD,WORLDHOOK_ON_UPDATE,WORLDHOOK_ON_SHUTDOWN}) {}
    void OnStartup() override { Camps::Manager::Get().Load(); }
    void OnAfterConfigLoad(bool reload) override { if(reload) Camps::Manager::Get().Load(); }
    void OnUpdate(uint32) override { Camps::Manager::Get().Tick(); }
    void OnShutdown() override { Camps::Manager::Get().Cleanup(); }
};
class CampsPlayer : public PlayerScript
{
public:
    CampsPlayer() : PlayerScript("camps_player",{PLAYERHOOK_ON_BEFORE_LOGOUT,PLAYERHOOK_ON_BEFORE_TELEPORT,PLAYERHOOK_ON_MAP_CHANGED}) {}
    void OnBeforeLogout(Player* p) override { Camps::Manager::Get().QueueCleanup(p->GetGUIDLow()); }
    void OnBeforeTeleport(Player* p,uint32,float,float,float,float) override { Camps::Manager::Get().QueueCleanup(p->GetGUIDLow()); }
    void OnMapChanged(Player* p) override { Camps::Manager::Get().QueueCleanup(p->GetGUIDLow()); }
};
}
void Addmod_camps_twowScripts()
{
    new CampsCommands(); new CampsWorld(); new CampsPlayer();
}

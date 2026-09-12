#pragma once
#include "CampsProtocol.h"
#include <map>
#include <deque>
#include <mutex>
#include <set>

class Player;
class WorldObject;
class GameObject;
class Creature;
class ChatHandler;
namespace Camps
{
struct Transform { float x = 0, y = 0, z = 0, o = 0; };
struct Camp { uint32_t owner = 0, map = 0; Transform pos; bool publicVisit = false; float radius = 40.0f; };
struct Prop { uint32_t guid = 0, owner = 0, camp = 0, entry = 0, map = 0; Transform pos; uint8_t kind = 0; };
struct CatalogEntry { uint32_t entry = 0, display = 0, type = 0; float size = 1.0f; std::string name, category; bool player = true; uint8_t kind = 0; };
struct Edit
{
    uint32_t token = 0, map = 0, instance = 0, live = 0, entry = 0, source = 0;
    Transform original, working;
    uint64_t touched = 0;
    bool originalActive = false;
    uint8_t kind = 0;
};
struct Undo { enum Kind { Create, Move, Remove } kind; Prop before; };
struct Client
{
    bool hello = false, gmMode = false;
    uint32_t lastRequest = 0;
    uint64_t lastAction = 0, lastSearch = 0, lastTravel = 0, breakUntil = 0;
    Edit edit;
    std::deque<Undo> undo;
};
struct Override { bool enabled = true, player = false; std::string category; };
class Manager
{
public:
    static Manager& Get();
    void Load();
    void Tick();
    void Cleanup();
    void QueueCleanup(uint32_t player);
    void Handle(ChatHandler* handler, std::string const& input);
    CatalogEntry GetTemplate(uint32_t entry, uint8_t kind) const;
    bool Safe(uint32_t entry, uint8_t kind = 0) const;
    bool SafeGameObject(uint32_t entry) const;
    bool SafeCreature(uint32_t entry) const;
    bool SafeItem(uint32_t entry) const;
private:
    bool enabled = false, players = false, visits = false, failed = false;
    uint32_t cap = 100, timeout = 120, nextToken = 1, travelCooldown = 60;
    float radius = 40, spacing = 100;
    std::map<uint32_t, Camp> camps;
    std::map<uint32_t, Prop> props;
    std::map<uint32_t, Override> overrides;
    std::map<uint32_t, Client> clients;
    std::set<uint32_t> forbiddenMaps, forbiddenZones, forbiddenAreas;
    std::mutex cleanupMutex;
    std::set<uint32_t> cleanupQueue;
    bool cleanupAll = false;
    bool GM(Player* player) const;
    bool Allowed(Player* player, Client const& client) const;
    bool Location(Player* player, Client const& client, Transform const& pos, bool claiming = false) const;
    unsigned Count(uint32_t account) const;
    void Cancel(Client& client);
    WorldObject* Resolve(Edit const& edit);
    WorldObject* Resolve(Prop const& prop);
    bool Current(Prop const& prop) const;
    bool AreaAllowed(uint32_t map, Transform const& pos) const;
    void Relocate(WorldObject* object, Transform const& pos);
    bool Begin(Player* player, Client& client, uint32_t entry, Prop const* source, bool duplicate, uint8_t kind = 0);
    bool Save(Player* player, Client& client, Prop& result);
    bool Erase(Prop const& prop);
    bool Restore(Prop const& prop);
    bool Commit();
    void Push(Client& client, Undo::Kind kind, Prop const& prop);
};
}

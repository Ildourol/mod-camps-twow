#include "CampsManager.h"
#include "Player.h"
#include "GameObject.h"
#include "Creature.h"
#include "ObjectMgr.h"
#include "ObjectAccessor.h"
#include "Map.h"
#include "MapManager.h"
#include "GridMap.h"
#include "World.h"
#include "WorldSession.h"
#include "Chat.h"
#include "Config/Config.h"
#include "Database/DatabaseEnv.h"
#include "DBCStores.h"
#include "Log.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <memory>
#include <cctype>

namespace Camps
{
namespace
{
uint64_t Now() { return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
uint32_t Account(Player* p) { return p->GetSession()->GetAccountId(); }
Transform Position(Player* p) { return {p->GetPositionX(), p->GetPositionY(), p->GetPositionZ(), p->GetOrientation()}; }
float Distance(Transform const& a, Transform const& b)
{ return std::sqrt((a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y)+(a.z-b.z)*(a.z-b.z)); }
std::string Lower(std::string s)
{ for (char& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c))); return s; }
std::string Category(std::string const& name)
{
    std::string n = Lower(name);
    for (auto const& pair : {std::make_pair("tent", "Shelter"), {"house", "Buildings"},
        {"table", "Furniture"}, {"chair", "Furniture"}, {"fire", "Fire & Light"},
        {"torch", "Fire & Light"}, {"crate", "Storage"}, {"barrel", "Storage"},
        {"anvil", "Crafting"}, {"banner", "Banners"}, {"food", "Food & Provisions"},
        {"tree", "Nature"}, {"bush", "Nature"}, {"fence", "Yard"}, {"smoke", "Atmosphere"}})
        if (n.find(pair.first) != std::string::npos) return pair.second;
    return "Miscellaneous";
}
bool IdList(std::string const& text, std::set<uint32_t>& out)
{
    out.clear(); if(text.empty()) return true;
    if(text.size()>512) return false;
    size_t start=0;
    for(;;)
    {
        auto end=text.find(',',start); std::string item=text.substr(start,end==std::string::npos?end:end-start);
        item.erase(std::remove(item.begin(),item.end(),' '),item.end());
        uint32_t id=0; if(!UInt(item,id) || out.size()>=64) return false;
        out.insert(id); if(end==std::string::npos) return true; start=end+1;
    }
}
}
bool Manager::SafeGameObject(uint32_t entry) const
{
    auto t = sObjectMgr.GetGameObjectInfo(entry);
    if (!t || (t->type != GAMEOBJECT_TYPE_GENERIC && t->type != GAMEOBJECT_TYPE_CHAIR && t->type != GAMEOBJECT_TYPE_MAP_OBJECT) ||
        t->ScriptId || t->PhaseQuestId || t->MinMoneyLoot || t->MaxMoneyLoot ||
        !t->displayId || !std::isfinite(t->size) || t->size <= 0 || t->size > 20 ||
        !sGameObjectDisplayInfoStore.LookupEntry(t->displayId)) return false;
    for (unsigned i = 0; i < 24; ++i) if (i != 3 && t->raw.data[i]) return false;
    auto q = sObjectMgr.GetGOQuestRelationsMapBounds(entry);
    auto involved = sObjectMgr.GetGOQuestInvolvedRelationsMapBounds(entry);
    return q.first == q.second && involved.first == involved.second;
}
static char const* GetCreatureTypeName(uint32_t type)
{
    switch (type)
    {
        case CREATURE_TYPE_BEAST: return "Beast";
        case CREATURE_TYPE_DRAGONKIN: return "Dragonkin";
        case CREATURE_TYPE_DEMON: return "Demon";
        case CREATURE_TYPE_ELEMENTAL: return "Elemental";
        case CREATURE_TYPE_GIANT: return "Giant";
        case CREATURE_TYPE_UNDEAD: return "Undead";
        case CREATURE_TYPE_HUMANOID: return "Humanoid";
        case CREATURE_TYPE_CRITTER: return "Critter";
        case CREATURE_TYPE_MECHANICAL: return "Mechanical";
        case CREATURE_TYPE_TOTEM: return "Totem";
        default: return "Creature";
    }
}
static char const* GetItemClassName(uint32_t type)
{
    switch (type)
    {
        case 0: return "Consumable";
        case 1: return "Container";
        case 2: return "Weapon";
        case 4: return "Armor";
        case 7: return "Trade Goods";
        case 9: return "Book";
        case 15: return "Miscellaneous";
        default: return "Items";
    }
}
bool Manager::SafeCreature(uint32_t entry) const
{
    auto c = sObjectMgr.GetCreatureTemplate(entry);
    if (!c || c->display_id[0] == 0 || c->rank == CREATURE_ELITE_WORLDBOSS) return false;
    if (entry == 1842) return false;
    return true;
}
bool Manager::SafeItem(uint32_t entry) const
{
    auto proto = sObjectMgr.GetItemPrototype(entry);
    return proto && proto->DisplayInfoID != 0;
}
bool Manager::Safe(uint32_t entry, uint8_t kind) const
{
    auto ov = overrides.find(entry);
    if (ov != overrides.end() && !ov->second.enabled) return false;
    if (kind == 1) return SafeCreature(entry);
    if (kind == 2) return SafeItem(entry);
    return SafeGameObject(entry);
}
CatalogEntry Manager::GetTemplate(uint32_t entry, uint8_t kind) const
{
    CatalogEntry out{entry, 0, 0, 1.0f, "", "Miscellaneous", true, kind};
    auto ov = overrides.find(entry);
    if (kind == 1)
    {
        if (auto c = sObjectMgr.GetCreatureTemplate(entry))
        {
            out.display = c->display_id[0];
            out.type = c->type;
            out.size = c->scale > 0.0f ? c->scale : 1.0f;
            out.name = c->name.substr(0, 48);
            out.category = GetCreatureTypeName(c->type);
            out.player = (ov == overrides.end() || ov->second.player);
            if (ov != overrides.end() && !ov->second.category.empty()) out.category = ov->second.category;
        }
    }
    else if (kind == 2)
    {
        if (auto proto = sObjectMgr.GetItemPrototype(entry))
        {
            out.display = proto->DisplayInfoID;
            out.type = proto->Class;
            out.size = 1.0f;
            out.name = proto->Name1.substr(0, 48);
            out.category = GetItemClassName(proto->Class);
            out.player = (ov == overrides.end() || ov->second.player);
            if (ov != overrides.end() && !ov->second.category.empty()) out.category = ov->second.category;
        }
    }
    else
    {
        if (auto t = sObjectMgr.GetGameObjectInfo(entry))
        {
            out.display = t->displayId;
            out.type = t->type;
            out.size = t->size;
            out.name = t->name.substr(0, 48);
            out.category = (t->type == GAMEOBJECT_TYPE_MAP_OBJECT) ? "Buildings" : (ov != overrides.end() && !ov->second.category.empty() ? ov->second.category : Category(t->name));
            out.player = (ov == overrides.end() || ov->second.player);
        }
    }
    return out;
}
static bool StartTransaction() { return !WorldDatabase.InTransaction() && WorldDatabase.BeginTransaction(); }
Manager& Manager::Get() { static Manager manager; return manager; }
bool Manager::GM(Player* p) const { return p->GetSession()->GetSecurity() >= SEC_DEVELOPER; }
bool Manager::Allowed(Player* p, Client const& c) const { return enabled && !failed && (c.gmMode ? GM(p) : players); }
unsigned Manager::Count(uint32_t owner) const
{ unsigned n = 0; for (auto const& pair : props) if (pair.second.camp == owner) ++n; return n; }

void Manager::Load()
{
    Cleanup();
    enabled = false;
    if (failed || !sConfig.GetBoolDefault("Camps.Enable", false)) return;
    players = sConfig.GetBoolDefault("Camps.Players", false);
    visits = sConfig.GetBoolDefault("Camps.Visits", false);
    cap = std::max(1, std::min(500, sConfig.GetIntDefault("Camps.PropCap", 100)));
    timeout = std::max(15, std::min(600, sConfig.GetIntDefault("Camps.EditTimeoutSeconds", 120)));
    travelCooldown = std::max(15, std::min(3600, sConfig.GetIntDefault("Camps.TravelCooldownSeconds", 60)));
    if(!IdList(sConfig.GetStringDefault("Camps.ForbiddenMaps", ""),forbiddenMaps) ||
        !IdList(sConfig.GetStringDefault("Camps.ForbiddenZones", ""),forbiddenZones) ||
        !IdList(sConfig.GetStringDefault("Camps.ForbiddenAreas", ""),forbiddenAreas))
    { sLog.outError("[camps] Invalid forbidden map/zone/area list; disabled."); return; }
    radius = static_cast<float>(std::max(5, std::min(100, sConfig.GetIntDefault("Camps.Radius", 40))));
    spacing = static_cast<float>(std::max(static_cast<int>(radius*2), std::min(1000, sConfig.GetIntDefault("Camps.MinimumSpacing", 100))));
    std::unique_ptr<QueryResult> schema(WorldDatabase.Query("SELECT version FROM camps_schema WHERE id=1"));
    if (!schema || schema->Fetch()[0].GetUInt32() != 1) { sLog.outError("[camps] Missing/incompatible schema; disabled."); return; }
    std::unique_ptr<QueryResult> engines(WorldDatabase.Query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name IN ('gameobject','game_event_gameobject','gameobject_battleground','camps_camp','camps_prop') AND engine='InnoDB'"));
    if (!engines || engines->Fetch()[0].GetUInt32() != 5) { sLog.outError("[camps] Transactional tables required; see docs/database.md. Disabled."); return; }
    camps.clear(); props.clear(); overrides.clear();
    std::unique_ptr<QueryResult> counts(WorldDatabase.Query("SELECT (SELECT COUNT(*) FROM camps_camp), (SELECT COUNT(*) FROM camps_prop), (SELECT COUNT(*) FROM camps_catalog_override)"));
    if (!counts || counts->Fetch()[0].GetUInt32() > 2000 || counts->Fetch()[1].GetUInt32() > 10000 || counts->Fetch()[2].GetUInt32()>20000) return;
    WorldDatabase.DirectExecute("ALTER TABLE camps_camp ADD COLUMN IF NOT EXISTS radius FLOAT NOT NULL DEFAULT 40");
    std::unique_ptr<QueryResult> rows(WorldDatabase.Query("SELECT account,map,x,y,z,o,public_visit,radius FROM camps_camp ORDER BY account LIMIT 2000"));
    if (rows) do
    {
        auto f = rows->Fetch(); Camp camp;
        camp.owner=f[0].GetUInt32(); camp.map=f[1].GetUInt32();
        camp.pos={f[2].GetFloat(),f[3].GetFloat(),f[4].GetFloat(),f[5].GetFloat()};
        camp.publicVisit=f[6].GetBool();
        camp.radius=(rows->GetFieldCount() >= 8 && f[7].GetFloat() > 5.0f) ? f[7].GetFloat() : radius;
        if (!camp.owner || !MapManager::IsValidMapCoord(camp.map,camp.pos.x,camp.pos.y,camp.pos.z,camp.pos.o)) return;
        camps.emplace(camp.owner,camp);
    } while (rows->NextRow());
    rows.reset(WorldDatabase.Query("SELECT guid,account,camp,entry FROM camps_prop ORDER BY guid LIMIT 10000"));
    if (rows) do
    {
        auto f = rows->Fetch(); Prop prop;
        prop.guid=f[0].GetUInt32(); prop.owner=f[1].GetUInt32(); prop.camp=f[2].GetUInt32(); prop.entry=f[3].GetUInt32();
        auto godata=sObjectMgr.GetGOData(prop.guid);
        auto crdata=godata ? nullptr : sObjectMgr.GetCreatureData(prop.guid);
        if ((!godata && !crdata) || !prop.owner || (prop.camp && (prop.camp != prop.owner || !camps.count(prop.camp))))
        { sLog.outError("[camps] Ownership/native spawn mismatch; repair required. Disabled."); return; }
        if (godata)
        {
            if (godata->id != prop.entry) { sLog.outError("[camps] GO entry mismatch. Disabled."); return; }
            prop.kind=0; prop.map=godata->position.mapId;
            prop.pos={godata->position.x,godata->position.y,godata->position.z,godata->position.o};
        }
        else
        {
            if (crdata->creature_id[0] != prop.entry) { sLog.outError("[camps] Creature entry mismatch. Disabled."); return; }
            prop.kind=1; prop.map=crdata->position.mapId;
            prop.pos={crdata->position.x,crdata->position.y,crdata->position.z,crdata->position.o};
        }
        props.emplace(prop.guid,prop);
    } while (rows->NextRow());
    rows.reset(WorldDatabase.Query("SELECT entry,enabled,player_allowed,category FROM camps_catalog_override ORDER BY entry LIMIT 20000"));
    if (rows) do { auto f=rows->Fetch(); overrides.emplace(f[0].GetUInt32(),Override{f[1].GetBool(),f[2].GetBool(),f[3].GetCppString().substr(0,32)}); } while(rows->NextRow());
    if(camps.size()!=counts->Fetch()[0].GetUInt32() || props.size()!=counts->Fetch()[1].GetUInt32() || overrides.size()!=counts->Fetch()[2].GetUInt32())
    { sLog.outError("[camps] Incomplete table load; disabled."); return; }
    enabled=true;
    sLog.outString("[camps] Loaded on-demand catalogue (%u overrides), %u camps, %u props.",unsigned(overrides.size()),unsigned(camps.size()),unsigned(props.size()));
}
bool Manager::Location(Player* p, Client const& c, Transform const& pos, bool claiming) const
{
    if (!Allowed(p,c) || !p->IsInWorld() || !p->IsAlive() || p->IsInCombat() || p->GetTransport() ||
        p->GetMap()->Instanceable() || !MapManager::IsValidMapCoord(p->GetMapId(),pos.x,pos.y,pos.z,pos.o) ||
        Distance(Position(p),pos)>60) return false;
    if(sMapMgr.GetContinentInstanceId(p->GetMapId(),pos.x,pos.y)!=p->GetInstanceId()) return false;
    if (c.gmMode) return true;
    if (p->GetMapId() != 0 && p->GetMapId() != 1) return false;
    if (!AreaAllowed(p->GetMapId(), pos)) return false;
    uint32_t account = Account(p);
    auto it = camps.find(account);
    if (claiming)
    {
        for (auto const& pair : camps)
        {
            if (pair.first == account) continue;
            if (pair.second.map != p->GetMapId()) continue;
            float dx = pair.second.pos.x - pos.x, dy = pair.second.pos.y - pos.y;
            if (std::sqrt(dx * dx + dy * dy) < spacing) return false;
        }
        return true;
    }
    if (it == camps.end() || it->second.map != p->GetMapId()) return false;
    float dx = it->second.pos.x - pos.x, dy = it->second.pos.y - pos.y;
    float campRadius = (it->second.radius > 5.0f) ? it->second.radius : radius;
    return std::sqrt(dx * dx + dy * dy) <= campRadius;
}
bool Manager::AreaAllowed(uint32_t map, Transform const& pos) const
{
    if (forbiddenMaps.count(map)) return false;
    uint32_t zone = 0, area = 0;
    sTerrainMgr.GetZoneAndAreaId(zone, area, map, pos.x, pos.y, pos.z);
    return !forbiddenZones.count(zone) && !forbiddenAreas.count(area);
}
WorldObject* Manager::Resolve(Edit const& e)
{
    if (!e.live) return nullptr;
    auto map = sMapMgr.FindMap(e.map, e.instance);
    if (!map) return nullptr;
    if (e.kind == 1) return map->GetCreature(ObjectGuid(HIGHGUID_UNIT, e.entry, e.live));
    return map->GetGameObject(ObjectGuid(HIGHGUID_GAMEOBJECT, e.entry, e.live));
}
WorldObject* Manager::Resolve(Prop const& p)
{
    if (!p.guid) return nullptr;
    auto map = sMapMgr.FindMap(p.map, sMapMgr.GetContinentInstanceId(p.map, p.pos.x, p.pos.y));
    if (!map) return nullptr;
    if (p.kind == 1) return map->GetCreature(ObjectGuid(HIGHGUID_UNIT, p.entry, p.guid));
    return map->GetGameObject(ObjectGuid(HIGHGUID_GAMEOBJECT, p.entry, p.guid));
}
bool Manager::Current(Prop const& prop) const
{
    if (prop.kind == 1)
    {
        auto data = sObjectMgr.GetCreatureData(prop.guid);
        return data && data->creature_id[0] == prop.entry && data->position.mapId == prop.map &&
            std::abs(data->position.x - prop.pos.x) < 0.01f && std::abs(data->position.y - prop.pos.y) < 0.01f &&
            std::abs(data->position.z - prop.pos.z) < 0.01f && std::abs(data->position.o - prop.pos.o) < 0.01f;
    }
    auto data = sObjectMgr.GetGOData(prop.guid);
    return data && data->id == prop.entry && data->position.mapId == prop.map &&
        std::abs(data->position.x - prop.pos.x) < 0.01f && std::abs(data->position.y - prop.pos.y) < 0.01f &&
        std::abs(data->position.z - prop.pos.z) < 0.01f && std::abs(data->position.o - prop.pos.o) < 0.01f;
}
void Manager::Relocate(WorldObject* object, Transform const& pos)
{
    auto map = object->GetMap();
    if (!map) return;
    if (auto go = dynamic_cast<GameObject*>(object))
    {
        map->Remove(go, false);
        go->Relocate(pos.x, pos.y, pos.z, pos.o);
        go->SetFloatValue(GAMEOBJECT_POS_X, pos.x);
        go->SetFloatValue(GAMEOBJECT_POS_Y, pos.y);
        go->SetFloatValue(GAMEOBJECT_POS_Z, pos.z);
        go->SetFloatValue(GAMEOBJECT_FACING, pos.o);
        go->UpdateRotationFields();
        map->Add(go);
    }
    else if (auto cr = dynamic_cast<Creature*>(object))
    {
        cr->NearTeleportTo(pos.x, pos.y, pos.z, pos.o);
        cr->SetHomePosition(pos.x, pos.y, pos.z, pos.o);
    }
}
void Manager::Cancel(Client& c)
{
    if (c.edit.token)
    {
        if (auto object=Resolve(c.edit))
        {
            if (c.edit.source) { Relocate(object,c.edit.original); object->SetActiveObjectState(c.edit.originalActive); }
            else
            {
                if (auto go = dynamic_cast<GameObject*>(object)) { go->SetRespawnTime(0); go->Delete(); }
                else if (auto cr = dynamic_cast<Creature*>(object)) { cr->AddObjectToRemoveList(); }
            }
        }
        c.edit=Edit{};
    }
}
void Manager::Cleanup() { for(auto& pair:clients) Cancel(pair.second); clients.clear(); }
void Manager::QueueCleanup(uint32_t player)
{
    std::lock_guard<std::mutex> guard(cleanupMutex);
    if(cleanupQueue.size()<4096) cleanupQueue.insert(player); else cleanupAll=true;
}
void Manager::Tick()
{
    std::set<uint32_t> pending;
    bool all=false;
    { std::lock_guard<std::mutex> guard(cleanupMutex); pending.swap(cleanupQueue); all=cleanupAll; cleanupAll=false; }
    if(all) { Cleanup(); return; }
    uint64_t now=Now();
    for(auto it=clients.begin();it!=clients.end();)
    {
        auto p=ObjectAccessor::FindPlayer(ObjectGuid(HIGHGUID_PLAYER,it->first));
        auto& c=it->second;
        if(!p || pending.count(it->first)) { Cancel(c); it=clients.erase(it); continue; }
        if(c.edit.token && (!Allowed(p,c) || now-c.edit.touched>timeout*1000 || p->GetMapId()!=c.edit.map || p->GetInstanceId()!=c.edit.instance || !Resolve(c.edit))) Cancel(c);
        ++it;
    }
}
bool Manager::Begin(Player* p, Client& c, uint32_t entry, Prop const* source, bool duplicate, uint8_t kind)
{
    if(c.edit.token || !Safe(entry, kind)) return false;
    CatalogEntry cat = GetTemplate(entry, kind);
    if(!c.gmMode && !cat.player) return false;
    if(source)
    {
        if(!Current(*source)) return false;
        if(source->map!=p->GetMapId() || (!c.gmMode && (source->owner!=Account(p) || source->camp!=Account(p)))) return false;
        for(auto const& pair:clients) if(pair.second.edit.source==source->guid) return false;
    }
    Transform pos=source ? source->pos : Position(p);
    if(!source) { pos.x+=3*std::cos(pos.o); pos.y+=3*std::sin(pos.o); }
    if(!Location(p,c,pos) || ((!source || duplicate) && (props.size()>=10000 || (!c.gmMode && Count(Account(p))>=cap)))) return false;
    Edit edit; edit.map=p->GetMapId(); edit.instance=p->GetInstanceId(); edit.entry=entry; edit.kind=kind; edit.original=pos; edit.working=pos;
    edit.token=nextToken++; if(!edit.token) edit.token=nextToken++;
    edit.touched=Now();
    if(source && !duplicate)
    {
        auto obj=Resolve(*source); if(!obj || obj->IsDeleted()) return false;
        edit.live=source->guid; edit.source=source->guid; edit.originalActive=obj->isActiveObject(); obj->SetActiveObjectState(true);
    }
    else
    {
        if (kind == 1)
        {
            auto cinfo = sObjectMgr.GetCreatureTemplate(entry);
            if (!cinfo) return false;
            edit.live=p->GetMap()->GenerateLocalLowGuid(HIGHGUID_UNIT);
            auto cr=std::unique_ptr<Creature>(new Creature);
            CreatureCreatePos cpos(p->GetMap(), pos.x, pos.y, pos.z, pos.o);
            if (!cr->Create(edit.live, cpos, cinfo, entry)) return false;
            cr->SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NOT_SELECTABLE | UNIT_FLAG_SPAWNING);
            cr->SetActiveObjectState(true);
            p->GetMap()->Add(cr.release());
        }
        else
        {
            edit.live=p->GetMap()->GenerateLocalLowGuid(HIGHGUID_GAMEOBJECT);
            auto obj=std::unique_ptr<GameObject>(new GameObject);
            if(!obj->Create(edit.live,entry,p->GetMap(),pos.x,pos.y,pos.z,pos.o,0,0,0,0,GO_ANIMPROGRESS_DEFAULT,GO_STATE_READY)) return false;
            obj->SetFlag(GAMEOBJECT_FLAGS,GO_FLAG_NO_INTERACT); obj->SetActiveObjectState(true);
            p->GetMap()->Add(obj.release());
        }
    }
    c.edit=edit; return true;
}
bool Manager::Commit()
{
    if(WorldDatabase.CommitTransactionDirect()) return true;
    failed=true; enabled=false;
    sLog.outError("[camps] Persistence failed. Building disabled until restart; inspect DB/native cache reconciliation.");
    return false;
}
void Manager::Push(Client& c, Undo::Kind kind, Prop const& prop)
{
    for(auto& pair:clients) if(&pair.second!=&c)
    {
        auto& history=pair.second.undo;
        history.erase(std::remove_if(history.begin(),history.end(),[&](Undo const& u){ return u.before.guid==prop.guid; }),history.end());
    }
    if(c.undo.size()>=20) c.undo.pop_front(); c.undo.push_back({kind,prop});
}
bool Manager::Save(Player* p, Client& c, Prop& result)
{
    auto& e=c.edit;
    if(!e.token || !Location(p,c,e.working) || !Safe(e.entry, e.kind)) return false;
    CatalogEntry cat = GetTemplate(e.entry, e.kind);
    if(!c.gmMode && !cat.player) return false;
    auto live=Resolve(e); if(!live || live->IsDeleted()) return false;
    if (e.kind == 1)
    {
        if(e.source)
        {
            auto it=props.find(e.source); if(it==props.end() || !Current(it->second) || (!c.gmMode && it->second.owner!=Account(p))) return false;
            Prop old=it->second;
            if(!StartTransaction()) return false;
            CreatureData originalData=*sObjectMgr.GetCreatureData(old.guid);
            sObjectMgr.RemoveCreatureFromGrid(old.guid,sObjectMgr.GetCreatureData(old.guid));
            live->SetActiveObjectState(e.originalActive);
            auto cr = dynamic_cast<Creature*>(live);
            if (cr) cr->SaveToDB(e.map);
            sObjectMgr.NewOrExistCreatureData(old.guid).instanciatedContinentInstanceId=e.instance;
            if(!Commit())
            {
                sObjectMgr.NewOrExistCreatureData(old.guid)=originalData;
                sObjectMgr.AddCreatureToGrid(old.guid,sObjectMgr.GetCreatureData(old.guid));
                Cancel(c); return false;
            }
            sObjectMgr.AddCreatureToGrid(old.guid,sObjectMgr.GetCreatureData(old.guid));
            if (it->second.camp == 0 && camps.count(Account(p)))
            {
                it->second.camp = Account(p);
                WorldDatabase.PExecute("UPDATE camps_prop SET camp=%u WHERE guid=%u", Account(p), old.guid);
            }
            it->second.pos=e.working; result=it->second; Push(c,Undo::Move,old); e=Edit{}; return true;
        }
        if(props.size()>=10000 || (!c.gmMode && Count(Account(p))>=cap)) return false;
        uint32_t guid=sObjectMgr.GenerateStaticCreatureLowGuid(); if(!guid) return false;
        auto cr=std::unique_ptr<Creature>(new Creature);
        auto pos=e.working;
        auto cinfo=sObjectMgr.GetCreatureTemplate(e.entry);
        CreatureCreatePos cpos(p->GetMap(), pos.x, pos.y, pos.z, pos.o);
        if(!cinfo || !cr->Create(guid,cpos,cinfo,e.entry)) return false;
        uint32_t campId = camps.count(Account(p)) ? Account(p) : 0u;
        result={guid,Account(p),campId,e.entry,e.map,pos,1};
        if(!StartTransaction()) return false;
        cr->SaveToDB(e.map);
        sObjectMgr.NewOrExistCreatureData(guid).instanciatedContinentInstanceId=e.instance;
        WorldDatabase.PExecute("INSERT INTO camps_prop (guid,account,camp,entry) VALUES (%u,%u,%u,%u)",guid,result.owner,result.camp,result.entry);
        if(!Commit()) { sObjectMgr.DeleteCreatureData(guid); Cancel(c); return false; }
        if(!cr->LoadFromDB(guid,p->GetMap())) { failed=true; enabled=false; Cancel(c); return false; }
        p->GetMap()->Add(cr.release()); sObjectMgr.AddCreatureToGrid(guid,sObjectMgr.GetCreatureData(guid));
        props.emplace(guid,result); Push(c,Undo::Create,result); Cancel(c); return true;
    }
    if(e.source)
    {
        auto it=props.find(e.source); if(it==props.end() || !Current(it->second) || (!c.gmMode && it->second.owner!=Account(p))) return false;
        Prop old=it->second;
        if(!StartTransaction()) return false;
        GameObjectData originalData=*sObjectMgr.GetGOData(old.guid);
        sObjectMgr.RemoveGameobjectFromGrid(old.guid,sObjectMgr.GetGOData(old.guid));
        live->SetActiveObjectState(e.originalActive);
        auto go = dynamic_cast<GameObject*>(live);
        if (go) go->SaveToDB();
        sObjectMgr.NewGOData(old.guid).instanciatedContinentInstanceId=e.instance;
        if(!Commit())
        {
            sObjectMgr.NewGOData(old.guid)=originalData;
            sObjectMgr.AddGameobjectToGrid(old.guid,sObjectMgr.GetGOData(old.guid));
            Cancel(c); return false;
        }
        sObjectMgr.AddGameobjectToGrid(old.guid,sObjectMgr.GetGOData(old.guid));
        if (it->second.camp == 0 && camps.count(Account(p)))
        {
            it->second.camp = Account(p);
            WorldDatabase.PExecute("UPDATE camps_prop SET camp=%u WHERE guid=%u", Account(p), old.guid);
        }
        it->second.pos=e.working; result=it->second; Push(c,Undo::Move,old); e=Edit{}; return true;
    }
    if(props.size()>=10000 || (!c.gmMode && Count(Account(p))>=cap)) return false;
    uint32_t guid=sObjectMgr.GenerateStaticGameObjectLowGuid(); if(!guid) return false;
    auto object=std::unique_ptr<GameObject>(new GameObject);
    auto pos=e.working;
    if(!object->Create(guid,e.entry,p->GetMap(),pos.x,pos.y,pos.z,pos.o,0,0,0,0,GO_ANIMPROGRESS_DEFAULT,GO_STATE_READY)) return false;
    uint32_t campId = camps.count(Account(p)) ? Account(p) : 0u;
    result={guid,Account(p),campId,e.entry,e.map,pos,0};
    if(!StartTransaction()) return false;
    object->SetRespawnTime(300); object->SaveToDB(e.map);
    sObjectMgr.NewGOData(guid).instanciatedContinentInstanceId=e.instance;
    WorldDatabase.PExecute("INSERT INTO camps_prop (guid,account,camp,entry) VALUES (%u,%u,%u,%u)",guid,result.owner,result.camp,result.entry);
    if(!Commit()) { sObjectMgr.DeleteGOData(guid); Cancel(c); return false; }
    if(!object->LoadFromDB(guid,p->GetMap())) { failed=true; enabled=false; Cancel(c); return false; }
    p->GetMap()->Add(object.release()); sObjectMgr.AddGameobjectToGrid(guid,sObjectMgr.GetGOData(guid));
    props.emplace(guid,result); Push(c,Undo::Create,result); Cancel(c); return true;
}
bool Manager::Erase(Prop const& prop)
{
    if(!StartTransaction()) return false;
    auto object=Resolve(prop);
    if (prop.kind == 1)
    {
        CreatureData originalData;
        bool hasData = false;
        if(auto data = sObjectMgr.GetCreatureData(prop.guid))
        {
            originalData = *data;
            hasData = true;
        }
        if (object)
        {
            if (auto cr = dynamic_cast<Creature*>(object)) cr->DeleteFromDB();
        }
        else
        {
            sObjectMgr.DeleteCreatureData(prop.guid);
            WorldDatabase.PExecute("DELETE FROM creature WHERE guid=%u", prop.guid);
        }
        WorldDatabase.PExecute("DELETE FROM camps_prop WHERE guid=%u", prop.guid);
        if(!Commit())
        {
            if(hasData)
            {
                sObjectMgr.NewOrExistCreatureData(prop.guid) = originalData;
                sObjectMgr.AddCreatureToGrid(prop.guid, sObjectMgr.GetCreatureData(prop.guid));
            }
            return false;
        }
        if (object)
        {
            if (auto cr = dynamic_cast<Creature*>(object)) { cr->AddObjectToRemoveList(); }
        }
    }
    else
    {
        GameObjectData originalData;
        bool hasData = false;
        if(auto data = sObjectMgr.GetGOData(prop.guid))
        {
            originalData = *data;
            hasData = true;
        }
        if (object)
        {
            if (auto go = dynamic_cast<GameObject*>(object)) go->DeleteFromDB();
        }
        else
        {
            sObjectMgr.DeleteGOData(prop.guid);
            WorldDatabase.PExecute("DELETE FROM gameobject WHERE guid=%u", prop.guid);
        }
        WorldDatabase.PExecute("DELETE FROM camps_prop WHERE guid=%u", prop.guid);
        if(!Commit())
        {
            if(hasData)
            {
                sObjectMgr.NewGOData(prop.guid) = originalData;
                sObjectMgr.AddGameobjectToGrid(prop.guid, sObjectMgr.GetGOData(prop.guid));
            }
            return false;
        }
        if (object)
        {
            if (auto go = dynamic_cast<GameObject*>(object)) { go->SetRespawnTime(0); go->Delete(); }
        }
    }
    props.erase(prop.guid);
    return true;
}
bool Manager::Restore(Prop const& prop)
{
    auto map=sMapMgr.FindMap(prop.map,sMapMgr.GetContinentInstanceId(prop.map,prop.pos.x,prop.pos.y)); if(!map || props.count(prop.guid)) return false;
    if (prop.kind == 1)
    {
        if (sObjectMgr.GetCreatureData(prop.guid)) return false;
        auto cr=std::unique_ptr<Creature>(new Creature); auto pos=prop.pos;
        auto cinfo=sObjectMgr.GetCreatureTemplate(prop.entry);
        CreatureCreatePos cpos(map, pos.x, pos.y, pos.z, pos.o);
        if(!cinfo || Resolve(prop) || !cr->Create(prop.guid,cpos,cinfo,prop.entry)) return false;
        if(!StartTransaction()) return false;
        cr->SaveToDB(prop.map);
        sObjectMgr.NewOrExistCreatureData(prop.guid).instanciatedContinentInstanceId=map->GetInstanceId();
        WorldDatabase.PExecute("INSERT INTO camps_prop (guid,account,camp,entry) VALUES (%u,%u,%u,%u)",prop.guid,prop.owner,prop.camp,prop.entry);
        if(!Commit()) { sObjectMgr.DeleteCreatureData(prop.guid); return false; }
        if(!cr->LoadFromDB(prop.guid,map)) { failed=true; enabled=false; return false; }
        map->Add(cr.release()); sObjectMgr.AddCreatureToGrid(prop.guid,sObjectMgr.GetCreatureData(prop.guid)); props.emplace(prop.guid,prop); return true;
    }
    else
    {
        if (sObjectMgr.GetGOData(prop.guid)) return false;
        auto obj=std::unique_ptr<GameObject>(new GameObject); auto pos=prop.pos;
        if(Resolve(prop) || !obj->Create(prop.guid,prop.entry,map,pos.x,pos.y,pos.z,pos.o,0,0,0,0,GO_ANIMPROGRESS_DEFAULT,GO_STATE_READY)) return false;
        if(!StartTransaction()) return false;
        obj->SetRespawnTime(300); obj->SaveToDB(prop.map);
        sObjectMgr.NewGOData(prop.guid).instanciatedContinentInstanceId=map->GetInstanceId();
        WorldDatabase.PExecute("INSERT INTO camps_prop (guid,account,camp,entry) VALUES (%u,%u,%u,%u)",prop.guid,prop.owner,prop.camp,prop.entry);
        if(!Commit()) { sObjectMgr.DeleteGOData(prop.guid); return false; }
        if(!obj->LoadFromDB(prop.guid,map)) { failed=true; enabled=false; return false; }
        map->Add(obj.release()); sObjectMgr.AddGameobjectToGrid(prop.guid,sObjectMgr.GetGOData(prop.guid)); props.emplace(prop.guid,prop); return true;
    }
}
}

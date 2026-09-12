#include "CampsManager.h"
#include "Chat.h"
#include "Player.h"
#include "WorldSession.h"
#include "GameObject.h"
#include "Creature.h"
#include "Map.h"
#include "MapManager.h"
#include "ObjectMgr.h"
#include "Database/DatabaseEnv.h"
#include <chrono>
#include <algorithm>
#include <cmath>

namespace Camps
{
namespace
{
uint64_t Now() { return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
std::string S(uint32_t n) { return std::to_string(n); }
std::string F(float n) { return std::to_string(n); }
std::string Lower(std::string s) { for(char& c:s) if(c>='A' && c<='Z') c+=32; return s; }
float Dist(Transform const& a,Transform const& b) { return std::sqrt((a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y)+(a.z-b.z)*(a.z-b.z)); }
}
void Manager::Handle(ChatHandler* h, std::string const& input)
{
    auto p=h->GetPlayer(); if(!p || !h->GetSession()) return;
    Request r;
    auto send=[&](std::string const& op,std::vector<std::string> const& fields)
    {
        std::string line=Reply(r.id,op,fields);
        if(line.size()<=240) h->SendSysMessage(line.c_str());
        else h->SendSysMessage(Reply(r.id,"ERROR",{"RESPONSE_SIZE"}).c_str());
    };
    auto error=[&](std::string const& code) { send("ERROR",{code}); };
    uint32_t player=p->GetGUIDLow(), account=h->GetSession()->GetAccountId();
    if(!clients.count(player) && clients.size()>=4096) { error("BUSY"); return; }
    auto& c=clients[player]; auto now=Now();
    if(now-c.lastAction<200) return;
    c.lastAction=now;
    if(!Parse(input,r)) { error("PROTOCOL"); return; }
    if(r.op!="HELLO" && (!c.hello || r.id<=c.lastRequest)) { error("HANDSHAKE_OR_REPLAY"); return; }
    c.lastRequest=r.id;
    auto exact=[&](size_t n) { if(r.args.size()==n) return true; error("ARGUMENTS"); return false; };
    if(r.op=="HELLO")
    {
        if(!exact(0)) return;
        Cancel(c); c.undo.clear(); c.hello=true; c.gmMode=GM(p);
        send("HELLO",{enabled && !failed ? "1":"0",GM(p)?"1":"0",players?"1":"0","buttons,undo,camps,ondemand",S(PageSize)}); return;
    }
    if(r.op=="RELOAD")
    {
        if(!exact(0)) return;
        if(h->GetSession()->GetSecurity()<SEC_ADMINISTRATOR) { error("PERMISSION"); return; }
        Load(); send("RELOAD",{enabled?"1":"0"}); return;
    }
    if(r.op=="STATUS")
    {
        if(!exact(0)) return;
        float curRadius = radius;
        if(camps.count(account) && camps[account].radius > 5.0f) curRadius = camps[account].radius;
        send("STATUS",{enabled && !failed?"1":"0",c.gmMode?"GM":"CAMP",S(Count(account)),S(cap),F(curRadius),S(unsigned(sObjectMgr.GetGameObjectInfoMap().size())),camps.count(account)?"1":"0",camps.count(account)?(camps[account].publicVisit?"1":"0"):"0"}); return;
    }
    if(r.op=="MODE")
    {
        if(!exact(1)) return;
        if((r.args[0]!="GM" && r.args[0]!="CAMP") || (r.args[0]=="GM" && !GM(p))) { error("PERMISSION"); return; }
        Cancel(c); c.undo.clear(); c.gmMode=r.args[0]=="GM"; send("MODE",{r.args[0]}); return;
    }
    if(!Allowed(p,c)) { error("DISABLED_OR_PERMISSION"); return; }
    auto token=[&]() { uint32_t t=0; return !r.args.empty() && UInt(r.args[0],t) && t && t==c.edit.token && now-c.edit.touched<=timeout*1000 && c.edit.map==p->GetMapId() && c.edit.instance==p->GetInstanceId(); };
    auto editReply=[&]() { auto const& e=c.edit; send("EDIT",{S(e.token),S(e.entry),F(e.working.x),F(e.working.y),F(e.working.z),F(e.working.o),S(unsigned(e.kind))}); };
    auto busy=[&](uint32_t guid) { for(auto const& pair:clients) if(pair.second.edit.source==guid) return true; return false; };
    auto owned=[&](Prop const& prop) { return prop.map==p->GetMapId() && (c.gmMode || prop.owner==account); };
    if(r.op=="SEARCH")
    {
        if(!exact(3)) return;
        uint32_t page;
        if(!UInt(r.args[2],page) || page>50000 || r.args[0].size()>48 || r.args[1].size()>32) { error("QUERY"); return; }
        if(now-c.lastSearch<750) { error("SEARCH_RATE"); return; } c.lastSearch=now;
        std::string query=Lower(r.args[0]),category=Lower(r.args[1]); uint32_t entry=0; bool numeric=UInt(query,entry);
        unsigned count=0, returned=0;
        send("BEGIN",{"CATALOG",S(page)});
        auto process = [&](CatalogEntry const& t)
        {
            bool catMatch = category.empty() ||
                ((category=="creature" || category=="creatures" || category=="npc" || category=="npcs") && t.kind==1) ||
                ((category=="item" || category=="items") && t.kind==2) ||
                ((category=="prop" || category=="props") && t.kind==0) ||
                Lower(t.category)==category || Lower(t.category).find(category)!=std::string::npos;
            if((!c.gmMode && !t.player) || !catMatch ||
                (numeric ? t.entry!=entry : Lower(t.name).find(query)==std::string::npos)) return;
            if(count++<page*PageSize) return;
            if(returned++>=PageSize) return;
            std::vector<std::string> fields{S(t.entry),t.name,S(t.type),S(t.display),F(t.size),t.category,t.player?"SAFE":"GM",S(unsigned(t.kind))};
            while(Reply(r.id,"ITEM",fields).size()>240 && !fields[1].empty()) fields[1].pop_back();
            send("ITEM",fields);
        };
        bool isCreatureCategory = (category=="npc" || category=="npcs" || category=="creature" || category=="creatures" ||
            category=="beast" || category=="dragonkin" || category=="demon" || category=="elemental" ||
            category=="giant" || category=="undead" || category=="humanoid" || category=="critter" ||
            category=="mechanical" || category=="totem");
        bool isItemCategory = (category=="item" || category=="items" ||
            category=="weapon" || category=="weapons" ||
            category=="armor" || category=="armors" ||
            category=="consumable" || category=="consumables" ||
            category=="container" || category=="containers" ||
            category=="trade goods" || category=="tradegoods" ||
            category=="book" || category=="books");
        if(isCreatureCategory)
        {
            for(auto const& pair:sObjectMgr.GetCreatureInfoMap())
            {
                if(!SafeCreature(pair.first)) continue;
                process(GetTemplate(pair.first, 1));
            }
        }
        else if(isItemCategory)
        {
            for(auto const& pair:sObjectMgr.GetItemPrototypeMap())
            {
                if(!SafeItem(pair.first)) continue;
                process(GetTemplate(pair.first, 2));
            }
        }
        else
        {
            for(auto const& pair:sObjectMgr.GetGameObjectInfoMap())
            {
                if(!SafeGameObject(pair.first)) continue;
                process(GetTemplate(pair.first, 0));
            }
        }
        send("END",{"CATALOG",S(count),S(page)}); return;
    }
    if(r.op=="OBJECTS" || r.op=="CAMPS")
    {
        uint32_t page = 0, campFilter = 0;
        if(r.args.empty() || !UInt(r.args[0],page) || page>1250) { error("PAGE"); return; }
        if(r.args.size()>=2 && !UInt(r.args[1],campFilter)) { error("ARGUMENTS"); return; }
        unsigned n=0; send("BEGIN",{r.op,S(page)});
        if(r.op=="OBJECTS") for(auto const& pair:props)
        {
            auto const& prop=pair.second;
            if(!c.gmMode && prop.owner != account) continue;
            if(campFilter == 1 && prop.camp != account) continue;
            else if(campFilter == 2 && prop.camp != 0) continue;
            else if(campFilter > 2 && prop.camp != campFilter) continue;
            if(n++<page*PageSize || n>page*PageSize+PageSize) continue;
            send("OBJECT",{S(prop.guid),S(prop.entry),F(prop.pos.x),F(prop.pos.y),F(prop.pos.z),S(unsigned(prop.kind)),S(prop.camp)});
        }
        if(r.op=="CAMPS") for(auto const& pair:camps)
        {
            auto const& camp=pair.second;
            if(camp.owner!=account && !c.gmMode && (!visits || !camp.publicVisit)) continue;
            if(n++<page*PageSize || n>page*PageSize+PageSize) continue;
            send("CAMP",{S(camp.owner),S(camp.map),F(camp.pos.x),F(camp.pos.y),S(Count(camp.owner)),camp.publicVisit?"PUBLIC":"PRIVATE",F(camp.radius)});
        }
        send("END",{r.op,S(n),S(page)}); return;
    }
    if(r.op=="PREVIEW" || r.op=="EDIT" || r.op=="DUPLICATE" || r.op=="NEAREST")
    {
        if(r.op=="PREVIEW" ? (r.args.size()!=1 && r.args.size()!=2) : (r.args.size()!=1)) { error("ARGUMENTS"); return; }
        uint32_t id=0; if(!UInt(r.args[0],id)) { error("ID"); return; }
        uint32_t kindVal = 0;
        if(r.op=="PREVIEW" && r.args.size()==2) { UInt(r.args[1], kindVal); }
        Prop const* source=nullptr;
        if(r.op=="NEAREST")
        {
            if(id>1) { error("CONE"); return; }
            float best=60;
            for(auto const& pair:props)
            {
                auto const& prop=pair.second; if(!owned(prop) || busy(prop.guid)) continue;
                float dx=prop.pos.x-p->GetPositionX(),dy=prop.pos.y-p->GetPositionY();
                float distance=std::sqrt(dx*dx+dy*dy);
                if(id && distance>0.1f && (dx*std::cos(p->GetOrientation())+dy*std::sin(p->GetOrientation()))/distance<0.7071f) continue;
                if(distance<best) { best=distance; source=&prop; kindVal=source->kind; }
            }
        }
        else if(r.op!="PREVIEW") { auto it=props.find(id); if(it!=props.end()) { source=&it->second; kindVal=source->kind; } }
        else if(r.args.size()==1)
        {
            if(sObjectMgr.GetGameObjectInfo(id)) kindVal = 0;
            else if(sObjectMgr.GetCreatureTemplate(id)) kindVal = 1;
            else if(sObjectMgr.GetItemPrototype(id)) kindVal = 2;
        }
        if(r.op!="PREVIEW" && !source) { error("NOT_FOUND"); return; }
        if(!Begin(p,c,source?source->entry:id,source,r.op=="DUPLICATE", uint8_t(kindVal))) { error("PREVIEW_REJECTED"); return; }
        editReply(); return;
    }
    if(r.op=="DELTA" || r.op=="SNAP" || r.op=="SAVE" || r.op=="CANCEL")
    {
        if(!exact(r.op=="DELTA"?5:1)) return;
        if(!token()) { error("STALE_EDIT"); return; }
        if(r.op=="CANCEL") { Cancel(c); send("CANCEL",{}); return; }
        if(r.op=="SAVE") { Prop result; if(!Save(p,c,result)) error("SAVE_REJECTED"); else send("SAVED",{S(result.guid),S(result.entry),S(unsigned(result.kind))}); return; }
        auto pos=c.edit.working;
        if(r.op=="DELTA")
        {
            float x,y,z,o;
            if(!Number(r.args[1],x,5) || !Number(r.args[2],y,5) || !Number(r.args[3],z,5) || !Number(r.args[4],o,0.7854f)) { error("DELTA_RANGE"); return; }
            float facing=p->GetOrientation(); pos.x+=x*std::cos(facing)-y*std::sin(facing);
            pos.y+=x*std::sin(facing)+y*std::cos(facing); pos.z+=z;
            pos.o=std::fmod(pos.o+o+6.2831853f,6.2831853f);
        }
        else
        {
            pos.z=p->GetMap()->GetHeight(pos.x,pos.y,pos.z+2,true,50);
            if(!std::isfinite(pos.z) || pos.z < -100000) { error("NO_GROUND"); return; }
        }
        auto object=Resolve(c.edit);
        if(!object || object->IsDeleted() || !Location(p,c,pos)) { error("LOCATION"); return; }
        Relocate(object,pos); c.edit.working=pos; c.edit.touched=now; editReply(); return;
    }
    if(r.op=="DELETE")
    {
        if(!exact(1)) return;
        uint32_t id; if(!UInt(r.args[0],id)) { error("ID"); return; }
        if(!props.count(id))
        {
            auto res = WorldDatabase.PQuery("SELECT account, camp, entry FROM camps_prop WHERE guid=%u", id);
            if(res)
            {
                auto f = res->Fetch();
                uint32_t ownerAcc = f[0].GetUInt32();
                if(!c.gmMode && ownerAcc != account) { error("OWNERSHIP"); return; }
                uint32_t campId = f[1].GetUInt32();
                uint32_t entry = f[2].GetUInt32();
                uint8_t kind = 0;
                uint32_t mapId = p->GetMapId();
                Transform tpos{0,0,0,0};
                if(sObjectMgr.GetCreatureData(id)) { kind = 1; auto cd = sObjectMgr.GetCreatureData(id); mapId = cd->position.mapId; tpos = {cd->position.x, cd->position.y, cd->position.z, cd->position.o}; }
                else if(sObjectMgr.GetGOData(id)) { kind = 0; auto gd = sObjectMgr.GetGOData(id); mapId = gd->position.mapId; tpos = {gd->position.x, gd->position.y, gd->position.z, gd->position.o}; }
                Prop fallbackProp{id, ownerAcc, campId, entry, mapId, tpos, kind};
                if(!Erase(fallbackProp)) { error("DELETE_FAILED"); return; }
                send("DELETED",{S(id)}); return;
            }
            else if(c.gmMode)
            {
                uint8_t kind = 0;
                uint32_t entry = 0;
                uint32_t mapId = p->GetMapId();
                Transform tpos{0,0,0,0};
                if(sObjectMgr.GetCreatureData(id)) { kind = 1; auto cd = sObjectMgr.GetCreatureData(id); entry = cd->creature_id[0]; mapId = cd->position.mapId; tpos = {cd->position.x, cd->position.y, cd->position.z, cd->position.o}; }
                else if(sObjectMgr.GetGOData(id)) { kind = 0; auto gd = sObjectMgr.GetGOData(id); entry = gd->id; mapId = gd->position.mapId; tpos = {gd->position.x, gd->position.y, gd->position.z, gd->position.o}; }
                Prop fallbackProp{id, account, 0, entry, mapId, tpos, kind};
                if(!Erase(fallbackProp)) { error("DELETE_FAILED"); return; }
                send("DELETED",{S(id)}); return;
            }
            error("ID"); return;
        }
        auto const& prop = props.at(id);
        if(!c.gmMode && prop.owner != account) { error("OWNERSHIP"); return; }
        for(auto const& pair:clients) if(pair.first!=player && pair.second.edit.source==id) { error("BUSY"); return; }
        if(c.edit.token && c.edit.source==id) Cancel(c);
        Prop copy = prop;
        if(!Erase(copy)) { error("DELETE_FAILED"); return; }
        Push(c,Undo::Remove,copy); send("DELETED",{S(id)}); return;
    }
    if(r.op=="UNDO")
    {
        if(!exact(0)) return;
        if(c.edit.token || c.undo.empty()) { error("UNDO_EMPTY_OR_BUSY"); return; }
        Undo u=c.undo.back(); auto old=u.before;
        if(!owned(old) || busy(old.guid) || !Safe(old.entry, old.kind)) { error("UNDO_PERMISSION"); return; }
        bool ok=false;
        if(u.kind==Undo::Create && props.count(old.guid) && owned(props.at(old.guid))) ok=Erase(props.at(old.guid));
        else if(u.kind==Undo::Remove && props.size()<10000 && (c.gmMode || Count(account)<cap)) ok=Restore(old);
        else if(u.kind==Undo::Move && props.count(old.guid) && Current(props.at(old.guid)) && owned(props.at(old.guid)))
        {
            auto object=Resolve(old);
            if(object && !WorldDatabase.InTransaction() && WorldDatabase.BeginTransaction())
            {
                if(old.kind == 1)
                {
                    CreatureData originalData=*sObjectMgr.GetCreatureData(old.guid);
                    sObjectMgr.RemoveCreatureFromGrid(old.guid,sObjectMgr.GetCreatureData(old.guid));
                    Relocate(object,old.pos);
                    if(auto cr = dynamic_cast<Creature*>(object)) cr->SaveToDB(old.map);
                    ok=Commit();
                    if(ok) { props[old.guid]=old; sObjectMgr.AddCreatureToGrid(old.guid,sObjectMgr.GetCreatureData(old.guid)); }
                    else
                    {
                        Relocate(object,props.at(old.guid).pos); sObjectMgr.NewOrExistCreatureData(old.guid)=originalData;
                        sObjectMgr.AddCreatureToGrid(old.guid,sObjectMgr.GetCreatureData(old.guid));
                    }
                }
                else
                {
                    GameObjectData originalData=*sObjectMgr.GetGOData(old.guid);
                    Transform prior=props.at(old.guid).pos;
                    sObjectMgr.RemoveGameobjectFromGrid(old.guid,sObjectMgr.GetGOData(old.guid));
                    Relocate(object,old.pos);
                    if(auto go = dynamic_cast<GameObject*>(object)) go->SaveToDB();
                    ok=Commit();
                    if(ok) { props[old.guid]=old; sObjectMgr.AddGameobjectToGrid(old.guid,sObjectMgr.GetGOData(old.guid)); }
                    else
                    {
                        Relocate(object,prior); sObjectMgr.NewGOData(old.guid)=originalData;
                        sObjectMgr.AddGameobjectToGrid(old.guid,sObjectMgr.GetGOData(old.guid));
                    }
                }
            }
        }
        if(ok) { c.undo.pop_back(); send("UNDONE",{}); } else error("UNDO_FAILED"); return;
    }
    if(r.op=="CLAIM")
    {
        if(r.args.size() > 2) { error("ARGUMENTS"); return; }
        uint32_t pub = 0;
        float chosenRadius = radius;
        if(r.args.size() >= 1 && (!UInt(r.args[0], pub) || pub > 1)) { error("ARGUMENTS"); return; }
        if(r.args.size() >= 2 && (!Number(r.args[1], chosenRadius, 100.0f) || chosenRadius < 10.0f || chosenRadius > 100.0f)) { error("ARGUMENTS"); return; }

        Transform pos{p->GetPositionX(),p->GetPositionY(),p->GetPositionZ(),p->GetOrientation()};
        if(c.edit.token || camps.size()>=2000 || !Location(p,c,pos,true)) { error("CLAIM_REJECTED"); return; }
        float height=p->GetMap()->GetHeight(pos.x,pos.y,pos.z+2,true,20);
        if(std::isfinite(height) && std::fabs(height-pos.z)<=5) pos.z=height;
        for(auto const& pair:camps)
        {
            if(pair.first == account) continue;
            Transform flat=pair.second.pos; flat.z=pos.z;
            if(pair.second.map==p->GetMapId() && Dist(flat,pos)<spacing) { error("SPACING"); return; }
        }
        if(camps.count(account))
        {
            if(!WorldDatabase.DirectPExecute("UPDATE camps_camp SET map=%u,x=%f,y=%f,z=%f,o=%f,public_visit=%u,radius=%f WHERE account=%u",
                p->GetMapId(),pos.x,pos.y,pos.z,pos.o,pub,chosenRadius,account)) { error("DATABASE"); return; }
            camps[account] = Camp{account,p->GetMapId(),pos,pub==1,chosenRadius};
        }
        else
        {
            if(!WorldDatabase.DirectPExecute("INSERT INTO camps_camp (account,map,x,y,z,o,public_visit,radius) VALUES (%u,%u,%f,%f,%f,%f,%u,%f)",
                account,p->GetMapId(),pos.x,pos.y,pos.z,pos.o,pub,chosenRadius)) { error("DATABASE"); return; }
            camps.emplace(account,Camp{account,p->GetMapId(),pos,pub==1,chosenRadius});
        }
        send("CLAIMED",{S(account),pub?"1":"0",F(chosenRadius)}); return;
    }
    if(r.op=="RADIUS")
    {
        if(!exact(1)) return;
        float newRadius = 0;
        if(!Number(r.args[0], newRadius, 100.0f) || newRadius < 10.0f || newRadius > 100.0f) { error("ARGUMENTS"); return; }
        if(!camps.count(account)) { error("NO_CAMP"); return; }
        camps[account].radius = newRadius;
        if(!WorldDatabase.DirectPExecute("UPDATE camps_camp SET radius=%f WHERE account=%u", newRadius, account)) { error("DATABASE"); return; }
        send("RADIUS",{F(newRadius)}); return;
    }
    if(r.op=="PUBLIC")
    {
        if(!exact(1)) return;
        uint32_t pub=0;
        if(!UInt(r.args[0],pub) || pub>1) { error("ARGUMENTS"); return; }
        if(!camps.count(account)) { error("NO_CAMP"); return; }
        camps[account].publicVisit = (pub==1);
        if(!WorldDatabase.DirectPExecute("UPDATE camps_camp SET public_visit=%u WHERE account=%u",pub,account)) { error("DATABASE"); return; }
        send("PUBLIC",{pub?"1":"0"}); return;
    }
    if(r.op=="GO" || r.op=="VISIT")
    {
        if(!exact(r.op=="GO"?0:1)) return;
        uint32_t owner=account;
        if(r.op=="VISIT" && !UInt(r.args[0],owner)) { error("CAMP"); return; }
        auto it=camps.find(owner);
        if(it==camps.end() || (owner!=account && !c.gmMode && (!visits || !it->second.publicVisit)) || now-c.lastTravel<travelCooldown*1000 ||
            !p->IsAlive() || p->IsInCombat() || p->GetTransport() || p->GetMap()->Instanceable() || c.edit.token) { error("TRAVEL_REJECTED"); return; }
        Camp dest=it->second;
        if((dest.map!=0 && dest.map!=1) || !MapManager::IsValidMapCoord(dest.map,dest.pos.x,dest.pos.y,dest.pos.z,dest.pos.o) || !AreaAllowed(dest.map,dest.pos)) { error("DESTINATION"); return; }
        c.lastTravel=now;
        bool ok=p->TeleportTo(dest.map,dest.pos.x,dest.pos.y,dest.pos.z,dest.pos.o);
        send(ok?"TRAVEL":"ERROR",{ok?"OK":"TELEPORT_FAILED"}); return;
    }
    if(r.op=="BREAK")
    {
        if(!exact(1)) return;
        if(!camps.count(account) || c.edit.token) { error("CAMP_OR_BUSY"); return; }
        if(r.args[0]=="REQUEST") { c.breakUntil=now+15000; send("CONFIRM",{"BREAK","15"}); return; }
        if(r.args[0]!="CONFIRM" || now>c.breakUntil || !c.breakUntil) { error("CONFIRM_EXPIRED"); return; }
        c.breakUntil=0;
        auto const& home=camps.at(account);
        Transform playerPos{p->GetPositionX(),p->GetPositionY(),p->GetPositionZ(),p->GetOrientation()};
        if(p->GetMapId()!=home.map || Dist(playerPos,home.pos)>60 || !p->IsAlive() || p->IsInCombat() || p->GetTransport())
        { error("GO_TO_CAMP"); return; }
        std::vector<Prop> remove;
        for(auto const& pair:props) if(pair.second.camp==account)
        {
            if(pair.second.owner!=account || pair.second.map!=home.map || !Current(pair.second) || busy(pair.first) || !Resolve(pair.second) || Resolve(pair.second)->IsDeleted()) { error("LOAD_CAMP_OR_BUSY"); return; }
            remove.push_back(pair.second);
        }
        if(WorldDatabase.InTransaction() || !WorldDatabase.BeginTransaction()) { error("DATABASE"); return; }
        std::map<uint32_t,GameObjectData> originalGOData;
        std::map<uint32_t,CreatureData> originalCreatureData;
        for(auto const& prop:remove)
        {
            if(prop.kind == 1)
            {
                originalCreatureData.emplace(prop.guid,*sObjectMgr.GetCreatureData(prop.guid));
                if(auto cr = dynamic_cast<Creature*>(Resolve(prop))) cr->DeleteFromDB();
            }
            else
            {
                originalGOData.emplace(prop.guid,*sObjectMgr.GetGOData(prop.guid));
                if(auto go = dynamic_cast<GameObject*>(Resolve(prop))) go->DeleteFromDB();
            }
        }
        WorldDatabase.PExecute("DELETE FROM camps_prop WHERE camp=%u",account);
        WorldDatabase.PExecute("DELETE FROM camps_camp WHERE account=%u",account);
        if(!Commit())
        {
            for(auto const& pair:originalGOData)
            {
                sObjectMgr.NewGOData(pair.first)=pair.second;
                sObjectMgr.AddGameobjectToGrid(pair.first,sObjectMgr.GetGOData(pair.first));
            }
            for(auto const& pair:originalCreatureData)
            {
                sObjectMgr.NewOrExistCreatureData(pair.first)=pair.second;
                sObjectMgr.AddCreatureToGrid(pair.first,sObjectMgr.GetCreatureData(pair.first));
            }
            error("DATABASE"); return;
        }
        for(auto const& prop:remove)
        {
            auto object=Resolve(prop);
            if(auto go = dynamic_cast<GameObject*>(object)) { go->SetRespawnTime(0); go->Delete(); }
            else if(auto cr = dynamic_cast<Creature*>(object)) { cr->AddObjectToRemoveList(); }
            props.erase(prop.guid);
        }
        camps.erase(account);
        for(auto& pair:clients) pair.second.undo.clear();
        send("BROKEN",{}); return;
    }
    error("UNKNOWN_OPERATION");
}
}

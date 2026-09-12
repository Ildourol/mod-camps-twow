#include "../src/CampsProtocol.h"
#include <iostream>
#include <cstdlib>
#include <random>

static unsigned checks=0;
static void Check(bool pass)
{
    ++checks;
    if(!pass) { std::cerr<<"Check failed: "<<checks<<'\n'; std::exit(1); }
}
int main()
{
    Camps::Request r;
    Check(Camps::Parse("1~1~HELLO",r) && r.id==1 && r.op=="HELLO" && r.args.empty());
    Check(Camps::Parse("1~2~SEARCH~table~~0",r) && r.args.size()==3 && r.args[1].empty());
    Check(Camps::Parse("1~3~SEARCH~a%7Eb%25c%7Cd~~0",r) && r.args[0]=="a~b%c|d");
    Check(Camps::Reply(3,"ITEM",{"a~b%c|d"})=="TCAMP/1~3~ITEM~a%7Eb%25c%7Cd");
    for(auto bad : {"", "2~1~HELLO", "1~0~HELLO", "1~-1~HELLO", "1~4294967296~HELLO",
        "1~1~hello", "1~1~HELLO%00", "1~1~SEARCH~%", "1~1~SEARCH~%GG", "1~1~SEARCH~%0A",
        "1~1~SEARCH~%7F", "1~1~SEARCH~%1", "1~1~X~1~2~3~4~5~6~7~8", "1|1|HELLO"}) Check(!Camps::Parse(bad,r));
    Check(!Camps::Parse("1~1~SEARCH~"+std::string(210,'x'),r));
    uint32_t u=0;
    Check(Camps::UInt("4294967295",u) && u==UINT32_MAX);
    for(auto bad : {"", "+1", " 1", "1 ", "1.0", "1e3", "-0", "99999999999"}) Check(!Camps::UInt(bad,u));
    float f=0;
    Check(Camps::Number("-0.5",f,5) && f==-0.5f);
    Check(Camps::Number("5",f,5));
    for(auto bad : {"nan", "inf", "-inf", "1e2", "0x1", " 1", "1 ", "1.2.3", "--1", "5.01", "", "+1"}) Check(!Camps::Number(bad,f,5));
    std::mt19937 rng(12345);
    for(unsigned i=0;i<10000;++i)
    {
        std::string original;
        for(unsigned j=0;j<20;++j) original+=static_cast<char>(32+rng()%95);
        Check(Camps::Parse("1~4~SEARCH~"+Camps::Escape(original),r) && r.args[0]==original);
        std::string arbitrary;
        unsigned n=rng()%240;
        for(unsigned j=0;j<n;++j) arbitrary+=static_cast<char>(rng()%256);
        // Random malformed inputs must neither throw nor crash.
        Camps::Parse(arbitrary,r);
    }
    std::cout<<checks<<" protocol checks passed; 10000 malformed fuzz inputs parsed.\n";
}

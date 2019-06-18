/*
 * This code is partially copied from 
 *  - DCNet-X ADC Server Project ( http://dcnet-x.sourceforge.net )
 *  - ADCH++ ( http://sourceforge.net/projects/adchpp )
 *  - DC++ ( http://sourceforge.net/projects/dcplusplus )
 *  - uHub ( http://www.extatic.org/uhub/ )
 * 
 */

#include "includes.h"
#include "base32.h"
#include "tiger.h"

extern "C" {

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

}

enum {SIZE = 192/8};

/*const char* BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

int create_sid(lua_State* L)
{
    char string[5];

    for (int i = 0; i < 4; i++)
        string[i] = BASE32_ALPHABET[rand()%32];
    string[5] = '\0';
    lua_pushlstring(L, string, 4);
    return 1;
}


int create_salt(lua_State* L)
{
    char string[25];

    for (int i = 0; i < 24; i++)
        string[i] = BASE32_ALPHABET[rand()%32];
    string[24] = '\0';
    lua_pushlstring(L, string, 24);
    return 1;
}*/

int is_valid_utf8(lua_State* L)
{

    size_t length;
    const char* string = luaL_checklstring(L, 1, &length);
    int expect = 0;
    char div = 0;
    int pos = 0;

    if (length == 0)
    {
        lua_pushboolean(L, 1);
        return 1;
    }
    for (pos = 0; pos < length; pos++)
    {
        if (expect)
        {
            if ((string[pos] & 0xC0) == 0x80) expect--;
            else
            {
                lua_pushboolean(L, 0);
                return 1;
            }
        }
        else
        {
            if (string[pos] & 0x80)
            {
                for (div = 0x40; div > 0x10; div /= 2)
                {
                    if (string[pos] & div) expect++;
                    else break;
                }
                if ((string[pos] & div) || (pos+expect >= length))
                {
                    lua_pushboolean(L, 0);
                    return 1;
                }
            }
        }
    }
    lua_pushboolean(L, 1);
    return 1;
}

static int is_valid_utf8_v2(lua_State* L)
{
    size_t length;
    const char* string = luaL_checklstring(L, 1, &length);
    int expect = 0;
    char div = 0;
    size_t pos = 0;

    if (length == 0)
    {
        lua_pushboolean(L, 1);
        return 1;
    }

    for (pos = 0; pos < length; pos++)
    {
        if (expect)
        {
            if ((string[pos] & 0xC0) == 0x80) expect--;
            else
            {
                lua_pushboolean(L, 0);
                return 1;
            }
        }
        else
        {
            if (string[pos] & 0x80)
            {
                for (div = 0x40; div > 0x08; div /= 2)
                {
                    if (string[pos] & div) expect++;
                    else break;
                }
                if ((string[pos] & div) || (pos+expect >= length))
                {
                    lua_pushboolean(L, 0);
                    return 1;
                }
                /*switch (expect) {
                    case 0:
                        lua_pushboolean(L, 1);
                        return 1;
                    case 1:

                        if (string[pos] < 0xC2)
                        {
                            lua_pushboolean(L, 0);
                            return 1;
                        }
                        break;
                    case 2:

                        if ((string[pos] == 0xE0) && (string[pos+1] < 0xA0 ))
                        {
                            lua_pushboolean(L, 0);
                            return 1;
                        }

                        if ((string[pos] == 0xED) && (string[pos+1] > 0x9F ))
                        {
                            lua_pushboolean(L, 0);
                            return 1;
                        }
                        break;
                    case 3:

                        if ((string[pos] == 0xF0) && (string[pos+1] < 0x90 ))
                        {
                            lua_pushboolean(L, 0);
                            return 1;
                        }
                        if (string[pos] > 0xF4)
                        {
                            lua_pushboolean(L, 0);
                            return 1;
                        }
                        if ((string[pos] == 0xF4) && (string[pos+1] > 0x8F ))
                        {
                            lua_pushboolean(L, 0);
                            return 1;
                        }
                        break;
                }*/
            }
        }
    }
    lua_pushboolean(L, 1);
    return 1;
}

int hash_pid(lua_State* L)
{
    std::string pid = (std::string) luaL_checkstring(L, 1);
    unsigned char cid[SIZE];

    memset(cid, 0, sizeof(cid));
    ADCLIB::BASE32::FROMBASE32(pid.c_str(), cid, sizeof(cid));
    ADCLIB::TigerHash Tiger;
    Tiger.update(cid, SIZE);
    Tiger.finalize();
    std::string result = ADCLIB::BASE32::TOBASE32(Tiger.getResult(), ADCLIB::TigerHash::HASH_SIZE);
    lua_pushlstring(L, result.c_str(), result.length());
    return 1;
}

int hash_pas(lua_State* L)
{
    std::string password = (std::string) luaL_checkstring(L, 1);
    std::string salt = (std::string) luaL_checkstring(L, 2);
    size_t saltBytes = salt.size()*5/8;
    unsigned char chunk[saltBytes];

    memset(chunk, 0, saltBytes);
    ADCLIB::BASE32::FROMBASE32(salt.c_str(), chunk, saltBytes);
    ADCLIB::TigerHash Tiger;
    Tiger.update(password.data(), password.length());
    Tiger.update(chunk, saltBytes);
    Tiger.finalize();
    std::string result = ADCLIB::BASE32::TOBASE32(Tiger.getResult(), ADCLIB::TigerHash::HASH_SIZE);
    lua_pushlstring(L, result.c_str(), result.length());
    return 1;
}

int hash_pas_oldschool(lua_State* L)
{
    std::string password = (std::string) luaL_checkstring(L, 1);
    std::string salt = (std::string) luaL_checkstring(L, 2);
    std::string cid = (std::string) luaL_checkstring(L, 3);
    size_t saltBytes = salt.size()*5/8;
    unsigned char chunk1[saltBytes];
    unsigned char chunk2[SIZE];
    memset(chunk1, 0, saltBytes);
    memset(chunk2, 0, sizeof(chunk2));
    ADCLIB::BASE32::FROMBASE32(salt.c_str(), chunk1, saltBytes);
    ADCLIB::BASE32::FROMBASE32(cid.c_str(), chunk2, sizeof(chunk2));
    ADCLIB::TigerHash Tiger;
    Tiger.update(chunk2, SIZE);
    Tiger.update(password.data(), password.length());
    Tiger.update(chunk1, saltBytes);
    Tiger.finalize();
    std::string result = ADCLIB::BASE32::TOBASE32(Tiger.getResult(), ADCLIB::TigerHash::HASH_SIZE);
    lua_pushlstring(L, result.c_str(), result.length());
    return 1;
}

int escape(lua_State* L)
{
    using namespace std;

    string in = luaL_optstring(L, 1, "");
    string out = "";

    out.reserve(in.length() * 2);

    string::const_iterator iter = in.begin();
    string::const_iterator end = in.end();

    for (; iter != end; ++iter)
    {
        if (' ' == *iter) {out += "\\s"; continue;}
        if ('\n' == *iter) {out += "\\n"; continue;}
        if ('\\' == *iter) {out += "\\\\"; continue;}

        out += *iter;
    }

    lua_pushlstring(L, out.c_str(), out.length());

    return 1;
}

int unescape(lua_State* L)
{
    using namespace std;

    string in = luaL_optstring(L, 1, "");
    string out = "";

    out.reserve(in.length());

    string::const_iterator iter = in.begin();
    string::const_iterator end = in.end();

    for (; iter != end; ++iter)
    {
        if ('\\' == *iter)
        {
            if (++iter == end) break;

            if ('s' == *iter) {out += ' '; continue;}
            if ('n' == *iter) {out += '\n'; continue;}
            if ('\\' == *iter) {out += '\\'; continue;}
        }

        out += *iter;
    }

    lua_pushlstring(L, out.c_str(), out.length());

    return 1;
}

static const luaL_reg adclib[] = {
    {"hash", hash_pid},
    {"hashpas", hash_pas},
    {"hasholdpas", hash_pas_oldschool},
    {"escape", escape},
    {"unescape", unescape},
    {"isutf8", is_valid_utf8_v2},
    /*{"createsid", create_sid},
    {"createsalt", create_salt},*/
    {NULL, NULL}
};

extern "C" int luaopen_adclib(lua_State* L)
{
    luaL_register(L, "adclib", adclib);
    return 0;
}


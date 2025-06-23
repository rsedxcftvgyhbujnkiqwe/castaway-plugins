//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_SMTCHEADER
#endinput
#endif
#define NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_SMTCHEADER

#include <smmem> // https://github.com/Scags/SM-Memory
#include <sdktools>
#include <dhooks>

#tryinclude <smmem/dynlib> // https://github.com/Scags/SM-Memory

#pragma semicolon true 
#pragma newdecls required

//////////////////////////////////////////////////////////////////////////////
// TOGGLES                                                                  //
//////////////////////////////////////////////////////////////////////////////

// By default, Pointer.Write() will set memory access unless specified. Set this to false to not set memory access by default.
#if !defined SMTC_UPDATEMEMACCESS_WHILEWRITING_BYDEFAULT
#define SMTC_UPDATEMEMACCESS_WHILEWRITING_BYDEFAULT true
#endif

//////////////////////////////////////////////////////////////////////////////
// TYPES                                                                    //
//////////////////////////////////////////////////////////////////////////////

#define NULL view_as<any>(0) // ((void*)0)
#define SIZE_T int

//////////////////////////////////////////////////////////////////////////////
// MATHEMATICAL MACROS                                                      //
//////////////////////////////////////////////////////////////////////////////

#define FLT_DECIMAL_DIG  9                                  // # of decimal digits of rounding precision
#define FLT_DIG          6                                  // # of decimal digits of precision
#define FLT_EPSILON      view_as<float>(0x34000000)         // smallest such that 1.0+FLT_EPSILON != 1.0
#define FLT_HAS_SUBNORM  1                                  // type does support subnormal numbers
#define FLT_GUARD        0
#define FLT_MANT_DIG     24                                 // # of bits in mantissa
#define FLT_MAX          view_as<float>(0x7f7fffff)         // max value
#define FLT_MAX_10_EXP   38                                 // max decimal exponent
#define FLT_MAX_EXP      128                                // max binary exponent
#define FLT_MIN          view_as<float>(0x800000)           // min normalized positive value
#define FLT_MIN_10_EXP   (-37)                              // min decimal exponent
#define FLT_MIN_EXP      (-125)                             // min binary exponent
#define FLT_NORMALIZE    0
#define FLT_RADIX        2                                  // exponent radix
#define FLT_TRUE_MIN     view_as<float>(0x1)                // min positive value

#define INT_MIN	(-INT_MAX - 1)
#define INT_MAX	2147483647
#define INT_WIDTH 32

#define M_E        2.71828182845904523536   // e
#define M_LOG2E    1.44269504088896340736   // log2(e)
#define M_LOG10E   0.434294481903251827651  // log10(e)
#define M_LN2      0.693147180559945309417  // ln(2)
#define M_LN10     2.30258509299404568402   // ln(10)
#define M_PI       3.14159265358979323846   // pi
#define M_PI_2     1.57079632679489661923   // pi/2
#define M_PI_4     0.785398163397448309616  // pi/4
#define M_1_PI     0.318309886183790671538  // 1/pi
#define M_2_PI     0.636619772367581343076  // 2/pi
#define M_2_SQRTPI 1.12837916709551257390   // 2/sqrt(pi)
#define M_SQRT2    1.41421356237309504880   // sqrt(2)
#define M_SQRT1_2  0.707106781186547524401  // 1/sqrt(2)

//////////////////////////////////////////////////////////////////////////////
// FUNCTION MACROS AND STACK (terrorist acts here)                          //
//////////////////////////////////////////////////////////////////////////////

#define SIZEOF(%1) SIZEOF_%1
#define STACK_ALLOC(%1,%2,%3) char SMTC_%1[SIZEOF_%2]; %2 %1 = %2(AddressOfString(SMTC_%1)) // %1 = name, %2 = methodmap, %3 = size to allocate

#define ARRAY Pointer
#define STACK char[]
#define STACK_RETURNREF(%1) return SMTC_%1 // Return a variable allocated with STACK_ALLOC. %1 = variable
#define STACK_RETURNVALUE(%1, %2) char SMTC_%1[%2]; memcpy(AddressOfString(SMTC_%1), %1, %2); return SMTC_%1 // Return a stack-allocated object not used with STACK_ALLOC. %1 = variable, %2 = size to allocate
#define STACK_GETRETURN(%1) AddressOfString(%1) // %1 = variable
#define STACK_SIZEOF(%1) sizeof(SMTC_%1) // %1 = variable

#define SIZEOF_int 4
#define SIZEOF_float 4
#define SIZEOF_any 4
#define SIZEOF_bool 1
#define SIZEOF_char 1

#define SIZEOF_CHAR 1
#define SIZEOF_BYTE 1
#define SIZEOF_WCHAR 2
#define SIZEOF_SHORT 2
#define SIZEOF_USHORT 2
#define SIZEOF_BOOLEAN 1
#define SIZEOF_BOOL 4
#define SIZEOF_SIZE_T 4

#define SIZEOF_Pointer 4

//////////////////////////////////////////////////////////////////////////////
// MISCELLANEOUS MACROS                                                     //
//////////////////////////////////////////////////////////////////////////////

#define SH_MEM_ALL (SH_MEM_EXEC | SH_MEM_READ | SH_MEM_WRITE)
#define VALID_MINIMUM_MEMORY_ADDRESS 0x10000 // smn_core.cpp

//////////////////////////////////////////////////////////////////////////////
// GLOBALS                                                                  //
//////////////////////////////////////////////////////////////////////////////

enum OSType
{
    OSTYPE_WINDOWS,
    OSTYPE_LINUX,
    OSTYPE_MACOS
}

stock OSType OSTypeUsed;

stock Pointer SMTC_CUserCmd_vtable;
stock Pointer SMTC_CTraceFilterSimple_vtable;
stock Pointer SMTC_CFlaggedEntitiesEnum_vtable;
stock Pointer SMTC_tf_point_t_vtable;

stock DynamicDetour SMTC_DHooks_Signature_CTFPlayer_OnTakeDamage_Alive;

stock DynamicHook SMTC_DHooks_CTFPointManager_AddPoint;
stock DynamicHook SMTC_DHooks_Offset_CTFPlayer_OnTakeDamage;
stock DynamicHook SMTC_DHooks_Offset_CTFPlayer_OnTakeDamage_Alive;

stock Handle SMTC_SDKCall_IEngineTrace_ClipRayToEntity;
stock Handle SMTC_SDKCall_IEngineTrace_TraceRay;
stock Handle SMTC_SDKCall_CSpatialPartition_EnumerateElementsInBox;
stock Handle SMTC_SDKCall_CTFPointManager_GetMaxPoints;
stock Handle SMTC_SDKCall_FileWeaponInfo_t_Parse;

stock Handle SMTC_SDKCall_CBaseEntity_TakeDamage;
stock Handle SMTC_SDKCall_CLagCompensationManager_StartLagCompensation;
stock Handle SMTC_SDKCall_CLagCompensationManager_FinishLagCompensation;
stock Handle SMTC_SDKCall_CTFRadiusDamageInfo_CalculateFalloff;
stock Handle SMTC_SDKCall_CTFRadiusDamageInfo_ApplyToEntity;
stock Handle SMTC_SDKCall_CTFGameRules_RadiusDamage;

// compiled with msvc
static char func_strlen[] = "\x55\x8B\xEC\x8B\x4D\x08\x8B\xC1\xF6\xC1\x03\x74\x0D\x0F\x1F\x00\x80\x38\x00\x74\x4D\x40\xA8\x03\x75\xF6\x53\x56\x0F\x1F\x40\x00\x8B\x18\x8B\xF0\x8B\xCB\x83\xC0\x04\xF7\xD1\x8D\x93\xFF\xFE\xFE\xFE\x23\xD1\xF7\xC2\x80\x80\x80\x80\x74\xE5\x84\xDB\x74\x3B\x8B\xCB\xC1\xE9\x08\x84\xC9\x74\x28\x8B\xCB\xC1\xE9\x10\x84\xC9\x74\x15\xC1\xEB\x18\x84\xDB\x75\xC8\x2B\x75\x08\x8D\x46\x03\x5E\x5B\x5D\xC3\x2B\xC1\x5D\xC3\x2B\x75\x08\x8D\x46\x02\x5E\x5B\x5D\xC3\x2B\x75\x08\x8D\x46\x01\x5E\x5B\x5D\xC3\x2B\x75\x08\x8B\xC6\x5E\x5B\x5D\xC3";
static char func_strnlen[] = "\x55\x8B\xEC\x8B\x45\x0C\x8B\x4D\x08\x56\x8D\x34\x01\x85\xC0\x75\x03\x5E\x5D\xC3\x83\xC8\xFF\x3B\xF1\x0F\x42\xF0\x8B\xC1\xF6\xC1\x03\x74\x0A\x80\x38\x00\x74\x60\x40\xA8\x03\x75\xF6\x3B\xC6\x73\x59\x8D\x50\xFE\x53\x66\x66\x66\x0F\x1F\x84\x00\x00\x00\x00\x00\x8B\x5A\x02\x83\xC2\x04\x8D\x83\xFF\xFE\xFE\xFE\xA9\x80\x80\x80\x80\x74\x28\x8D\x42\xFE\x84\xDB\x74\x2A\x8B\xCB\x8D\x42\xFF\xC1\xE9\x08\x84\xC9\x74\x1E\x8B\xCB\x8B\xC2\xC1\xE9\x10\x84\xC9\x74\x13\xC1\xEB\x18\x8D\x42\x01\x84\xDB\x74\x09\x8D\x4A\x02\x8B\xC6\x3B\xCE\x72\xBC\x8B\x4D\x08\x5B\x3B\xC6\x0F\x46\xF0\x2B\xF1\x8B\xC6\x5E\x5D\xC3";
static char func_strcmp[] = "\x55\x8B\xEC\x8B\x4D\x0C\x56\x8B\x75\x08\x8A\x16\x84\xD2\x74\x15\x8A\xC2\x2B\xF1\x8A\xD0\x3A\x01\x75\x0B\x8A\x44\x0E\x01\x41\x8A\xD0\x84\xC0\x75\xEF\x0F\xB6\x09\x0F\xB6\xC2\x2B\xC1\x5E\x5D\xC3";
static char func_strncmp[] = "\x55\x8B\xEC\x8B\x4D\x10\x53\x56\x85\xC9\x74\x1B\x8B\x75\x0C\x8B\x45\x08\x8A\x1E\x8D\x76\x01\x8A\x10\x3A\xD3\x75\x10\x40\x84\xD2\x74\x05\x83\xE9\x01\x75\xEB\x5E\x33\xC0\x5B\x5D\xC3\x0F\xB6\xCB\x0F\xB6\xC2\x5E\x2B\xC1\x5B\x5D\xC3";
static char func_strchr[] = "\x55\x8B\xEC\x8A\x45\x0C\x53\x8B\x5D\x08\x56\xF6\xC3\x03\x74\x14\x8A\x0B\x3A\xC8\x0F\x84\x86\x00\x00\x00\x84\xC9\x74\x7C\x43\xF6\xC3\x03\x75\xEC\x0F\xB6\xC0\x8B\xF0\xC1\xE6\x08\x0B\xF0\x8B\xC6\xC1\xE0\x10\x0B\xF0\x8B\x0B\x8B\xC3\x89\x4D\x08\x83\xC3\x04\x8D\x91\xFF\xFE\xFE\x7E\xF7\xD1\x33\xD1\xF7\xC2\x00\x01\x01\x81\x75\x17\x8B\x55\x08\x33\xD6\x8D\x8A\xFF\xFE\xFE\x7E\xF7\xD2\x33\xCA\xF7\xC1\x00\x01\x01\x81\x74\xCD\x8A\x4D\x0C\x8B\x55\x08\x3A\xD1\x74\x2A\x84\xD2\x74\x24\x8A\x50\x01\x40\x3A\xD1\x74\x1E\x84\xD2\x74\x18\x8A\x50\x01\x40\x3A\xD1\x74\x12\x84\xD2\x74\x0C\x8A\x50\x01\x40\x3A\xD1\x74\x06\x84\xD2\x75\x9B\x33\xC0\x5E\x5B\x5D\xC3\x5E\x8B\xC3\x5B\x5D\xC3";
static char func_strstr[] = "\x55\x8B\xEC\x53\x56\x8B\x75\x08\x57\x8A\x0E\x84\xC9\x74\x33\x8B\x7D\x0C\x8B\xD6\x2B\xD7\x8A\x1F\x3A\xCB\x75\x1D\x8B\xC7\x84\xC9\x74\x12\x8A\x08\x84\xC9\x74\x21\x38\x0C\x02\x75\x0C\x40\x80\x3C\x02\x00\x75\xEE\x80\x38\x00\x74\x10\x8A\x4E\x01\x46\x42\x84\xC9\x75\xD6\x5F\x5E\x33\xC0\x5B\x5D\xC3\x5F\x8B\xC6\x5E\x5B\x5D\xC3";

static char func_findsignatures[] = "\x55\x8B\xEC\x8B\x55\x0C\x56\x8B\x75\x08\x57\x33\xFF\x3B\xF2\x73\x50\x8B\x45\x14\x53\x8B\x5D\x10\x2B\xDE\x66\x0F\x1F\x44\x00\x00\x3B\x7D\x1C\x73\x35\x33\xC9\x85\xC0\x74\x1E\x8B\xC6\x0F\x1F\x00\x8A\x14\x03\x80\xFA\x2A\x74\x04\x3A\x10\x75\x07\x41\x40\x3B\x4D\x14\x72\xED\x8B\x45\x14\x8B\x55\x0C\x3B\xC8\x75\x07\x8B\x4D\x18\x89\x34\xB9\x47\x46\x4B\x3B\xF2\x72\xC6\x5B\x8B\xC7\x5F\x5E\x5D\xC3\x8B\xC7\x5F\x5E\x5D\xC3";

static Handle SMTC_SDKCall_strlen;
static Handle SMTC_SDKCall_strnlen;
static Handle SMTC_SDKCall_strcmp;
static Handle SMTC_SDKCall_strncmp;
static Handle SMTC_SDKCall_strchr;
static Handle SMTC_SDKCall_strstr;

static Handle SMTC_SDKCall_FindSignatures;

char empty_string[] = "";
stock Pointer aEmptyString;

stock any SMTC_CLagCompensationManager_m_thisOffset;
stock any SMTC_CLagCompensationManager_m_isCurrentlyDoingCompensation;

stock any SMTC_CBaseEntity_m_RefEHandle;
stock any SMTC_CBasePlayer_m_pCurrentCommand;
stock any SMTC_CTFWeaponBase_m_iWeaponMode;
stock any SMTC_CTFWeaponBase_m_pWeaponInfo;
stock any SMTC_CTFPointManager_m_Points;

//////////////////////////////////////////////////////////////////////////////
// POINTER METHODMAP                                                        //
//////////////////////////////////////////////////////////////////////////////

// A methodmap mimicking the design of a pointer, I.E. a variable that holds a value representing a location in memory.
methodmap Pointer
{
    // The value this pointer is holding.
    property any Address
    {
        public get() { return view_as<any>(this); }
    }

    // Constructor - wrap around an existing address.
    public Pointer(Address address)
    {
        return view_as<Pointer>(address);
    }

    // Locate the value that this pointer is pointing to and return it, with a given offset.
    public any Dereference(any offset = 0, NumberType bits = NumberType_Int32)
    {
        return LoadFromAddress(this.Address + offset, bits);
    }

    // Write to the address this pointer is holding, with a given offset.
    public void Write(any value, any offset = 0, NumberType bits = NumberType_Int32, bool updateMemAccess = SMTC_UPDATEMEMACCESS_WHILEWRITING_BYDEFAULT)
    {
        StoreToAddress(this.Address + offset, value, bits, updateMemAccess);
    }

    // Get the array offset from the pointer's current address. 
    // You must specify the size of the type used with this pointer using the typeSize parameter.
    public Pointer Get(int index, int typeSize = 4)
    {
        return Pointer(this.Address + view_as<Address>(index * typeSize));
    }

    // Get the array offset from the pointer's current address within a two-dimensional array.
    // You must specify the size of the type used with this pointer using the typeSize parameter.
    // You must specify the size of each sub-array using the arraySize parameter.
    public Pointer Get2D(int a, int b, int typeSize = 4, int arraySize = 1)
    {
        return Pointer(this.Address + view_as<Address>((b * typeSize) + (a * arraySize)));
    }

    // Get the string length.
    public int strlen()
    {
        if (SMTC_SDKCall_strlen == null)
        {
            // If we don't set execution perms, the function will just crash. This will have massive overhead initially, but will be fine later on.
            // To be fair, so do the SDKCall natives...
            SetMemAccess(AddressOfString(func_strlen), sizeof(func_strlen), SH_MEM_READ | SH_MEM_WRITE | SH_MEM_EXEC);
            
            StartPrepSDKCall(SDKCall_Static);
            PrepSDKCall_SetAddress(AddressOfString(func_strlen));
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char*
            PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int
            SMTC_SDKCall_strlen = EndPrepSDKCall();
        }
        int x = this.Dereference();
        if (x & 0xFF == 0) return 0;
        if (x & 0xFF00 == 0) return 1;
        if (x & 0xFF0000 == 0) return 2;
        if (x & 0xFF000000 == 0) return 3;
        return SDKCall(SMTC_SDKCall_strlen, this); // This is WAY faster than doing it in SourceMod, unless the string is really short...
    }

    // Get the string length, scanning up to maxlen characters. 
    // Return maxlen if no NUL is found.
    public int strnlen(int maxlen)
    {
        if (SMTC_SDKCall_strnlen == null)
        {
            SetMemAccess(AddressOfString(func_strnlen), sizeof(func_strnlen), SH_MEM_READ | SH_MEM_WRITE | SH_MEM_EXEC);
            
            StartPrepSDKCall(SDKCall_Static);
            PrepSDKCall_SetAddress(AddressOfString(func_strnlen));
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // const char*
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // int
            PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int
            SMTC_SDKCall_strnlen = EndPrepSDKCall();
        }
        return SDKCall(SMTC_SDKCall_strnlen, this, maxlen);
    }

    // Compares two strings lexographically.
    public int strcmp(any string)
    {
        if (SMTC_SDKCall_strcmp == null)
        {
            SetMemAccess(AddressOfString(func_strcmp), sizeof(func_strcmp), SH_MEM_READ | SH_MEM_WRITE | SH_MEM_EXEC);
            
            StartPrepSDKCall(SDKCall_Static);
            PrepSDKCall_SetAddress(AddressOfString(func_strcmp));
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char*
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char*
            PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int
            SMTC_SDKCall_strcmp = EndPrepSDKCall();
        }
        return SDKCall(SMTC_SDKCall_strcmp, this, string);
    }

    // Compares two strings parts lexographically.
    public int strncmp(any string, int length)
    {
        if (SMTC_SDKCall_strncmp == null)
        {
            SetMemAccess(AddressOfString(func_strncmp), sizeof(func_strncmp), SH_MEM_READ | SH_MEM_WRITE | SH_MEM_EXEC);
            
            StartPrepSDKCall(SDKCall_Static);
            PrepSDKCall_SetAddress(AddressOfString(func_strncmp));
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char*
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char*
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // int
            PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int
            SMTC_SDKCall_strncmp = EndPrepSDKCall();
        }
        return SDKCall(SMTC_SDKCall_strncmp, this, string, length);
    }

    // Copies one string to another string.
    public Pointer strcpy(any source)
    {
        return memcpy(this, source, view_as<Pointer>(source).strlen() + 1);
    }

    // Copies first n characters of source to destination.
    public Pointer strncpy(any source, int n)
    {
        int size = view_as<Pointer>(source).strnlen(n);
        if (size != n)
        {
            memset(this + size, '\0', n - size);
        }
        return memcpy(this, source, size);
    }

    // Append source on the end of destination.
    public Pointer strcat(any source)
    {
        (this + this.strlen()).strcpy(source);
        return this;
    }

    // Append first n characters of source on the end of destination.
    public Pointer strncat(any source, int n)
    {
        Pointer s1 = this + this.strlen();
        int ss = view_as<Pointer>(source).strnlen(n);
        s1.Write('\0', ss, NumberType_Int8);
        memcpy(s1, source, ss);
        return this;
    }

    // Duplicate a string.
    public Pointer strdup()
    {
        int len = this.strlen() + 1;
        Pointer duplicate = malloc(len);
        if (duplicate == NULL)
            return NULL;
        return memcpy(duplicate, this, len);
    }

    // Returns a pointer to the first occurring char in string, otherwise NULL.
    public Pointer strchr(int c)
    {
        if (SMTC_SDKCall_strchr == null)
        {
            SetMemAccess(AddressOfString(func_strchr), sizeof(func_strchr), SH_MEM_READ | SH_MEM_WRITE | SH_MEM_EXEC);
            
            StartPrepSDKCall(SDKCall_Static);
            PrepSDKCall_SetAddress(AddressOfString(func_strchr));
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char*
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // int c
            PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int
            SMTC_SDKCall_strchr = EndPrepSDKCall();
        }
        return SDKCall(SMTC_SDKCall_strchr, this, c);
    }

    // Returns a pointer to the last occurring char in string, otherwise NULL.
    public Pointer strrchr(int c)
    {
        Pointer found, p, s = this;
        if (c == '\0')
            return s.strchr('\0');

        found = NULL;
        while ((p = s.strchr(c)) != NULL)
        {
            found = p;
            s = p + 1;
        }

        return found;
    }

    // Set all characters of a string.
    public void strset(int c)
    {
        memset(this, c, this.strlen());
    }
    
    // Set all characters of a string up to a given length.
    public void strnset(int c, int n)
    {
        int len = this.strlen();
        if (n > len)
            n = len;
        memset(this, c, n);
    }

    // Returns a pointer to the first occurring string in string, otherwise NULL.
    // Not an optimised function.
    public Pointer strstr(any str)
    {
        if (SMTC_SDKCall_strstr == null)
        {
            SetMemAccess(AddressOfString(func_strstr), sizeof(func_strstr), SH_MEM_READ | SH_MEM_WRITE | SH_MEM_EXEC);
            
            StartPrepSDKCall(SDKCall_Static);
            PrepSDKCall_SetAddress(AddressOfString(func_strstr));
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char*
            PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char*
            PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int
            SMTC_SDKCall_strstr = EndPrepSDKCall();
        }
        return SDKCall(SMTC_SDKCall_strstr, this, str);
    }

    // Store pointer into a char buffer. maxlen should include NUL.
    public void ToCharBuffer(char[] buffer, int maxlen = -1)
    {
        int length = this.strlen() + 1;
        if (maxlen == -1)
            maxlen = length;
        else if (length < maxlen)
            maxlen = length;
        memcpy(AddressOfString(buffer), this, maxlen);
    }

    // Store char buffer into a pointer. maxlen should include NUL.
    public void CharBufferToPointer(char[] buffer, int maxlen = -1)
    {
        int length = strlen(buffer) + 1;
        if (maxlen == -1)
            maxlen = length;
        else if (length < maxlen)
            maxlen = length;
        memcpy(this, AddressOfString(buffer), maxlen);
    }

    // Store into a buffer. You must specify the size of the type used with this pointer using the typeSize parameter.
    public void ToBuffer(char[] buffer, int typeSize = 4)
    {
        memcpy(AddressOfString(buffer), this, typeSize);
    }

    // Return the address of a cell.
    public static Pointer Reference(any& cell)
    {
        return AddressOf(cell);
    }

    // Return the address of an array of cells.
    public static Pointer ReferenceArray(any[] cell)
    {
        return AddressOfArray(cell);
    }

    // Return the address of a string.
    public static Pointer ReferenceString(char[] cell)
    {
        return AddressOfString(cell);
    }
}

//////////////////////////////////////////////////////////////////////////////
// POINTERS                                                                 //
//////////////////////////////////////////////////////////////////////////////

// :D
stock Address operator+(Address left, int right)
{
    return left + view_as<Address>(right);
}
stock Address operator+(int left, Address right)
{
    return view_as<Address>(left) + right;
}
stock Address operator-(Address left, int right)
{
    return left - view_as<Address>(right);
}
stock Address operator-(int left, Address right)
{
    return view_as<Address>(left) - right;
}

// Pointer arithmetic.
stock Pointer operator+(const Pointer left, const int right)
{
    return Pointer(left.Address + right);
}
stock Pointer operator-(const Pointer left, const int right)
{
    return Pointer(left.Address - right);
}
stock Pointer operator+(const Pointer left, const Address right)
{
    return Pointer(left.Address + right);
}
stock Pointer operator-(const Pointer left, const Address right)
{
    return Pointer(left.Address - right);
}

// Assignment overloading.
stock Address operator=(int value)
{
    return view_as<Address>(value);
}
stock Address operator=(Pointer value)
{
    return view_as<Address>(value);
}
stock Pointer operator=(int value)
{
    return view_as<Pointer>(value);
}
stock Pointer operator=(Address value)
{
    return view_as<Pointer>(value);
}

//////////////////////////////////////////////////////////////////////////////
// GLOBALS - SDKCALLS                                                       //
//////////////////////////////////////////////////////////////////////////////

// Generate the string function and CKeyLess SDKCalls beforehand.
stock void SMTC_GenerateSDKCallInfo()
{
    SMTC_SDKCall_strlen = null;
    SMTC_SDKCall_strnlen = null;
    SMTC_SDKCall_strcmp = null;
    SMTC_SDKCall_strncmp = null;
    SMTC_SDKCall_strchr = null;
    SMTC_SDKCall_strstr = null;
    SMTC_SDKCall_FindSignatures = null;

    STACK_ALLOC(str1, Pointer, 1);
    STACK_ALLOC(str2, Pointer, 1);
    str1.strlen();
    str1.strnlen(1);
    str1.strcmp(str2);
    str1.strncmp(str2, 1);
    str1.strchr('S');
    str1.strstr(str2);

    aEmptyString = AddressOfString(empty_string);

    SetMemAccess(AddressOfString(func_findsignatures), sizeof(func_findsignatures), SH_MEM_ALL);
    StartPrepSDKCall(SDKCall_Static);
    PrepSDKCall_SetAddress(AddressOfString(func_findsignatures));
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // size_t imageBase;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // size_t end;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // const char* signature;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // size_t siglength;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // size_t* addresses;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);  // size_t maxlength;
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int
    SMTC_SDKCall_FindSignatures = EndPrepSDKCall();

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CUTLRBTREE
    SMTC_CallCKeyLess(NULL, NULL, NULL);
#endif
}

//////////////////////////////////////////////////////////////////////////////
// GLOBALS - FUNCTIONS                                                      //
//////////////////////////////////////////////////////////////////////////////

enum struct SMTCFunction_t
{
    Function func;
}
static any GetFirstIndex(any[] array)
{
    return array[0];
}

// Get the index of a function as a numeric value.
stock any SMTC_GetFunctionValue(Function func)
{
    /*
    kelsey — Today at 18:36
    WHAT ARE YOU DOING
    */
    SMTCFunction_t obj;
    obj.func = func;
    return GetFirstIndex(obj);
}

enum struct SMTCValue_t
{
    any index;
}
static any GetFirstIndexFunction(any[] array)
{
    return array[0];
}

// Convert a numeric value to a function.
stock any SMTC_GetValueAsFunction(any index)
{
    SMTCValue_t obj;
    obj.index = index;
    return GetFirstIndexFunction(obj);
}

// Check whether the value of a function pointer matches as a potential
// SourceMod function, or if it points to a compiled subroutine.
stock bool SMTC_IsSMFunction(any value)
{
    return 0 <= value < VALID_MINIMUM_MEMORY_ADDRESS;
}

//////////////////////////////////////////////////////////////////////////////
// GLOBALS - MISCELLANEOUS                                                  //
//////////////////////////////////////////////////////////////////////////////

// Scans through a block of memory and returns all addresses for a matching signature.
stock int SMTC_FindSignatures(any imageBase, any end, const char[] signature, const int siglength, any[] addresses, const int maxlength)
{
    return SDKCall(SMTC_SDKCall_FindSignatures, imageBase, end, AddressOfString(signature), siglength, AddressOfArray(addresses), maxlength);
}

// Re-allocates a block of memory for an array of num elements. Each byte is initialized as 0.
stock any recalloc(Pointer memory, int num, int size, int old)
{
    Pointer buffer = calloc(num, size);
    memcpy(buffer, memory, old * size);
    free(memory);
    return buffer;
}

// Swap fast between two blocks of memory. You must specify the size of the type used with this global using the typeSize parameter.
stock void V_swap(Pointer x, Pointer y, int typeSize = 4)
{
    Pointer temp = malloc(typeSize);
    memcpy(temp, x, typeSize);
    memcpy(x, y, typeSize);
    memcpy(y, temp, typeSize);
    free(temp);
}

// Return absolute of int.
//stock any abs(any x)
//{
//    return (x + 0xFFFFFFFF) ^ 0xFFFFFFFF; // sm uses cells which are 32-bit so we can just use 0xFFFFFFFF as our bitmask
//}

// Valve fabs() implementation. You should use FloatAbs().
stock float FloatMakePositive(float f)
{
    return view_as<float>(view_as<int>(f) & 0x7FFFFFFF); // evil floating point bit level hacking
}

// Convert bit count to NumberType.
stock NumberType BitToNumberType(any bits)
{
    switch (bits)
    {
    case 1:
        return NumberType_Int8;
    case 2:
        return NumberType_Int16;
    case 4:
        return NumberType_Int32;
    default:
        return view_as<NumberType>(-1);
    }
}

// Destruct an object. This is meant to call the destructor of the object
// used; if possible call your own destructor method.
stock void Destruct(any pMemory, int typeSize = 4)
{
    memset(pMemory, 0xDD, typeSize);
}

// Re-allocate within a specific location in memory. You must specify the size of the type used with this global using the typeSize parameter.
// Normally this would call the the constructor of the allocated memory, but that's not possible here.
stock void Construct(Pointer memory, int typeSize = 4)
{
    memset(memory, 0, typeSize);
}

// Re-allocate within a specific location in memory, from another source. You must specify the size of the type used with this global using the typeSize parameter.
// Normally this would call the the constructor of the allocated memory, but that's not possible here.
stock void CopyConstruct(Pointer memory, Pointer source, int typeSize = 4)
{
    memcpy(memory, source, typeSize);
}

stock any max(any a, any b)
{
    return a > b ? a : b;
}

stock any min(any a, any b)
{
    return a > b ? b : a;
}

stock float fmax(float a, float b)
{
    return a > b ? a : b;
}

//stock float fmin(float a, float b)
//{
//    return a > b ? b : a;
//}

//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_SMTC
#endinput
#endif
#define NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_SMTC

#pragma semicolon true 
#pragma newdecls required

//////////////////////////////////////////////////////////////////////////////
// GLOBALS                                                                  //
//////////////////////////////////////////////////////////////////////////////

typeset SMTC_ForwardCallback
{
    // FORWARDTYPE_ADDPOINT (TF2 only): 
    // When a new tf_point_t object is instantiated  within a CTFPointManager (or derived) object,
    // this will be invoked through CTFPointManager::AddPoint().
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_TF_POINT_T && defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CBASEENTITY
    function void (const CBaseEntity manager, const TF_Point_t point);
#endif

    // FORWARDTYPE_ONTAKEDAMAGE,
    // FORWARDTYPE_ONTAKEDAMAGE_POSTCALL,
    // FORWARDTYPE_ONTAKEDAMAGE_ALIVE,
    // FORWARDTYPE_ONTAKEDAMAGE_ALIVE_POSTCALL:
    // These are all events after an entity is taking damage through CBaseEntity::TakeDamage().
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CTAKEDAMAGEINFO && defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CBASEENTITY
    function MRESReturn (const CBaseEntity entity, const CTakeDamageInfo info, bool& returnValue);
#endif
};

enum SMTC_ForwardType
{
    FORWARDTYPE_ADDPOINT,
    FORWARDTYPE_ONTAKEDAMAGE,
    FORWARDTYPE_ONTAKEDAMAGE_POSTCALL,
    FORWARDTYPE_ONTAKEDAMAGE_ALIVE,
    FORWARDTYPE_ONTAKEDAMAGE_ALIVE_POSTCALL
}

enum struct SMTC_HookData
{
    SMTC_ForwardType type;
    SMTC_ForwardCallback callback;
    int entity;
}

static ArrayList g_Hooks;
bool g_SMTCInitialized = false;

// taken from server_srv.so for CDefOps<int>::LessFunc
stock static char s_aDefaultLessFunc[] = "\x55\x89\xE5\x8B\x45\x0C\x8B\x55\x08\x5D\x8B\x00\x39\x02\x0F\x9C\xC0\xC3";

//////////////////////////////////////////////////////////////////////////////
// SMTC FORWARDS                                                            //
//////////////////////////////////////////////////////////////////////////////

static void SMTC_HookGC()
{
    for (int i = 0, size = g_Hooks.Length; i < size; ++i)
    {
        SMTC_HookData data;
        g_Hooks.GetArray(i, data);
        if (!IsValidEntity(data.entity))
        {
            g_Hooks.Erase(i--);
            --size;
        }
    }
}

// Hook onto entities and invoke forwards whenever a specific event occurs.
// Intended to work in similar fashion to SDKHooks, uses DHooks behind the scenes.
// The garbage collector is called within this function.
stock void SMTC_HookEntity(int entity, SMTC_ForwardType type, SMTC_ForwardCallback callback)
{
    SMTC_HookGC();

    switch (type)
    {
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_TF_POINT_T
    case FORWARDTYPE_ADDPOINT:
        SMTC_DHooks_CTFPointManager_AddPoint.HookEntity(Hook_Post, entity, SMTC_CTFPointManager_AddPoint);
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CTAKEDAMAGEINFO
    case FORWARDTYPE_ONTAKEDAMAGE:
        SMTC_DHooks_Offset_CTFPlayer_OnTakeDamage.HookEntity(Hook_Pre, entity, SMTC_Offset_CTFPlayer_OnTakeDamage);
    case FORWARDTYPE_ONTAKEDAMAGE_POSTCALL:
        SMTC_DHooks_Offset_CTFPlayer_OnTakeDamage.HookEntity(Hook_Post, entity, SMTC_Offset_CTFPlayer_OnTakeDamage_Post);
    case FORWARDTYPE_ONTAKEDAMAGE_ALIVE:
        SMTC_DHooks_Offset_CTFPlayer_OnTakeDamage_Alive.HookEntity(Hook_Pre, entity, SMTC_Offset_CTFPlayer_OnTakeDamage_Alive);
    case FORWARDTYPE_ONTAKEDAMAGE_ALIVE_POSTCALL:
        SMTC_DHooks_Offset_CTFPlayer_OnTakeDamage_Alive.HookEntity(Hook_Post, entity, SMTC_Offset_CTFPlayer_OnTakeDamage_Alive_Post);
#endif
    default:
        ThrowError("Incorrect SMTC_ForwardType specified! %u", type);
    }

    SMTC_HookData data;
    data.type = type;
    data.callback = callback;
    data.entity = EntIndexToEntRef(entity);
    g_Hooks.PushArray(data);
}

// Get hook data for the specified entity.
stock void SMTC_GetHookData(int entity, SMTC_ForwardType type, SMTC_HookData data)
{
    int ref = EntIndexToEntRef(entity);
    for (int i = 0, size = g_Hooks.Length; i < size; ++i)
    {
        SMTC_HookData temp;
        g_Hooks.GetArray(i, temp);
        if (temp.entity == ref && temp.type == type)
            data = temp;
    }
}

//////////////////////////////////////////////////////////////////////////////
// INITIALIZER                                                              //
//////////////////////////////////////////////////////////////////////////////

// Call this in OnPluginStart() to initialize some SMTC features, such as mini-crit effect handling with CTakeDamageInfo.
stock void SMTC_Initialize()
{
    if (g_SMTCInitialized)
        return;

    // Set up hooks from the config file.
    GameData config = LoadGameConfigFile("NotnHeavy - SourceMod Type Collection");
    char keyvalue[128];
    
    OSTypeUsed = view_as<OSType>(config.GetOffset("OSTypeUsed"));

    SMTC_DHooks_Signature_CTFPlayer_OnTakeDamage_Alive = DynamicDetour.FromConf(config, "Signature::CTFPlayer::OnTakeDamage_Alive()");
    
    SMTC_DHooks_CTFPointManager_AddPoint = DynamicHook.FromConf(config, "CTFPointManager::AddPoint()");
    SMTC_DHooks_Offset_CTFPlayer_OnTakeDamage = DynamicHook.FromConf(config, "Offset::CTFPlayer::OnTakeDamage()");
    SMTC_DHooks_Offset_CTFPlayer_OnTakeDamage_Alive = DynamicHook.FromConf(config, "Offset::CTFPlayer::OnTakeDamage_Alive()");

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "IEngineTrace::ClipRayToEntity()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const Ray_t&
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // unsigned int
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // IHandleEntity*
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // trace_t*
    SMTC_SDKCall_IEngineTrace_ClipRayToEntity = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "IEngineTrace::TraceRay()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const Ray_t&
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // unsigned int
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // ITraceFilter*
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // trace_t*
    SMTC_SDKCall_IEngineTrace_TraceRay = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CSpatialPartition::EnumerateElementsInBox()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // SpatialPartitionListMask_t listMask;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const Vector& mins;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const Vector& maxs;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // bool coarseTest;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // IPartitionEnumerator* pIterator;
    SMTC_SDKCall_CSpatialPartition_EnumerateElementsInBox = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CTFPointManager::GetMaxPoints()");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    SMTC_SDKCall_CTFPointManager_GetMaxPoints = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "FileWeaponInfo_t::Parse()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // KeyValues* pKeyValuesData;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const char* szWeaponName;
    SMTC_SDKCall_FileWeaponInfo_t_Parse = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CBaseEntity::TakeDamage()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // const CTakeDamageInfo&;
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain); // float
    SMTC_SDKCall_CBaseEntity_TakeDamage = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CLagCompensationManager::StartLagCompensation()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CBasePlayer* player;
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CUserCmd* cmd;
    SMTC_SDKCall_CLagCompensationManager_StartLagCompensation = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CLagCompensationManager::FinishLagCompensation()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CBasePlayer* player;
    SMTC_SDKCall_CLagCompensationManager_FinishLagCompensation = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFRadiusDamageInfo::CalculateFalloff()");
    SMTC_SDKCall_CTFRadiusDamageInfo_CalculateFalloff = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFRadiusDamageInfo::ApplyToEntity()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CBaseEntity* pEntity
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int
    SMTC_SDKCall_CTFRadiusDamageInfo_ApplyToEntity = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFGameRules::RadiusDamage()");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CTFRadiusDamageInfo& info
    SMTC_SDKCall_CTFGameRules_RadiusDamage = EndPrepSDKCall();

    SMTC_CLagCompensationManager_m_thisOffset = config.GetOffset("CLagCompensationManager::m_thisOffset");
    SMTC_CLagCompensationManager_m_isCurrentlyDoingCompensation = config.GetOffset("CLagCompensationManager::m_isCurrentlyDoingCompensation");

    // Generate SDKCalls used around the code: see function definition.
    SMTC_GenerateSDKCallInfo();

    // Read final config data specific to certain headers.

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_TFPLAYERCLASSDATA_T
    g_pTFPlayerClassDataMgr = config.GetAddress("g_pTFPlayerClassDataMgr");
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CUSERCMD
    config.GetKeyValue("CUserCmd_vtable", keyvalue, sizeof(keyvalue));
    SMTC_tf_point_t_vtable = RuntimeVTable.FindSingle(g_ServerPath, keyvalue);
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_TF_POINT_T
    config.GetKeyValue("tf_point_t_vtable", keyvalue, sizeof(keyvalue));
    SMTC_tf_point_t_vtable = RuntimeVTable.FindSingle(g_ServerPath, keyvalue);
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CENGINETRACE
    enginetrace = CEngineTrace(config.GetAddress("enginetrace"));
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CTFGAMERULES
    g_pGameRules = CTFGameRules(config.GetAddress("g_pGameRules"));
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CGLOBALVARS
    gpGlobals = CGlobalVars(config.GetAddress("gpGlobals"));
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CLAGCOMPENSATIONMANAGER
    lagcompensation = CLagCompensationManager(config.GetAddress("lagcompensation"));
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CSPATIALPARTITION
    partition = CSpatialPartition(config.GetAddress("partition"));
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CUTLRBTREE
    SMTC_pDefaultLessFunc = AddressOfString(s_aDefaultLessFunc);
    SetMemAccess(AddressOfString(s_aDefaultLessFunc), sizeof(s_aDefaultLessFunc), SH_MEM_EXEC | SH_MEM_READ | SH_MEM_WRITE);
#endif

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_UTIL
    config.GetKeyValue("CTraceFilterSimple_vtable", keyvalue, sizeof(keyvalue));
    SMTC_CTraceFilterSimple_vtable = SMTC_tf_point_t_vtable = RuntimeVTable.FindSingle(g_ServerPath, keyvalue);
    config.GetKeyValue("CFlaggedEntitiesEnum_vtable", keyvalue, sizeof(keyvalue));
    SMTC_CFlaggedEntitiesEnum_vtable = SMTC_tf_point_t_vtable = RuntimeVTable.FindSingle(g_ServerPath, keyvalue);
#endif

    delete config;

    // Instantiate g_Hooks.
    g_Hooks = new ArrayList(sizeof(SMTC_HookData));

    // For generating an offset on plugin start, getting datamap props from the world entity will not work 
    // because the world entity has not yet been initialised. Instead, I decided to go with getting the props
    // from CBasePlayer, which is part of the Source SDK.
    //int m_angRotation = FindDataMapInfo(0, "m_angRotation"), m_vecViewOffset = FindDataMapInfo(0, "m_vecViewOffset");
    int m_angRotation = FindSendPropInfo("CBasePlayer", "m_angRotation"), m_vecViewOffset = FindSendPropInfo("CBasePlayer", "m_vecViewOffset[0]");
    if (m_angRotation + 0x0C != m_vecViewOffset - 0x04)
        ThrowError("Could not calculate offset for CBaseEntity::m_RefEHandle.");
    SMTC_CBaseEntity_m_RefEHandle = m_angRotation + 0x0C;

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CUSERCMD
    SMTC_CBasePlayer_m_pCurrentCommand = FindSendPropInfo("CBasePlayer", "m_hViewModel") + 76;
#endif

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CTFWEAPONINFO
    SMTC_CTFWeaponBase_m_iWeaponMode = FindSendPropInfo("CTFWeaponBase", "m_iReloadMode") - SIZEOF_int; 
    SMTC_CTFWeaponBase_m_pWeaponInfo = FindSendPropInfo("CTFWeaponBase", "m_flReloadPriorNextFire") + SIZEOF_float;
#endif

#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_TF_POINT_T
    SMTC_CTFPointManager_m_Points = FindSendPropInfo("CTFFlameManager", "m_unNextPointIndex") + 8;
#endif

    // Call forwards.
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_VECTOR
    SMTC_VectorForward();
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_CTAKEDAMAGEINFO
    SMTC_CTakeDamageInfoForward();
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_UTIL
    SMTC_UTILForward();
#endif
#if defined NOTNHEAVY_SOURCEMOD_TYPE_COLLECTION_QANGLE
    SMTC_QAngleForward();
#endif

    g_SMTCInitialized = true;
}

//////////////////////////////////////////////////////////////////////////////
// SMTC                                                                     //
//////////////////////////////////////////////////////////////////////////////

methodmap SMTC
{
    // Get the operating system used.
    public static OSType GetOperatingSystem()
    {
        return OSTypeUsed;
    }

    // Hook onto entities and invoke forwards whenever a specific event occurs.
    // Intended to work in similar fashion to SDKHooks, uses DHooks behind the scenes.
    // The garbage collector is called within this function.
    public static void HookEntity(int entity, SMTC_ForwardType type, SMTC_ForwardCallback callback)
    {
        SMTC_HookEntity(entity, type, callback);
    }

    // Get hook data for the specified entity.
    public static void GetHookData(int entity, SMTC_ForwardType type, SMTC_HookData data)
    {
        SMTC_GetHookData(entity, type, data);
    }
}
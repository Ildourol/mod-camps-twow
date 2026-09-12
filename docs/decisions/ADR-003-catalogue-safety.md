# ADR-003: strict generic decoration cache
Context: template tables include gameplay-sensitive types and scripts.
Decision: named native GAMEOBJECT_TYPE_GENERIC plus display/size/script/quest/payload
validation; cache copied values from ObjectMgr; override table can restrict but not
override type safety. Category classification is separate.
Alternatives: expose all templates to GM, hardcoded prop list, search SQL per query.
Consequences: some desirable visuals are excluded, but no duplicated template data
or arbitrary unsafe spawning. Evidence: SharedDefines.h, GameObjectInfo and Use(),
ObjectMgr::GetGameObjectInfoMap; catalogue-safety.md specifies the full checks.

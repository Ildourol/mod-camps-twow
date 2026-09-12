# ADR-005: omit optional alt gathering in version 1
Context: target PlayerBots has master attachment, ownership and async map scheduling;
Warband uses different foreign bot command and phasing APIs.
Decision: no PlayerBots dependency/gathering feature in this version. Account-wide
ownership works for ordinary alts without logging in or teleporting bots.
Alternatives: invoke foreign `.playerbots` strings, reach into bot state, or add a
dedicated optional integration. These require a separately verified native bot
ownership/login/teleport contract and combined bots-enabled runtime acceptance.
Consequences: gathering is not a capability; BUILD_PLAYERBOTS=OFF link is verified.
Evidence: target PlayerbotScripts.cpp and core threading guide; Warband gather queue
review is behavioral only. No missing core seam is claimed for this optional feature.

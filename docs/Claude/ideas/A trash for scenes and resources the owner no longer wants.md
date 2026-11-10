---
type: idea
status: current
phase: ""
date: 2026-11-10
summary: "A trash for every scene and resource thrown away, since the owner asks whether a hidden scene is not one he no longer wants."
id: IDEA-048
aliases:
  - "IDEA-048"
since: 2026-11-10
area: app
source: owner
origin: "owner, W4 hand test"
tags:
  - idea
---

# A trash for scenes and resources the owner no longer wants

2026-11-10 (owner, while discussing [[ideas/Drag a scene between the storyboard and the Not in the storyboard group]]): "We could have a trash where everything we throw away goes, resources or scenes. Because if a scene is hidden, it is because we do not want it any more?"

The question behind it is what "not in the storyboard" means. Two meanings are possible and the app mixes them today: a scene **parked** for later (an alternative take, kept out of the film for now) and a scene **no longer wanted**. A trash would carry the second meaning (restorable, emptied on purpose, for scenes and for resources), and the group "Not in the storyboard" would keep the first. Related existing facts: older projects stored `ditched` and `archived` states, now read as hidden with a note (idea "drop ditched and archived", see the Index); resources have their own removal; `retiredIDs` keeps the IDs of deleted scenes ([[decisions/Deleted scene IDs are kept in retiredIDs]]).

Settled by the owner the same day: [[decisions/Parked scenes and thrown-away items are two different places]] (two places: parked scenes stay in "Not in the storyboard", a trash receives what is thrown away). Status `current`. Still to settle in an audit, as questions: what happens to a resource a scene still uses, whether the trash empties itself after a delay, and where it lives in the interface.

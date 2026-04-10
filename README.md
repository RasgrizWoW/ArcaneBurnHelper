# Arcane Burn Helper – TBC Anniversary

Arcane Burn Helper is a lightweight decision-support addon for Arcane Mages on The Burning Crusade Anniversary realms. It helps you decide when to Burn and when to Sustain based on real combat data, your mana, and your available mana cooldowns.

This addon is designed to be simple, lightweight, and readable during raids.

***

### Whats New?

*   Show/Hide commands
    *   /abh show (UI on)
    *   /abh hide (UI off)

***

# What Problem This Addon Solves

Arcane Mage in TBC is all about mana management:

*   Burn too early → you go OOM before the boss dies.
*   Sustain too long → you lose DPS.
*   Burn at the right time → maximum damage.

This addon answers one question in real time:

**Do I have enough mana and cooldowns to burn, or do I need to sustain?**

It does this by comparing:

*   Estimated Time To Kill (ETK)
*   Time until low mana
*   Time until OOM
*   Evocation, Mana Gem, and Potion cooldowns

***

# What The Addon Displays

## Column 1 – Fight & Mana

*   ETK – Estimated Time To Kill based on recent DPS
*   S Low – Time until you reach the low mana threshold using sustain rotation
*   B Low – Time until you reach the low mana threshold while burning
*   S OOM – Time until OOM using sustain rotation
*   B OOM – Time until OOM while burning
*   MODE – BURN / SUSTAIN / HOLD decision

## Column 2 – Status & Cooldowns

*   AB – Current Arcane Blast stack
*   Armor – Mage Armor or Molten Armor
*   Evo – Evocation cooldown status
*   Gem – Mana Gem cooldown status
*   Pot – Potion cooldown status

### Cooldown Colors

*   Green = Ready
*   Yellow = Ready Soon (configurable)
*   Red = On Cooldown
*   Gray = Not Available / Not in Bags

### Arcane Blast Stack Colors

*   AB0 = Gray
*   AB1 = Light Blue
*   AB2 = Yellow
*   AB3 = Orange/Red

***

# Mode Logic (Burn vs Sustain)

The addon determines MODE using:

*   ETK vs Time to Low Mana
*   ETK vs Time to OOM
*   Evocation availability
*   Mana Gem availability
*   Potion availability (if Mana Potion selected)

### Mode Meanings

*   BURN – You have enough mana and/or cooldowns to burn safely
*   SUSTAIN – You need to conserve mana to last the fight
*   HOLD – Borderline — either strategy works

***

# Options Menu

Open with: /abh options

## Configurable Settings

*   Sustain Rotation – Arcane Blast
*   Sustain Rotation – Frostbolt
*   Armor – Mage Armor or Molten Armor
*   Potion Type – Mana Potion or Destruction Potion
*   T5 2pc – Adds 20% Arcane Blast mana cost
*   Low Mana Trigger % – Mana % used for burn planning (default 20%)
*   Ready Soon Seconds – When cooldown indicator turns yellow
*   UI Scale – Scale of the addon UI

### Default Settings

*   Sustain Rotation: 2 AB / 3 Frostbolt
*   Default rotation macro:

```
/castsequence [nochanneling,@mouseover,harm,nodead][nochanneling,@focus,harm,nodead][nochanneling,harm,nodead] reset=mod:alt/3 Arcane Blast,Arcane Blast, Frostbolt, Frostbolt, Frostbolt
```

*   Armor: Molten
*   Potion: Destruction Potion
*   Low Mana: 20%
*   Ready Soon: 15 sec
*   Scale: 1.0

***

# Slash Commands

*   /abh lock – Lock frame (prevents moving & resizing)
*   /abh unlock – Unlock frame
*   /abh reset – Reset position to center
*   /abh options – Open options menu

***

# How To Use This Addon In Raids

General Arcane Mage logic with the addon:

*   Mode = BURN → Use Arcane Blast burn
*   Mode = SUSTAIN → Use sustain rotation
*   Evo ready → You can burn
*   Gem ready → You can burn
*   Mana pot ready → You can burn
*   All cooldowns down → Sustain

***

# Notes

*   Designed specifically for TBC Anniversary Arcane Mage
*   Arcane Blast spellID: 30451
*   Arcane Blast mana costs:
    *   AB0 = 195
    *   AB1 = 341
    *   AB2 = 488
    *   AB3 = 634
*   T5 2pc increases Arcane Blast mana cost by 20%
*   Arcane Meditation and Mage Armor mana regen are included in calculations

***

# Summary

Arcane Burn Helper tells you:

"If I burn now, will I run out of mana before the boss dies?"

And answers that question in real time using your DPS, mana, and cooldowns.

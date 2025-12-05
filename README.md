# EMS Mini-Game

A standalone revive system for FiveM that uses ox_lib for all the UI stuff. No frameworks needed, just ox_lib.

## What It Does

When someone is downed (player or NPC), you can use the `/treat` command to start a comprehensive treatment process:

**Patient Assessment** - Initial 3-5 second assessment that determines patient condition and affects difficulty

**3-Stage Mini-Game:**
1. **CPR Rhythm** - Hit skill checks in a row (difficulty varies based on condition)
2. **Bleeding Control** - Complete randomized QTE checks (more checks for severe injuries)
3. **Stabilization** - Hold a progress circle (longer for certain injury types)

If you complete all stages, they get revived. If you fail any stage, you gotta start over.

## Features

- **Patient Assessment** - Weighted condition reports that modify treatment difficulty
- **Injury-Based Difficulty** - Gunshot wounds, explosions, falls, fire, and melee injuries affect treatment
- **Complication System** - Random complications can occur during each stage (rib fractures, arterial bleeds, shock)
- **Biometrics Panel** - View patient vitals (pulse, respirations, bleeding level, consciousness) after each stage
- **Distance/Line of Sight Checks** - Treatment cancels if you move too far or lose sight of the patient
- **Performance Rating** - Get rated on your treatment speed and complication handling (Perfect Treatment, Good Work, Stable Condition)
- **Varied Success Messages** - Randomized success messages for variety
- **Visual Feedback** - Green screen flash on successful revive
- **Screen Shake Effects** - Explosion injuries cause screen shake during CPR

## Commands

- `/treat` - Start treating the closest downed player or NPC within 3 meters

## Requirements

- ox_lib (that's it)

## Configuration

Everything is in `config.lua`:
- Difficulty settings for each stage
- Number of checks per stage
- Revive health amount
- Cooldown timers
- Whether NPCs can be revived
- Animation settings
- Assessment duration and condition weights
- Injury-based difficulty modifiers
- Complication chances and effects
- Biometrics ranges
- Interrupt distance settings

## How It Works

The script finds the closest downed target when you use `/treat`. If there's no one nearby, it'll tell you. 

**Treatment Process:**
1. Assessment phase determines patient condition and injury type
2. Initial vitals are displayed in a dialog menu
3. Complete all 3 stages while managing complications
4. Vitals update after each stage completion
5. Get performance rating based on speed and complications handled
6. Patient is revived with visual feedback

The script continuously checks distance and line of sight - if you move too far or lose sight of the patient, treatment is cancelled. There's a cooldown so you can't spam it, and the script handles all the revive stuff properly so NPCs don't fall through the ground or die immediately after being revived.

## For support join my discord
https://discord.gg/5UP6j76CVe


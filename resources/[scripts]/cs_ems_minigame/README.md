# EMS Mini-Game

A standalone revive system for FiveM that uses ox_lib for all the UI stuff. No frameworks needed, just ox_lib.

## What It Does

When someone is downed (player or NPC), you can use the `/treat` command to start a 3-stage mini-game to revive them:

1. **CPR Rhythm** - Hit 5 skill checks in a row
2. **Bleeding Control** - Complete 4 randomized QTE checks
3. **Stabilization** - Hold a progress circle for a few seconds

If you complete all 3 stages, they get revived. If you fail any stage, you gotta start over.

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

## How It Works

The script finds the closest downed target when you use `/treat`. If there's no one nearby, it'll tell you. Once you start, you gotta complete all 3 stages without failing or the target moving away.

There's a cooldown so you can't spam it, and the script handles all the revive stuff properly so NPCs don't fall through the ground or die immediately after being revived.


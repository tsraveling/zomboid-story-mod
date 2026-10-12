# PZ Skill Keys

Keys for `ctx.perkLevel(key)` and site `perk = key`. Both resolve via `Perks.FromString`, so keys are the case-sensitive Java enum IDs, not the UI names. Levels run 0-10.

Check a minimum level: `ctx.perkLevel("Doctor") >= 3`

## Physical

| Key | UI name |
|---|---|
| `Fitness` | Fitness |
| `Strength` | Strength |
| `Sprinting` | Running |
| `Lightfoot` | Lightfooted |
| `Nimble` | Nimble |
| `Sneak` | Sneaking |

## Melee

| Key | UI name |
|---|---|
| `Axe` | Axe |
| `Blunt` | Long Blunt |
| `SmallBlunt` | Short Blunt |
| `LongBlade` | Long Blade |
| `SmallBlade` | Short Blade |
| `Spear` | Spear |
| `Maintenance` | Maintenance |

## Firearms

| Key | UI name |
|---|---|
| `Aiming` | Aiming |
| `Reloading` | Reloading |

## Crafting

| Key | UI name |
|---|---|
| `Woodwork` | Carpentry |
| `Carving` | Carving |
| `Cooking` | Cooking |
| `Electricity` | Electrical |
| `Glassmaking` | Glassmaking |
| `FlintKnapping` | Knapping |
| `Masonry` | Masonry |
| `Blacksmith` | Blacksmithing |
| `MetalWelding` | Welding |
| `Mechanics` | Mechanics |
| `Pottery` | Pottery |
| `Tailoring` | Tailoring |

## Farming

| Key | UI name |
|---|---|
| `Farming` | Agriculture |
| `Husbandry` | Animal Care |
| `Butchering` | Butchering |

## Survival

| Key | UI name |
|---|---|
| `Doctor` | First Aid |
| `Fishing` | Fishing |
| `PlantScavenging` | Foraging |
| `Tracking` | Tracking |
| `Trapping` | Trapping |

CAVEAT: Keys whose UI name differs are the usual typo trap: `Woodwork`, `Doctor`, `Sprinting`, `Lightfoot`, `Sneak`, `PlantScavenging`, `Husbandry`, `Farming`, `Blunt`, `MetalWelding`, `Blacksmith`, `FlintKnapping`. An unknown key makes `Perks.FromString` return nil or `Perks.None`, so the check silently fails.

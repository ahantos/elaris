# durability_dials.gd
# Every number of the durability rules, in one place. They are starting values:
# the combat simulator tunes them (plan, section 8, "Target and dials"), so they
# are variables and nothing else in the game writes a durability number down.
# The rules that read them are in autoload/durability_manager.gd.
extends RefCounted
class_name DurabilityDials

# --- notches ---
# A material's notch count is its durability score over the divisor, rounded
# half up, never fewer than the minimum (MaterialData.notches_for)
static var notch_divisor: float = 8.0
static var min_notches: int = 2
# What good making adds to the count: one for masterforged craftsmanship, one
# for each plus of magic
static var masterforged_notches: int = 1
static var notches_per_magic_plus: int = 1
# How many lost notches cost 1: to hit for a weapon, armour class for medium
# and heavy body armour. At 2 the first lost notch is free.
static var lost_notches_per_penalty: int = 2
# What medium and heavy armour still give over no armour until they break
static var armor_bonus_floor: int = 1

# --- marks: steady wear ---
# A fight gives every piece used in it one mark for this many rounds, rounded up
static var rounds_per_mark: int = 2
# A piece loses a notch when its marks reach its hardness times the factor.
# The seven secondary slots wear more slowly.
static var marks_factor: int = 3
static var marks_factor_secondary: int = 6

# --- blows: sudden wear ---
# Notches a critical hit takes from what it lands on, and a natural 1 from the
# weapon it was rolled with
static var critical_notches: int = 1
static var natural_one_notches: int = 1
# A critical hit with a two-handed weapon or one that deals bludgeoning damage
static var heavy_blow_notches: int = 2
# Without a shield a critical hit lands on the body armour this often, out of
# critical_spread; the rest of the time on another worn piece
static var critical_body_share: int = 2
static var critical_spread: int = 3
# Hardness: a difference of this much or more changes the loss. The harder
# striker takes extra notches; against a harder piece the blow leaves marks
# and no notch.
static var hardness_gap: int = 2
static var harder_striker_notches: int = 1
static var harder_piece_marks: int = 1
# The hardness of unarmoured flesh and of a bare fist
static var flesh_hardness: int = 1
# The chance of magic gear to ignore a notch lost to a blow, by its plus
static var magic_resist_chance: Array[float] = [0.0, 0.05, 0.10, 0.15]

# --- debuffs ---
# Cracked: this many notches lost in one blow
static var cracked_notches: int = 2
# Breached: attacks on the wearer are critical hits this much below a natural 20
static var breached_critical_range: int = 1
# Dented: tiles of movement lost
static var dented_speed_tiles: int = 1
# Torn: extra damage of every hit on the wearer
static var torn_extra_damage: int = 1
# Chipped: damage the weapon loses
static var chipped_damage_penalty: int = 1

# --- buffs ---
static var battle_honed_kills: int = 30
static var battle_honed_attack_bonus: int = 1
static var blood_forged_kills: int = 20
static var blood_forged_damage: int = 1
static var mage_touched_kills: int = 10
static var mage_touched_damage: int = 1
static var dragon_hardened_armor_class: int = 1

# --- repair ---
# What one repair kit restores, and the scrap it uses up with it
static var kit_notches: int = 1
static var kit_scrap_units: int = 1
# Scrap a salvaged piece gives: a body armour or a two-handed weapon gives more
static var salvage_units: int = 1
static var salvage_units_large: int = 2

# --- ageing ---
# Age a piece gains for each notch repaired, and the age that costs it one
# maximum notch: the factor times its original maximum
static var age_per_repaired_notch: int = 1
static var age_factor: int = 4

# --- loot ---
# Looted gear has lost at random from none to this share of its notches
static var looted_lost_share: float = 0.5

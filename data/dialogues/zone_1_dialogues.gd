# zone_1_dialogues.gd
# Static registry of every hand-authored Zone 1 dialogue tree (pure data, no state).
# DialogueManager loads this once in _ready(). Owned by A6 (World & Story).
# Schema per docs/ARCHITECTURE_CONTRACTS.md section 3:
#   {dialogue_id, npc_name, start_node: "root",
#    nodes: {node_id: {speaker, text, choices: [
#        {text, next: node_id|"" (end),
#         skill_check: {skill, dc, success_next, failure_next}   (optional),
#         condition: {type, ...}                                  (optional),
#         effects: [{type, ...}]                                  (optional)}]}}}
#
# Condition types handled by DialogueManager:
#   quest_active / quest_completed / quest_not_started  {quest_id}
#       (quest_not_started is an A6 schema EXTENSION — also true for failed quests)
#   reputation_at_least   {faction_id, value}
#   relationship_at_least {companion_id, value}
#   has_item              {item_id}
# Effect types: start_quest, give_item, take_item, give_gold, reputation,
#   relationship, recruit_companion, start_crisis.
#
# Zone 1 cast:
#   reeve_marta         - Brackenford  (city NPC, main-chain quest giver)
#   trader_lyssa        - Brackenford  (city NPC, side quest giver)
#   guildmaster_oswin   - Brackenford  (Merchants' Guild faction contact)
#   captain_aldric      - Dawnwatch    (city NPC, Order of the Dawn contact)
#   elder_senna         - Mournstead   (city NPC, Gravewardens contact)
#   mysterious_stranger - the woods    (main-chain pivot, starts the crisis)
extends RefCounted


static func get_definitions() -> Dictionary:
	"""Return {dialogue_id: dialogue tree Dictionary} for all Zone 1 dialogues."""
	var defs: Dictionary = {}

	# =========================================================================
	# REEVE MARTA — Brackenford. Main quest giver; persuasion DC 12 haggle.
	# =========================================================================
	defs["reeve_marta"] = {
		"dialogue_id": "reeve_marta",
		"npc_name": "Reeve Marta",
		"start_node": "root",
		"nodes": {
			"root": {
				"speaker": "Reeve Marta",
				"text": "Travelers, is it? Good. Brackenford is short on swords and long on troubles.",
				"choices": [
					{
						"text": "What troubles the town?",
						"next": "trouble",
						"condition": {"type": "quest_not_started", "quest_id": "mq_01_strange_tidings"},
					},
					{
						"text": "About the restless dead...",
						"next": "progress",
						"condition": {"type": "quest_active", "quest_id": "mq_01_strange_tidings"},
					},
					{
						"text": "The barrowfields are quieter now.",
						"next": "after",
						"condition": {"type": "quest_completed", "quest_id": "mq_01_strange_tidings"},
					},
					{"text": "Just passing through.", "next": ""},
				],
			},
			"trouble": {
				"speaker": "Reeve Marta",
				"text": "Graves stand open on the barrowfields east of here. The dead walk by night. The Order sends prayers, not soldiers — the town can pay twenty-five gold to see it put right.",
				"choices": [
					{
						"text": "I'll put them to rest.",
						"next": "thanks",
						"effects": [{"type": "start_quest", "quest_id": "mq_01_strange_tidings"}],
					},
					{
						# NOTE: when skill_check is present, success_next/failure_next
						# override "next" (DialogueManager ignores it).
						"text": "[Persuasion] Grave-work is dangerous work. Sweeten the pot.",
						"next": "",
						"skill_check": {
							"skill": "persuasion",
							"dc": 12,
							"success_next": "haggle_yes",
							"failure_next": "haggle_no",
						},
					},
					{"text": "Find another fool.", "next": ""},
				],
			},
			"haggle_yes": {
				"speaker": "Reeve Marta",
				"text": "Hells. Fine — twenty now, the rest when it's done. Don't make me regret it.",
				"choices": [
					{
						"text": "Done.",
						"next": "thanks",
						"effects": [
							{"type": "give_gold", "amount": 20},
							{"type": "start_quest", "quest_id": "mq_01_strange_tidings"},
						],
					},
				],
			},
			"haggle_no": {
				"speaker": "Reeve Marta",
				"text": "The purse is what it is. Take the work or leave it.",
				"choices": [
					{
						"text": "I'll take it anyway.",
						"next": "thanks",
						"effects": [{"type": "start_quest", "quest_id": "mq_01_strange_tidings"}],
					},
					{"text": "Leave it, then.", "next": ""},
				],
			},
			"thanks": {
				"speaker": "Reeve Marta",
				"text": "The barrowfields lie east, past the old mill. And warn the Gravewardens in Mournstead — Elder Senna should hear of this from a living mouth.",
				"choices": [
					{"text": "On my way.", "next": ""},
				],
			},
			"progress": {
				"speaker": "Reeve Marta",
				"text": "Still dead walking out there, by every report. Put them down — and don't forget Elder Senna in Mournstead.",
				"choices": [
					{"text": "I'm working on it.", "next": ""},
				],
			},
			"after": {
				"speaker": "Reeve Marta",
				"text": "So I hear, and Brackenford owes you for it. Mind the roads, though — the Guild pays for bandit trouble, if coin tempts you.",
				"choices": [
					{"text": "Good to know.", "next": ""},
				],
			},
		},
	}

	# =========================================================================
	# CAPTAIN ALDRIC — Dawnwatch. Order of the Dawn contact; reputation gate.
	# =========================================================================
	defs["captain_aldric"] = {
		"dialogue_id": "captain_aldric",
		"npc_name": "Captain Aldric",
		"start_node": "root",
		"nodes": {
			"root": {
				"speaker": "Captain Aldric",
				"text": "Captain Aldric, of the Order of the Dawn. State your business — the watch is doubled and my patience is thin.",
				"choices": [
					{
						"text": "Has the Order work for a free blade?",
						"next": "offer",
						"condition": {"type": "quest_not_started", "quest_id": "fq_dawn_cleansing_flame"},
					},
					{
						"text": "The dead you sent me after are burning.",
						"next": "fq_progress",
						"condition": {"type": "quest_active", "quest_id": "fq_dawn_cleansing_flame"},
					},
					{
						"text": "[Friend of the Dawn] What does the Order truly fear out here?",
						"next": "secret",
						"condition": {"type": "reputation_at_least", "faction_id": "order_of_dawn", "value": 10},
					},
					{"text": "Nothing, captain.", "next": ""},
				],
			},
			"offer": {
				"speaker": "Captain Aldric",
				"text": "The barrows vomit up bones faster than my lances can burn them. Six of the risen, hacked back to stillness — do that, and the Dawn will know your name.",
				"choices": [
					{
						"text": "Consider it done.",
						"next": "",
						"effects": [{"type": "start_quest", "quest_id": "fq_dawn_cleansing_flame"}],
					},
					{"text": "Not today.", "next": ""},
				],
			},
			"fq_progress": {
				"speaker": "Captain Aldric",
				"text": "Then keep burning. Six of them, remember — the Dawn counts.",
				"choices": [
					{"text": "Aye, captain.", "next": ""},
				],
			},
			"secret": {
				"speaker": "Captain Aldric",
				"text": "Between us? The Order's archives name this pattern. First open graves. Then ranks of walking dead. Then a herald in robes... and then the crowned thing they serve. Pray the archives are wrong.",
				"choices": [
					{"text": "Let's hope they are.", "next": ""},
				],
			},
		},
	}

	# =========================================================================
	# ELDER SENNA — Mournstead. Gravewardens contact; mq_01 talk target.
	# =========================================================================
	defs["elder_senna"] = {
		"dialogue_id": "elder_senna",
		"npc_name": "Elder Senna",
		"start_node": "root",
		"nodes": {
			"root": {
				"speaker": "Elder Senna",
				"text": "You walk loudly for the living. Speak softly — the dead of Mournstead still sleep, and I would keep it so.",
				"choices": [
					{
						"text": "Reeve Marta sends warning: the barrowfields stir.",
						"next": "warning",
						"condition": {"type": "quest_active", "quest_id": "mq_01_strange_tidings"},
					},
					{
						"text": "What stirs the dead here, Elder?",
						"next": "lore",
						"condition": {"type": "quest_active", "quest_id": "mq_02_whispers_in_the_barrows"},
					},
					{
						"text": "Have the Wardens need of anything?",
						"next": "fq_offer",
						"condition": {"type": "quest_not_started", "quest_id": "fq_wardens_quiet_earth"},
					},
					{"text": "Rest well, Elder.", "next": ""},
				],
			},
			"warning": {
				"speaker": "Elder Senna",
				"text": "...So it begins again. The Reeve did right to send you. Take this against the cold of the grave — and come back to me when the first of the risen lie still.",
				"choices": [
					{
						"text": "Thank you, Elder.",
						"next": "",
						"effects": [
							{"type": "give_item", "item_id": "potion_healing", "count": 1},
							{"type": "reputation", "faction_id": "gravewardens", "delta": 5},
						],
					},
				],
			},
			"lore": {
				"speaker": "Elder Senna",
				"text": "Something below the great barrow calls the dead upright. And a hooded one watches the graves from the wood's edge — neither warden nor knight nor honest traveler. Find them. Ask them what they see.",
				"choices": [
					{"text": "I will.", "next": ""},
				],
			},
			"fq_offer": {
				"speaker": "Elder Senna",
				"text": "Goblins root through the old barrows for trinkets, and the offering stones go bare. Bring two rite-loaves of bread for the stones, and still three of the wretched diggers.",
				"choices": [
					{
						"text": "The quiet earth will keep.",
						"next": "",
						"effects": [{"type": "start_quest", "quest_id": "fq_wardens_quiet_earth"}],
					},
					{"text": "Another time.", "next": ""},
				],
			},
		},
	}

	# =========================================================================
	# THE HOODED STRANGER — mq_02 talk target; starts the crisis after mq_03.
	# =========================================================================
	defs["mysterious_stranger"] = {
		"dialogue_id": "mysterious_stranger",
		"npc_name": "The Hooded Stranger",
		"start_node": "root",
		"nodes": {
			"root": {
				"speaker": "The Hooded Stranger",
				"text": "You see me. Few bother to look. Ask, then — the dead are patient, but I am not.",
				"choices": [
					{
						"text": "Who are you? Why watch the graves?",
						"next": "reveal",
						"condition": {"type": "quest_active", "quest_id": "mq_02_whispers_in_the_barrows"},
					},
					{
						"text": "The Herald is destroyed.",
						"next": "aftermath",
						"condition": {"type": "quest_completed", "quest_id": "mq_03_the_herald"},
					},
					{"text": "Stay out of trouble.", "next": ""},
				],
			},
			"reveal": {
				"speaker": "The Hooded Stranger",
				"text": "I watched these barrows before your town had walls. What wakes them is no restless spirit — it is a Herald, a thing sent ahead of a master. The old kingdom called him the Lich King. Kill the Herald now, or kneel to its master later.",
				"choices": [
					{"text": "Then the Herald dies.", "next": ""},
					{"text": "Why not stop it yourself?", "next": "refusal"},
				],
			},
			"refusal": {
				"speaker": "The Hooded Stranger",
				"text": "Because some doors must not be opened by those who hold the keys. Go. Kill it.",
				"choices": [
					{"text": "...As you say.", "next": ""},
				],
			},
			"aftermath": {
				"speaker": "The Hooded Stranger",
				"text": "The Herald falls, and still the ground hums. You have bought years, perhaps — not peace. The master stirs in the Hollow Throne, and the Borderlands will feel it first. Remember that I told you freely.",
				"choices": [
					{
						"text": "Then we will be ready.",
						"next": "",
						"effects": [
							{"type": "start_crisis", "crisis_id": "lich_king_rises"},
							{"type": "reputation", "faction_id": "gravewardens", "delta": 5},
						],
					},
				],
			},
		},
	}

	# =========================================================================
	# GUILDMASTER OSWIN — Brackenford. Merchants' Guild contact; has_item gate.
	# =========================================================================
	defs["guildmaster_oswin"] = {
		"dialogue_id": "guildmaster_oswin",
		"npc_name": "Guildmaster Oswin",
		"start_node": "root",
		"nodes": {
			"root": {
				"speaker": "Guildmaster Oswin",
				"text": "Guildmaster Oswin, at your service — provided your service profits the Guild. Coin moves the Borderlands, friend. Not prayers.",
				"choices": [
					{
						"text": "I heard you lost a shipment.",
						"next": "shipment",
						"condition": {"type": "quest_not_started", "quest_id": "sq_missing_shipment"},
					},
					{
						"text": "The Guild wants the toll roads cleared?",
						"next": "tolls",
						"condition": {"type": "quest_not_started", "quest_id": "fq_merchants_toll_roads"},
					},
					{
						"text": "I carry good iron, as it happens.",
						"next": "iron_talk",
						"condition": {"type": "has_item", "item_id": "material_iron"},
					},
					{"text": "Good day, Guildmaster.", "next": ""},
				],
			},
			"shipment": {
				"speaker": "Guildmaster Oswin",
				"text": "Sharp ears. A wagon of iron ingots, taken on the east road — bandits, three at the least. Dead bandits and returned iron pay sixty gold. The Guild does not haggle twice.",
				"choices": [
					{
						"text": "I'll fetch your iron.",
						"next": "",
						"effects": [{"type": "start_quest", "quest_id": "sq_missing_shipment"}],
					},
					{"text": "Pass.", "next": ""},
				],
			},
			"tolls": {
				"speaker": "Guildmaster Oswin",
				"text": "Five bandits swing their 'tolls' over the south road. Remove them — permanently — and the Guild's gratitude becomes tangible.",
				"choices": [
					{
						"text": "Consider them removed.",
						"next": "",
						"effects": [{"type": "start_quest", "quest_id": "fq_merchants_toll_roads"}],
					},
					{"text": "Not my fight.", "next": ""},
				],
			},
			"iron_talk": {
				"speaker": "Guildmaster Oswin",
				"text": "Ha! You DO carry ingots — a trader after my own ledger. Here, a finder's fee, and keep the Guild in mind when you sell.",
				"choices": [
					{
						"text": "A pleasure doing business.",
						"next": "",
						"effects": [
							{"type": "give_gold", "amount": 10},
							{"type": "reputation", "faction_id": "merchants_guild", "delta": 2},
						],
					},
				],
			},
		},
	}

	# =========================================================================
	# TRADER LYSSA — Brackenford tanner. Side quest giver.
	# =========================================================================
	defs["trader_lyssa"] = {
		"dialogue_id": "trader_lyssa",
		"npc_name": "Trader Lyssa",
		"start_node": "root",
		"nodes": {
			"root": {
				"speaker": "Trader Lyssa",
				"text": "Mind the racks — those hides cost more than you did. Lyssa, tanner. Buying pelts, selling leather.",
				"choices": [
					{
						"text": "You're buying wolf pelts?",
						"next": "pelts",
						"condition": {"type": "quest_not_started", "quest_id": "sq_pelts_for_winter"},
					},
					{"text": "How fares the pelt trade?", "next": "trade"},
					{"text": "Just looking.", "next": ""},
				],
			},
			"pelts": {
				"speaker": "Trader Lyssa",
				"text": "Winter's nipping and the caravans want lined cloaks. Four wolves culled and three good hides brought back — forty gold, paid on delivery.",
				"choices": [
					{
						"text": "Easy coin.",
						"next": "",
						"effects": [{"type": "start_quest", "quest_id": "sq_pelts_for_winter"}],
					},
					{"text": "Too much fur, too little gold.", "next": ""},
				],
			},
			"trade": {
				"speaker": "Trader Lyssa",
				"text": "Slow. The wolves got bold and the hunters got dead. You look neither — see me if you want honest work.",
				"choices": [
					{"text": "Maybe I will.", "next": ""},
				],
			},
		},
	}

	return defs

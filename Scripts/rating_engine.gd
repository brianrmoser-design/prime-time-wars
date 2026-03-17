###############################################################
# rating_engine.gd
#
# PURPOSE
# This script contains all scoring systems used to evaluate
# a television show.
#
# It is a direct conversion of the scoring logic inside
# game.js.
#
# The most important function is:
#
# rate_show(show)
#
# which returns a full breakdown of the show’s performance.
#
###############################################################

class_name RatingEngine


###############################################################
# ACTOR WEIGHTS
#
# These weights determine how important each acting trait
# is depending on the show type.
#
###############################################################

const ACTOR_WEIGHTS = {

	"sitcom_multicam": {
	"P":0.15, "C":0.10, "W":0.10, "I":0.05,
	"ED":0.05, "DC":0.15, "SH":0.20, "CT":0.20
	},

	"sitcom_singlecam": {
	"P":0.12, "C":0.10, "W":0.15, "I":0.05,
	"ED":0.12, "DC":0.10, "SH":0.20, "CT":0.16
	},

	"animated_comedy": {
	"P":0.00, "C":0.05, "W":0.05, "I":0.05,
	"ED":0.15, "DC":0.20, "SH":0.20, "CT":0.30
	},

	"sketch_comedy": {
	"P":0.15, "C":0.20, "W":0.20, "I":0.05,
	"ED":0.05, "DC":0.05, "SH":0.15, "CT":0.15
	},

	"drama_serial": {
	"P":0.15, "C":0.10, "W":0.05, "I":0.20,
	"ED":0.30, "DC":0.15, "SH":0.05, "CT":0.00
	},

	"drama_procedural": {
	"P":0.20, "C":0.20, "W":0.05, "I":0.10,
	"ED":0.15, "DC":0.20, "SH":0.05, "CT":0.05
	},

	"drama_scifi_fantasy": {
	"P":0.15, "C":0.10, "W":0.05, "I":0.20,
	"ED":0.15, "DC":0.25, "SH":0.05, "CT":0.00
	},

	"talk_late_night": {
	"P":0.10, "C":0.10, "W":0.25, "I":0.00,
	"SH":0.25, "CT":0.10, "BF":0.20, "ED":0.00
	},
  "news_evening": {
    "P": 0.20, "C": 0.15, "W": 0.05, "I": 0.05,
    "ED": 0.00,"DC": 0.05, "SH": 0.00, "CT": 0.00,
    "TI": 0.25, "BF": 0.25, "LC": 0.00, "CC": 0.00
  },
  "news_overnight": {
    "P": 0.20, "C": 0.15, "W": 0.00, "I": 0.00,
    "ED": 0.00, "DC": 0.00, "SH": 0.00, "CT": 0.00,
    "TI": 0.15, "BF": 0.40, "LC": 0.00, "CC": 0.00
  },
  "news_magazine": {
    "P": 0.15, "C": 0.10, "W": 0.10, "I": 0.10,
    "ED": 0.15, "DC": 0.10, "SH": 0.00, "CT": 0.00,
    "TI": 0.25, "BF": 0.05, "LC": 0.00, "CC": 0.00
  },
  "news_political": {
    "P": 0.10, "C": 0.15, "W": 0.15, "I": 0.10,
    "ED": 0.00, "DC": 0.00, "SH": 0.00, "CT": 0.00,
    "TI": 0.35, "BF": 0.15, "LC": 0.00, "CC": 0.00
  },
  "news_morning": {
    "P": 0.15, "C": 0.15, "W": 0.15, "I": 0.00,
    "ED": 0.05, "DC": 0.00, "SH": 0.10, "CT": 0.00,
    "TI": 0.15, "BF": 0.25, "LC": 0.00, "CC": 0.00
  },
  "news_talk_panel": {
    "P": 0.10, "C": 0.15, "W": 0.20, "I": 0.10,
    "ED": 0.00, "DC": 0.00, "SH": 0.00, "CT": 0.00,
    "TI": 0.30, "BF": 0.15, "LC": 0.00, "CC": 0.00
  },
  "reality_show": {
    "P": 0.20, "C": 0.10, "W": 0.10, "I": 0.10,
    "ED": 0.10, "DC": 0.10, "SH": 0.00, "CT": 0.00,
    "TI": 0.20, "BF": 0.10, "LC": 0.00, "CC": 0.00
  },
  "reality_competition": {
    "P": 0.20, "C": 0.10, "W": 0.10, "I": 0.10,
    "ED": 0.10, "DC": 0.10, "SH": 0.00, "CT": 0.00,
    "TI": 0.20, "BF": 0.10, "LC": 0.00, "CC": 0.00
  },
  "reality_dating": {
    "P": 0.20, "C": 0.10, "W": 0.10, "I": 0.10,
    "ED": 0.10, "DC": 0.10, "SH": 0.00, "CT": 0.00,
    "TI": 0.20, "BF": 0.10, "LC": 0.00, "CC": 0.00
  },
  "reality_cooking": {
    "P": 0.20, "C": 0.10, "W": 0.10, "I": 0.10,
    "ED": 0.10, "DC": 0.10, "SH": 0.00, "CT": 0.00,
    "TI": 0.20, "BF": 0.10, "LC": 0.00, "CC": 0.00
  },
   "drama_daytime_soap": {
    "P": 0.10, "C": 0.20, "W": 0.00, "I": 0.20,
    "ED": 0.25, "DC": 0.25, "SH": 0.00, "CT": 0.00,
    "TI": 0.00, "BF": 0.00, "LC": 0.00, "CC": 0.00
  },
  "sports_live": {
    "P": 0.05, "C": 0.10, "W": 0.20, "I": 0.00,
    "ED": 0.10, "DC": 0.00, "SH": 0.00, "CT": 0.00,
    "TI": 0.40, "BF": 0.15, "LC": 0.00, "CC": 0.00
}
}


###############################################################
# WRITER WEIGHTS
###############################################################

const WRITER_WEIGHTS = {
	"W":0.30,
	"ED":0.25,
	"DC":0.20,
	"SH":0.25
}


###############################################################
# SHOWRUNNER WEIGHTS
###############################################################

const SHOWRUNNER_WEIGHTS = {
	"C":0.15,
	"W":0.05,
	"CC":0.30,
	"LC":0.25,
	"ED":0.10,
	"DC":0.10,
	"SH":0.05
}

###############################################################
# rate_show
#
# MAIN ENGINE FUNCTION
#
# Takes a show object built by build_show_object()
# and returns a full breakdown of scores.
###############################################################

static func rate_show(show:Dictionary):

	var show_type = show["showType"]

	var actors = show["actors"]
	var writers = show["writers"]
	var showrunners = show["showrunners"]


	###########################################################
	# ACTOR SCORING
	###########################################################

	var actor_results = []
	var lead_scores = []
	var support_scores = []

	for actor in actors:

		var score = compute_actor_score(actor["traits"], show_type)

		actor_results.append({
			"name": actor["name"],
			"role": actor["role"],
			"score": score
		})

		if actor["role"] == "lead":
			lead_scores.append(score)

		if actor["role"] == "support":
			support_scores.append(score)


	var cast_score = compute_cast_score(lead_scores, support_scores)


	###########################################################
	# WRITER SCORING
	###########################################################

	var writer_results = []
	var writer_entries = []

	for writer in writers:

		var score = compute_writer_score(writer["traits"])

		writer_results.append({
			"name": writer["name"],
			"role": writer["role"],
			"score": score
		})

		writer_entries.append({
			"score": score,
			"role": writer["role"]
		})

	var writing_score = compute_writing_score(writer_entries)


	###########################################################
	# SHOWRUNNER SCORING
	###########################################################

	var showrunner_results = []
	var showrunner_scores = []

	for sr in showrunners:

		var score = compute_showrunner_score(sr["traits"])

		showrunner_results.append({
			"name": sr["name"],
			"score": score
		})

		showrunner_scores.append(score)

	var showrunner_score = aggregate_showrunner_scores(showrunner_scores)


	###########################################################
	# FINAL SHOW QUALITY
	###########################################################

	var base_show_quality = compute_base_show_quality(
		cast_score,
		writing_score,
		showrunner_score
	)


	return {
		"actors": actor_results,
		"writers": writer_results,
		"showrunners": showrunner_results,
		"castScore": cast_score,
		"writingScore": writing_score,
		"showrunnerScore": showrunner_score,
		"baseShowQuality": base_show_quality
	}

###############################################################
# compute_base_show_quality
###############################################################

static func compute_base_show_quality(cast_score, writing_score, showrunner_score):

	return (
		0.5 * cast_score +
		0.3 * writing_score +
		0.2 * showrunner_score
	)

###############################################################
# compute_cast_score
#
# Lead actors count more than supporting actors.
###############################################################

static func compute_cast_score(lead_scores:Array, support_scores:Array):

	var lead_avg = 0.0
	var support_avg = 0.0

	if lead_scores.size() > 0:
		lead_avg = lead_scores.reduce(func(a,b): return a+b) / lead_scores.size()

	if support_scores.size() > 0:
		support_avg = support_scores.reduce(func(a,b): return a+b) / support_scores.size()

	if lead_scores.is_empty() and support_scores.is_empty():
		return 0

	if support_scores.is_empty():
		return lead_avg

	if lead_scores.is_empty():
		return support_avg

	return 0.6 * lead_avg + 0.4 * support_avg


###############################################################
# compute_writing_score
#
# Handles writing room weighting.
###############################################################

static func compute_writing_score(writer_entries:Array):

	var weighted_sum = 0.0
	var room_size = 0.0

	for w in writer_entries:

		var weight = 1.0

		if w["role"] == "head":
			weight = 1.5

		if w["role"] == "showrunner":
			weight = 2.0

		weighted_sum += w["score"] * weight
		room_size += weight

	var base_avg = weighted_sum / room_size

	var raw_factor = min(room_size / 6.0, 1.0)
	var room_factor = 0.5 + 0.5 * raw_factor

	return base_avg * room_factor


###############################################################
# aggregate_showrunner_scores
#
# JS equivalent:
# aggregateShowrunnerScores(scores)
#
# Handles cases where there are:
# 0 showrunners
# 1 showrunner
# multiple showrunners
###############################################################

static func aggregate_showrunner_scores(scores:Array):

	# Case 1: no showrunners exist
	# In JS this would return NaN, but in Godot we return 0
	if scores.size() == 0:
		return 0

	# Case 2: exactly one showrunner
	if scores.size() == 1:
		return scores[0]

	# Case 3: multiple showrunners
	var total = 0.0

	for s in scores:
		total += s

	return total / scores.size()

###############################################################
# compute_actor_score
#
# Calculates an actor's score based on their traits
# and the show type.
###############################################################

static func compute_actor_score(traits:Dictionary, show_type:String):

	# Stop immediately if this show type has no actor scoring rules
	if not ACTOR_WEIGHTS.has(show_type):
		return 0

	# Only retrieve weights after confirming they exist
	var w = ACTOR_WEIGHTS[show_type]


	return (
		traits.get("P",0)  * w.get("P",0) +
		traits.get("C",0)  * w.get("C",0) +
		traits.get("W",0)  * w.get("W",0) +
		traits.get("I",0)  * w.get("I",0) +
		traits.get("ED",0) * w.get("ED",0) +
		traits.get("DC",0) * w.get("DC",0) +
		traits.get("SH",0) * w.get("SH",0) +
		traits.get("CT",0) * w.get("CT",0) +
		traits.get("TI",0) * w.get("TI",0) +
		traits.get("BF",0) * w.get("BF",0) +
		traits.get("LC",0) * w.get("LC",0) +
		traits.get("CC",0) * w.get("CC",0)
	)


###############################################################
# compute_writer_score
###############################################################

static func compute_writer_score(traits:Dictionary):

	return (
		traits.get("W",0)  * WRITER_WEIGHTS["W"] +
		traits.get("ED",0) * WRITER_WEIGHTS["ED"] +
		traits.get("DC",0) * WRITER_WEIGHTS["DC"] +
		traits.get("SH",0) * WRITER_WEIGHTS["SH"]
	)


###############################################################
# compute_showrunner_score
###############################################################

static func compute_showrunner_score(traits:Dictionary):

	return (
		traits.get("C",0)  * SHOWRUNNER_WEIGHTS["C"] +
		traits.get("W",0)  * SHOWRUNNER_WEIGHTS["W"] +
		traits.get("CC",0) * SHOWRUNNER_WEIGHTS["CC"] +
		traits.get("LC",0) * SHOWRUNNER_WEIGHTS["LC"] +
		traits.get("ED",0) * SHOWRUNNER_WEIGHTS["ED"] +
		traits.get("DC",0) * SHOWRUNNER_WEIGHTS["DC"] +
		traits.get("SH",0) * SHOWRUNNER_WEIGHTS["SH"]
	)
class_name RatingEngine

###############################################################
# rating_engine.gd
#
# WHAT THIS FILE DOES (in plain terms)
# ------------------------------------
# ShowBuilder hands us a **single show** already sorted into: on-camera people,
# writers (including showrunners in that list), and showrunners on their own.
#
# Here we turn that into **numbers** the game can show on charts:
#   • How strong the **cast / hosts** feel as a group
#   • How strong the **writing room** feels
#   • How strong **showrunner leadership** feels
#   • One **overall “base show quality”** that mixes those three
#
# HOW SKILLS ARE USED
# --------------------
# Each person has skills stored as roughly **0–100** (higher = stronger). We
# don’t judge “good or bad” here—we **combine** those numbers using **weights**:
# “for this job, we care this much about acting, this much about comedy,” etc.
# Think of it as a **blend**: important skills count more; missing skills count
# as zero.
#
# The final scores are **not** forced to be out of 100—they’re whatever you get
# from those blends. That’s normal for this style of model.
#
# WHAT “SHOW TYPE” CHANGES
# ------------------------
# The kind of show (e.g. **news** vs **most other formats**) changes which
# on-camera skills matter most—news leans harder on **broadcasting**; other
# formats lean more on acting and the “spectrum” traits. Right now only a
# simple **news vs not-news** split is implemented; you can add finer rules later.
###############################################################

## How we mix **writing** skills for one writer: writing craft, comedy, drama.
## The three percentages add up to 100% so the result reads like one blended skill.
const WRITER_WEIGHTS := {"WRI": 0.40, "COM": 0.30, "DRM": 0.30}

## How we mix **showrunner** skills: running the machine, plus comedy/drama tone.
## Again, three pieces that add up to 100%.
const SHOWRUNNER_WEIGHTS := {"LOG": 0.50, "COM": 0.25, "DRM": 0.25}

## For **on-camera** people: how much each skill matters in the blend.
## All the pieces here add up to 100% so you get one fair “on-air” number per person.
##
## There are two recipes:
##   • **Most shows** — balanced toward acting, comedy, drama, a bit of broadcasting,
##     and the personality spectrums.
##   • **News-style shows** (anything whose type name starts with “news_”) —
##     much heavier on **broadcasting**, because desk and field delivery matter more.
const W_ON_AIR_GENERAL := {
	"ACT": 0.28, "COM": 0.18, "DRM": 0.18, "BCN": 0.08,
	"DIST": 0.09, "WVW": 0.09, "EDY": 0.05, "VUL": 0.05
}
const W_ON_AIR_NEWS := {
	"ACT": 0.10, "COM": 0.06, "DRM": 0.06, "BCN": 0.42,
	"DIST": 0.10, "WVW": 0.10, "EDY": 0.08, "VUL": 0.08
}


## Main pass: score the cast, the writing room, the showrunner side, then mix them.
static func rate_show(show: Dictionary) -> Dictionary:
	var show_type: String = show["showType"]
	var actors: Array = show["actors"]
	var writers: Array = show["writers"]
	var showrunners: Array = show["showrunners"]

	# On-camera: one blended score per person; keep “lead” separate from “support” for the next step.
	var actor_results: Array = []
	var lead_scores: Array = []
	var support_scores: Array = []
	for actor in actors:
		var score := compute_on_air_score(actor["traits"], show_type)
		actor_results.append({"name": actor["name"], "role": actor["role"], "score": score})
		if actor["role"] == "lead":
			lead_scores.append(score)
		if actor["role"] == "support":
			support_scores.append(score)
	var cast_score := _compute_cast_score(lead_scores, support_scores)

	# Writers: score each person, then apply “room size” rules (bigger room, different weighting).
	var writer_results: Array = []
	var writer_entries: Array = []
	for writer in writers:
		var wscore := compute_writer_score(writer["traits"])
		writer_results.append({"name": writer["name"], "role": writer["role"], "score": wscore})
		writer_entries.append({"score": wscore, "role": writer["role"]})
	var writing_score := _compute_writing_score(writer_entries)

	# Showrunners: one leadership score each; if there are several, we average them.
	var showrunner_results: Array = []
	var showrunner_scores: Array = []
	for sr in showrunners:
		var sr_score := compute_showrunner_score(sr["traits"])
		showrunner_results.append({"name": sr["name"], "score": sr_score})
		showrunner_scores.append(sr_score)
	var showrunner_score := _aggregate_showrunner_scores(showrunner_scores)

	# Overall: half cast, three-tenths writing, two-tenths leadership — except news with no writers:
	# those formats are not scored on a writing room, so cast + leadership share the full weight.
	var base_show_quality: float
	if _is_news_show(show_type) and writers.is_empty():
		base_show_quality = _compute_base_show_quality_news_no_writers(cast_score, showrunner_score)
	else:
		base_show_quality = _compute_base_show_quality(cast_score, writing_score, showrunner_score)
	return {
		"actors": actor_results,
		"writers": writer_results,
		"showrunners": showrunner_results,
		"castScore": cast_score,
		"writingScore": writing_score,
		"showrunnerScore": showrunner_score,
		"baseShowQuality": base_show_quality
	}


## Choose the on-camera recipe: news shows vs everything else.
## You can add more branches later (sports, late-night talk, etc.).
static func _on_air_weights_for_type(show_type: String) -> Dictionary:
	if show_type.begins_with("news_"):
		return W_ON_AIR_NEWS
	return W_ON_AIR_GENERAL


## One on-camera person: multiply each skill by “how much it matters,” then add the pieces.
## If a skill is missing, it counts as zero.
static func compute_on_air_score(traits: Dictionary, show_type: String) -> float:
	var w: Dictionary = _on_air_weights_for_type(show_type)
	var total := 0.0
	for k in w.keys():
		total += float(traits.get(k, 0)) * float(w[k])
	return total


## One writer’s blended score (same math for staff, head, or showrunner row—their **role**
## only matters later when we size the room).
static func compute_writer_score(traits: Dictionary) -> float:
	return (
		float(traits.get("WRI", 0)) * WRITER_WEIGHTS["WRI"] +
		float(traits.get("COM", 0)) * WRITER_WEIGHTS["COM"] +
		float(traits.get("DRM", 0)) * WRITER_WEIGHTS["DRM"]
	)


## One showrunner’s leadership score from their skills (only some traits are used in the math today).
static func compute_showrunner_score(traits: Dictionary) -> float:
	return (
		float(traits.get("LOG", 0)) * SHOWRUNNER_WEIGHTS["LOG"] +
		float(traits.get("COM", 0)) * SHOWRUNNER_WEIGHTS["COM"] +
		float(traits.get("DRM", 0)) * SHOWRUNNER_WEIGHTS["DRM"]
	)


## The big three ingredients mixed into one headline number (you can change the 50/30/20 split).
static func _compute_base_show_quality(cast_score: float, writing_score: float, showrunner_score: float) -> float:
	return 0.5 * cast_score + 0.3 * writing_score + 0.2 * showrunner_score


static func _is_news_show(show_type: String) -> bool:
	return show_type.begins_with("news_")


## News with no writing staff: drop the writing pillar and scale cast + leadership so weights sum to 1
## (same relative balance as 0.5 : 0.2 → 5/7 vs 2/7).
static func _compute_base_show_quality_news_no_writers(cast_score: float, showrunner_score: float) -> float:
	const w_cast := 0.5
	const w_sr := 0.2
	var non_write := w_cast + w_sr
	return (w_cast / non_write) * cast_score + (w_sr / non_write) * showrunner_score


## Turn separate lead and support scores into **one cast score**.
## If both groups exist: **60%** the average of leads, **40%** the average of support.
## If only one group exists, we use that group’s average alone.
static func _compute_cast_score(lead_scores: Array, support_scores: Array) -> float:
	var lead_avg := 0.0
	var support_avg := 0.0
	if lead_scores.size() > 0:
		lead_avg = lead_scores.reduce(func(a, b): return a + b) / lead_scores.size()
	if support_scores.size() > 0:
		support_avg = support_scores.reduce(func(a, b): return a + b) / support_scores.size()
	if lead_scores.is_empty() and support_scores.is_empty():
		return 0.0
	if support_scores.is_empty():
		return lead_avg
	if lead_scores.is_empty():
		return support_avg
	return 0.6 * lead_avg + 0.4 * support_avg


## Writing **room** score (two ideas combined):
## 1) Start from each writer’s score, but **count some jobs heavier**—a head writer
##    counts more than a staff writer; a showrunner row counts the most.
## 2) Apply a **room-size factor**: tiny rooms are penalized; once the “effective”
##    headcount is about six or more, the bonus stops growing. The multiplier on
##    the room ends up between half strength and full strength.
static func _compute_writing_score(writer_entries: Array) -> float:
	var weighted_sum := 0.0
	var room_size := 0.0
	for w in writer_entries:
		var weight := 1.0
		if w["role"] == "head":
			weight = 1.5
		if w["role"] == "showrunner":
			weight = 2.0
		weighted_sum += w["score"] * weight
		room_size += weight
	if room_size <= 0.0:
		return 0.0
	var base_avg := weighted_sum / room_size
	var raw_factor: float = minf(room_size / 6.0, 1.0)
	var room_factor := 0.5 + 0.5 * raw_factor
	return base_avg * room_factor


## Several showrunners: plain average. None listed: zero for this pillar.
static func _aggregate_showrunner_scores(scores: Array) -> float:
	if scores.is_empty():
		return 0.0
	if scores.size() == 1:
		return scores[0]
	var total := 0.0
	for s in scores:
		total += s
	return total / scores.size()

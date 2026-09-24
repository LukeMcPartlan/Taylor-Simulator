extends SceneTree
## Headless verification for the FakeTok phone minigame:
##  - 16 display images exist and load
##  - prompt weighting: down appears ~3x as often as any other direction
##  - up/down navigation: down advances (wraps), up goes back, never past 0
##  - left/right toggle comments; up/down scroll comments while open
##  - comment pool: ~1/50 negative, positive usernames from the female pools,
##    negative usernames from the gamer pool, vote ranges sane
##
## Run: godot --headless --script tests/test_faketok.gd

var _failures: Array = []
var _checks: int = 0


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_failures.append(name)
		printerr("FAIL: ", name)


func _initialize() -> void:
	_run()
	print("----")
	print("checks: %d  failures: %d" % [_checks, _failures.size()])
	print("ALL GREEN" if _failures.is_empty() else "FAILURES PRESENT")
	quit()


func _run() -> void:
	var script: GDScript = load("res://scripts/minigames/phone_swipe.gd")

	# --- Display art ------------------------------------------------------
	var loaded := 0
	for i in 16:
		var tex: Texture2D = load("res://placeholder art/phone/display_%02d.png" % (i + 1))
		if tex != null:
			loaded += 1
	_check(loaded == 16, "faketok: all 16 display images load (got %d)" % loaded)

	# --- Prompt weighting ---------------------------------------------------
	var game = script.new()
	game.size = Vector2(700, 560)
	root.add_child(game)
	game.start()
	game.set("_display_index", 5)  # mid-deck so up is eligible
	var counts := {KEY_DOWN: 0, KEY_UP: 0, KEY_LEFT: 0, KEY_RIGHT: 0}
	for i in 1200:
		game.test_pick_prompt()
		var p: int = game.get_prompt()
		counts[p] = int(counts[p]) + 1
	var down_share := float(counts[KEY_DOWN]) / 1200.0
	_check(down_share > 0.40 and down_share < 0.60,
		"faketok: down is ~3x weighted (share %.2f)" % down_share)
	var up_share := float(counts[KEY_UP]) / 1200.0
	_check(up_share > 0.10 and up_share < 0.25,
		"faketok: up/left/right share the rest (up %.2f)" % up_share)

	# --- Navigation ---------------------------------------------------------
	game.set("_display_index", 3)
	game.test_set_prompt(KEY_DOWN)
	game.test_press(KEY_DOWN)
	_check(int(game.get("_display_index")) == 4, "faketok: down advances")
	game.set("_display_index", 15)
	game.test_set_prompt(KEY_DOWN)
	game.test_press(KEY_DOWN)
	_check(int(game.get("_display_index")) == 0, "faketok: down wraps at the end")
	game.set("_display_index", 3)
	game.test_set_prompt(KEY_UP)
	game.test_press(KEY_UP)
	_check(int(game.get("_display_index")) == 2, "faketok: up goes to the prior tiktok")
	game.set("_display_index", 0)
	game.test_set_prompt(KEY_UP)
	game.test_press(KEY_UP)
	_check(int(game.get("_display_index")) == 0, "faketok: can't go up from the first tiktok")

	# --- Wrong input still acts ------------------------------------------------
	# A wrong arrow performs its swipe anyway (-1 dopamine), but the prompt
	# arrow stays the same and blinks red instead of advancing to a new one.
	game.set("_display_index", 3)
	game.test_set_prompt(KEY_UP)  # prompt wants UP...
	game.test_press(KEY_DOWN)      # ...but we press DOWN (wrong)
	_check(int(game.get("_display_index")) == 4,
		"faketok: wrong input still performs the swipe")
	_check(int(game.get_prompt()) == KEY_UP,
		"faketok: wrong input keeps the same prompt arrow")
	_check(float(game.get("_flash")) > 0.0,
		"faketok: wrong input blinks the arrow red")

	# --- Wrong input: comment toggle + scroll still act -------------------------
	# Pressing LEFT while the prompt wants UP still toggles the comments open
	# (wrong: -1 dopamine, prompt stays, red blink).
	game.set("_comments_open", false)
	game.test_set_prompt(KEY_UP)  # prompt wants UP...
	game.test_press(KEY_LEFT)      # ...but we press LEFT (wrong)
	_check(bool(game.get("_comments_open")),
		"faketok: wrong input still toggles comments open")
	_check(int(game.get_prompt()) == KEY_UP,
		"faketok: wrong comment toggle keeps the prompt")
	_check(float(game.get("_flash")) > 0.0,
		"faketok: wrong comment toggle blinks red")
	# With comments open, a wrong DOWN scrolls the comments instead of
	# advancing the TikTok.
	game.set("_scroll", 0)
	var idx_before: int = int(game.get("_display_index"))
	game.test_set_prompt(KEY_UP)  # prompt wants UP...
	game.test_press(KEY_DOWN)      # ...but we press DOWN (wrong)
	_check(int(game.get("_scroll")) == 1,
		"faketok: wrong input scrolls comments while open")
	_check(int(game.get("_display_index")) == idx_before,
		"faketok: wrong scroll does not advance the tiktok")
	# Reset for the sections below.
	game.set("_comments_open", false)
	game.set("_scroll", 0)

	# --- Comments toggle + scroll -------------------------------------------
	_check(not bool(game.get("_comments_open")), "faketok: comments start closed")
	game.test_set_prompt(KEY_LEFT)
	game.test_press(KEY_LEFT)
	_check(bool(game.get("_comments_open")), "faketok: left opens comments")
	_check(int(game.get("_comments").size()) == 60, "faketok: comment pool has 60 entries")
	# Scroll down to the bottom, then back up; clamps at both ends.
	for i in 70:
		game.test_set_prompt(KEY_DOWN)
		game.test_press(KEY_DOWN)
	var max_scroll: int = 60 - 6
	_check(int(game.get("_scroll")) == max_scroll, "faketok: comment scroll clamps at the bottom")
	for i in 70:
		game.test_set_prompt(KEY_UP)
		game.test_press(KEY_UP)
	_check(int(game.get("_scroll")) == 0, "faketok: comment scroll clamps at the top")
	game.test_set_prompt(KEY_RIGHT)
	game.test_press(KEY_RIGHT)
	_check(not bool(game.get("_comments_open")), "faketok: right closes comments")

	# --- Comment pool composition -------------------------------------------
	var neg := 0
	var total := 0
	var bad_pos_name := false
	var bad_neg_name := false
	var bad_votes := false
	var pos_names: Array = game.NAMES_POSITIVE
	var neg_names: Array = game.NAMES_NEGATIVE
	for round in 12:
		var pool: Array = game._gen_comments()
		for c in pool:
			total += 1
			var d: Dictionary = c
			if bool(d["neg"]):
				neg += 1
				if not neg_names.has(String(d["name"])):
					bad_neg_name = true
				if int(d["votes"]) > -1_000_000 or int(d["votes"]) < -9_999_999:
					bad_votes = true
			else:
				if not pos_names.has(String(d["name"])):
					bad_pos_name = true
				if int(d["votes"]) < 1_200 or int(d["votes"]) > 98_700:
					bad_votes = true
				if not game.POSITIVE_TEXTS.has(String(d["text"])):
					bad_votes = true
	_check(game.POSITIVE_TEXTS.size() >= 10,
		"faketok: a dozen different positive comments (got %d)" % game.POSITIVE_TEXTS.size())
	var neg_rate := float(neg) / float(total)
	_check(neg_rate > 0.005 and neg_rate < 0.05,
		"faketok: ~1/50 comments are negative (rate %.3f over %d)" % [neg_rate, total])
	_check(not bad_pos_name, "faketok: positive names come from the female pools")
	_check(not bad_neg_name, "faketok: negative names come from the gamer pool")
	_check(not bad_votes, "faketok: vote ranges and positive texts are sane")

	# --- Endless + instant quit ---------------------------------------------
	# No win condition: 30 correct presses never end the game on their own...
	var game2 = script.new()
	game2.size = Vector2(700, 560)
	root.add_child(game2)
	var done := {}
	game2.finished.connect(func(success: bool) -> void: done["ok"] = success)
	game2.start()
	for i in 30:
		game2.test_press(game2.get_prompt())
	_check(not done.has("ok") and not bool(game2.get("_over")),
		"faketok: endless — 30 correct swipes never end the game")
	# ...and quitting closes instantly, no banner wait.
	game2.quit()
	_check(done.has("ok") and not bool(done["ok"]),
		"faketok: quit closes instantly")
	game.queue_free()
	game2.queue_free()

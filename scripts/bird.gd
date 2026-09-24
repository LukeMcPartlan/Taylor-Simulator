class_name Bird
extends Area2D
## One-time bird collectible. Five of these live in Main.tscn (children of
## World) — drag them around the editor and swap their sprite_texture in
## the inspector.
##
## Each real game mode has one fixed species (GameState.MODE_BIRDS); only
## that mode's bird appears, and only while it's still uncollected. Touching
## it collects it FOREVER (+50 serotonin, banked). In PRACTICE mode all five
## birds are out every day as a gallery: uncollected ones are touchable,
## collected ones stay visible but dimmed and no longer reward.
##
## Exported knobs (per-bird, set in the editor):
##   bird_id: String         must be unique; one of GameState.BIRD_IDS
##   bird_name: String       shown in the "+50 serotonin (Robin!)" popup
##   sprite_texture: Texture2D  Luke's art goes here
##   reward_serotonin: float default 50.0

@export var bird_id: String = "robin"
@export var bird_name: String = "Robin"
@export var sprite_texture: Texture2D
@export var reward_serotonin: float = 50.0

const TOUCH_RADIUS: float = 28.0

var _sprite: Sprite2D
var _active_today: bool = false
var _bob_t: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	add_to_group("bird")
	_base_y = position.y

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	if sprite_texture != null:
		_sprite.texture = sprite_texture
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = TOUCH_RADIUS
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)
	GameState.day_started.connect(_on_day_started)
	_update_for_day()


func _process(delta: float) -> void:
	if not _active_today or not visible:
		return
	# Gentle idle bob so the bird reads as alive.
	_bob_t += delta
	_sprite.position.y = sin(_bob_t * 3.0) * 3.0


func _on_day_started(_day: int) -> void:
	_update_for_day()


func _update_for_day() -> void:
	_active_today = GameState.bird_active_today(bird_id)
	# Found birds stay visible in practice (gallery) but dimmed and
	# untouchable; everywhere else they simply don't appear.
	var found := GameState.bird_found(bird_id)
	visible = _active_today or (found and GameState.all_birds_daily())
	modulate.a = 0.45 if found else 1.0
	# Deferred: this can run inside signal callbacks (day_started,
	# body_entered), where flipping monitoring directly is blocked.
	set_deferred("monitoring", _active_today and not found)
	set_deferred("monitorable", _active_today and not found)
	_sprite.position = Vector2.ZERO


func _on_body_entered(body: Node2D) -> void:
	if not _active_today:
		return
	if not body.is_in_group("player"):
		return
	if not GameState.collect_bird(bird_id, reward_serotonin):
		return
	_active_today = false
	var world := get_parent()
	if world != null and world.has_method("spawn_float_text"):
		world.spawn_float_text(global_position + Vector2(0, -60),
			"+%d serotonin (%s!)" % [int(reward_serotonin), bird_name],
			Color(1.0, 0.9, 0.4))
	GameState.say("TAYLOR", "Oh! A %s! Hi little guy!" % bird_name.to_lower())
	_fly_away()


func _fly_away() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 160.0, 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(_hide_after_flight)


func _hide_after_flight() -> void:
	visible = false
	position.y = _base_y

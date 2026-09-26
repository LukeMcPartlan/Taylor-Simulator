class_name DayNight
extends Node2D
## Day/night cycle tint for the world canvas. A full-screen ColorRect overlay
## follows the camera and tints the world by the GameState clock (6am-1am):
## warm dawn, clear day, orange sunset, cool night. The overlay lives in the
## default canvas, so the HUD (CanvasLayer 1) and minigames (CanvasLayer 100)
## always draw above it, crisp and untinted.
##
## Keyframes are (hour, overlay color); the tint smooth-blends between them
## so phases melt into each other instead of snapping.

# hour -> overlay ColorRect color. Alpha does the work: warm wash at dawn /
# sunset, cool dark wash at night, transparent midday.
const KEYFRAMES: Array = [
	[6.0, Color(1.0, 0.55, 0.25, 0.14)],   # 6am: dawn warmth
	[8.0, Color(0.0, 0.0, 0.0, 0.0)],      # 8am: clear day
	[18.0, Color(0.0, 0.0, 0.0, 0.0)],     # 6pm: still clear
	[19.5, Color(1.0, 0.45, 0.15, 0.18)],  # ~7:30pm: sunset peak
	[20.5, Color(0.08, 0.12, 0.35, 0.38)], # 8:30pm: night settles in
	[25.0, Color(0.05, 0.08, 0.28, 0.45)],  # 1am: late night, deepest
]

var _rect: ColorRect


static func tint_for_hour(h: float) -> Color:
	## Overlay color for a clock hour. Smooth-blends between keyframes.
	var frames: Array = KEYFRAMES
	if h <= float(frames[0][0]):
		return frames[0][1]
	for i in range(frames.size() - 1):
		var h0: float = frames[i][0]
		var h1: float = frames[i + 1][0]
		if h >= h0 and h <= h1:
			var t: float = (h - h0) / maxf(h1 - h0, 0.001)
			t = t * t * (3.0 - 2.0 * t)  # smoothstep: melt, don't snap
			return (frames[i][1] as Color).lerp(frames[i + 1][1] as Color, t)
	return frames[frames.size() - 1][1]


static func phase_icon_for_hour(h: float) -> String:
	## Readability aid: one glanceable icon per phase for the HUD clock.
	if h < 8.0:
		return "🌅"
	if h < 18.0:
		return "☀️"
	if h < 20.0:
		return "🌇"
	return "🌙"


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.z_index = 4096  # above all world sprites, below every CanvasLayer
	add_child(_rect)


func _process(_delta: float) -> void:
	if _rect == null:
		return
	# Cover the camera view (handles zoom); fall back to the viewport rect.
	var view_size := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		view_size = view_size / cam.zoom
		_rect.global_position = cam.get_screen_center_position() - view_size * 0.5
	else:
		_rect.global_position = Vector2.ZERO
	_rect.size = view_size
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		_rect.color = DayNight.tint_for_hour(float(gs.get("time_hours")))

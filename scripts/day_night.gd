class_name DayNight
extends Node2D
## Day/night cycle tint for the world canvas. A full-screen ColorRect overlay
## follows the camera and tints the world by the GameState clock (6am-1am):
## dark purple at day start, warming by 7, sunrise colors to 9, clear midday,
## sunset warmth to 8pm, purple to 10pm, very dark to 1am. The overlay lives
## in the default canvas, so the HUD (CanvasLayer 1) and minigames
## (CanvasLayer 100) always draw above it, crisp and untinted.
##
## Keyframes are (hour, overlay color); the tint smooth-blends between them
## so phases melt into each other instead of snapping.
##
## INSPECTOR TEST CONTROLS: select the DayNight node (World/DayNight, or in
## the Remote scene tree while playing) and open "Inspector test controls":
## turn on "preview time", drag the hour slider, and tweak the phase colors
## live. When you like a look, copy the color values into KEYFRAMES below.

@export_group("Inspector test controls")
@export var preview_time := false
@export_range(6.0, 25.0, 0.1, "suffix:h") var preview_hour := 12.0
@export var preview_predawn := Color(0.30, 0.08, 0.45, 0.50)
@export var preview_warm := Color(0.85, 0.50, 0.25, 0.30)
@export var preview_sunrise := Color(1.00, 0.60, 0.35, 0.25)
@export var preview_midday := Color(0.0, 0.0, 0.0, 0.0)
@export var preview_evening := Color(0.0, 0.0, 0.0, 0.0)
@export var preview_sunset := Color(1.00, 0.45, 0.20, 0.35)
@export var preview_night := Color(0.28, 0.08, 0.48, 0.50)
@export var preview_late := Color(0.02, 0.02, 0.10, 0.65)

# hour -> overlay ColorRect color. Alpha does the work: dark purple at day
# start, warming by 7, sunrise colors to 9, clear midday, sunset warmth to
# 8pm, purple to 10pm, very dark to 1am.
const KEYFRAMES: Array = [
	[6.0, Color(0.30, 0.08, 0.45, 0.50)],   # 6am: dark purple pre-dawn
	[7.0, Color(0.85, 0.50, 0.25, 0.30)],   # 7am: warm
	[8.0, Color(1.00, 0.60, 0.35, 0.25)],   # 8am: sunrise colors
	[9.0, Color(0.0, 0.0, 0.0, 0.0)],       # 9am: clear
	[18.0, Color(0.0, 0.0, 0.0, 0.0)],      # 6pm: still clear
	[20.0, Color(1.00, 0.45, 0.20, 0.35)],  # 8pm: sunset warm peak
	[22.0, Color(0.28, 0.08, 0.48, 0.50)],  # 10pm: purple
	[25.0, Color(0.02, 0.02, 0.10, 0.65)],  # 1am: very dark
]

var _rect: ColorRect


static func tint_for_hour(h: float) -> Color:
	## Overlay color for a clock hour. Smooth-blends between keyframes.
	return _blend(KEYFRAMES, h)


static func _blend(frames: Array, h: float) -> Color:
	## Smooth-blend helper shared by the shipped keyframes and the
	## inspector preview colors.
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


func _preview_frames() -> Array:
	return [
		[6.0, preview_predawn],
		[7.0, preview_warm],
		[8.0, preview_sunrise],
		[9.0, preview_midday],
		[18.0, preview_evening],
		[20.0, preview_sunset],
		[22.0, preview_night],
		[25.0, preview_late],
	]


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
	if preview_time:
		_rect.color = DayNight._blend(_preview_frames(), preview_hour)
	elif gs != null:
		_rect.color = DayNight.tint_for_hour(float(gs.get("time_hours")))

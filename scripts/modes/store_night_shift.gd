extends StoreLaptop
## Taylor's LAPTOP in Night-Shift mode: the same laptop hardware as every
## mode, but Night Shift's AMAZON tab sells the full 9-item shared catalog.
## (WORK tab — deranged employee emails — is identical in all modes.)


func _store_mode_id() -> int:
	return ModeManager.Mode.NIGHT_SHIFT

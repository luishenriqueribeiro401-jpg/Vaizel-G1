extends Node3D
## Composição das cenas: UI se comunica com o jogador por sinais.

@onready var player: PlayerController = $Player
@onready var mobile: MobileControls = $MobileControls/Overlay
@onready var debug_hud: DebugHUD = $DebugHUD


func _ready() -> void:
    mobile.direction_changed.connect(player.set_touch_direction)
    mobile.look_delta.connect(player.add_touch_look)
    mobile.jump_requested.connect(player.request_jump)
    mobile.touch_controls_activated.connect(player.enable_touch_mode)
    debug_hud.bind_player(player)

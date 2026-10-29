class_name DebugHUD
extends CanvasLayer
## Amostragem a 5 Hz; evita refazer textos em cada frame.

@export var show_on_start: bool = true
@onready var metrics: Label = $Panel/Metrics
@onready var refresh: Timer = $RefreshTimer
var _player: CharacterBody3D


func _ready() -> void:
    visible = show_on_start
    refresh.timeout.connect(_update_metrics)
    refresh.start()


func bind_player(player: CharacterBody3D) -> void:
    _player = player
    _update_metrics()


func _update_metrics() -> void:
    if not visible or not is_instance_valid(_player):
        return
    var p: Vector3 = _player.global_position
    var horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
    metrics.text = "X: %7.2f   Y: %7.2f   Z: %7.2f\nFPS: %d   Vel.: %.2f m/s\nNo chão: %s" % [
        p.x, p.y, p.z, int(Engine.get_frames_per_second()), horizontal_speed,
        "SIM" if _player.is_on_floor() else "NÃO"
    ]

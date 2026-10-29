class_name MobileControls
extends Control
## Camada touch independente do jogador: multitouch via índices de dedos.
signal look_delta(delta_pixels: Vector2)
signal jump_requested
signal direction_changed(direction: Vector2)
signal touch_controls_activated

@export_range(0.18, 0.40, 0.01) var joystick_height_ratio: float = 0.27
@export_range(0.15, 0.35, 0.01) var jump_height_ratio: float = 0.21
@export_range(8.0, 60.0, 1.0) var edge_margin: float = 24.0

@onready var joystick: SandboxVirtualJoystick = $Joystick
@onready var jump_anchor: Control = $JumpAnchor
var _camera_finger: int = -1
var _jump_finger: int = -1
var _jump_center: Vector2 = Vector2.ZERO
var _jump_radius: float = 50.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = OS.has_feature("mobile") or OS.get_name() == "Android"
    joystick.direction_changed.connect(_relay_direction)
    resized.connect(_update_layout)
    _update_layout()


func _update_layout() -> void:
    var bounds: Vector2 = size
    if bounds.x <= 0.0 or bounds.y <= 0.0:
        return
    var short_side: float = minf(bounds.x, bounds.y)
    var margin: float = minf(edge_margin, short_side * 0.045)
    var joystick_diameter: float = clampf(short_side * joystick_height_ratio, 90.0, 210.0)
    var jump_diameter: float = clampf(short_side * jump_height_ratio, 74.0, 158.0)
    joystick.size = Vector2.ONE * joystick_diameter
    joystick.position = Vector2(margin, bounds.y - margin - joystick_diameter)
    jump_anchor.size = Vector2.ONE * jump_diameter
    jump_anchor.position = bounds - Vector2.ONE * (margin + jump_diameter)
    _jump_radius = jump_diameter * 0.5
    _jump_center = jump_anchor.position + jump_anchor.size * 0.5
    joystick.queue_redraw()
    queue_redraw()


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        if touch.pressed and not visible:
            visible = true
            touch_controls_activated.emit()
        if not visible:
            return
        if touch.pressed:
            _begin_touch(touch.index, touch.position)
        else:
            _end_touch(touch.index)
    elif event is InputEventScreenDrag and visible:
        var drag: InputEventScreenDrag = event
        if drag.index == joystick.finger_index:
            joystick.move_finger(drag.position)
        elif drag.index == _camera_finger:
            look_delta.emit(drag.relative)
        # O botão de pulo permanece ocupado até o dedo sair da tela.


func _begin_touch(index: int, point: Vector2) -> void:
    if index == _camera_finger or index == _jump_finger or index == joystick.finger_index:
        return
    if _jump_finger < 0 and point.distance_to(_jump_center) <= _jump_radius * 1.18:
        _jump_finger = index
        jump_requested.emit()
        queue_redraw()
        return
    if point.x < size.x * 0.5 and joystick.try_begin(index, point):
        return
    if _camera_finger < 0 and point.x >= size.x * 0.5:
        _camera_finger = index


func _end_touch(index: int) -> void:
    if index == joystick.finger_index:
        joystick.end_finger(index)
    elif index == _camera_finger:
        _camera_finger = -1
    elif index == _jump_finger:
        _jump_finger = -1
        queue_redraw()


func _relay_direction(direction: Vector2) -> void:
    direction_changed.emit(direction)


func _draw() -> void:
    if not visible:
        return
    var opacity: float = 0.59 if _jump_finger >= 0 else 0.32
    draw_circle(_jump_center, _jump_radius, Color(0.07, 0.10, 0.14, opacity))
    draw_arc(_jump_center, _jump_radius - 1.5, 0.0, TAU, 64, Color(0.94, 0.96, 1.0, 0.75), 2.5, true)
    var font: Font = ThemeDB.fallback_font
    var font_size: int = maxi(13, int(_jump_radius * 0.37))
    var label: String = "PULAR"
    var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_string(font, _jump_center + Vector2(-text_size.x * 0.5, text_size.y * 0.30), label,
        HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.90))

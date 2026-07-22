extends Control

var arcade_mode := false
var intensity := 0.0
var phase := 0.0
var accent := Color("f2a93b")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_arcade_mode(enabled: bool) -> void:
    arcade_mode = enabled

func set_accent(next_accent: Color) -> void:
    accent = next_accent

func _process(delta: float) -> void:
    phase += delta
    intensity = move_toward(intensity, 1.0 if arcade_mode else 0.0, delta * 2.4)
    if arcade_mode or intensity > 0.01:
        queue_redraw()

func _draw() -> void:
    if intensity <= 0.01:
        return
    var viewport := size
    var center := Vector2(viewport.x * 0.5, viewport.y * 0.56)
    var horizon := viewport.y * 0.77
    var glow := Color(accent.r, accent.g, accent.b, 0.20 * intensity)
    var faint := Color(accent.r, accent.g, accent.b, 0.065 * intensity)
    var cyan := Color(0.18, 0.88, 1.0, 0.13 * intensity)
    for row in range(9):
        var progress := float(row) / 8.0
        var y := lerpf(horizon, viewport.y + 80.0, progress * progress)
        draw_line(Vector2(0, y), Vector2(viewport.x, y), faint, 2.0)
    for line in range(-9, 10):
        var bottom_x := center.x + float(line) * viewport.x * 0.12
        draw_line(Vector2(center.x, horizon), Vector2(bottom_x, viewport.y + 40.0), cyan if line % 2 == 0 else faint, 2.0)
    for ring in range(3):
        var radius := 332.0 + float(ring) * 45.0 + sin(phase * 1.35 + float(ring)) * 5.0
        var start := phase * (0.55 + float(ring) * 0.12) + float(ring) * 2.0
        draw_arc(center, radius, start, start + 1.7, 56, glow, 3.0, true)
        draw_arc(center, radius, start + PI, start + PI + 1.15, 44, faint, 2.0, true)
    for spark in range(18):
        var x := fposmod(float(spark * 173) + phase * (22.0 + float(spark % 4) * 9.0), viewport.x)
        var y := 105.0 + fposmod(float(spark * 83) + sin(phase + spark) * 45.0, viewport.y * 0.64)
        var radius := 1.2 + float(spark % 3) * 0.65
        draw_circle(Vector2(x, y), radius, Color(0.95, 0.35, 0.90, 0.42 * intensity))

extends Node2D

const CELL_SIZE := 16
const GRID_WIDTH := 20
const GRID_HEIGHT := 12
const INITIAL_LENGTH := 3
const MOVE_INTERVAL := 0.12

const SNAKE_COLOR := Color(0.2, 0.8, 0.3)
const HEAD_COLOR := Color(0.3, 0.9, 0.4)
const FOOD_COLOR := Color(0.9, 0.2, 0.2)
const BG_COLOR := Color(0.1, 0.1, 0.12)
const BG_COLOR_ALT := Color(0.14, 0.14, 0.17)
const OUTLINE_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_WIDTH := 1.0

const FOOD_SCORE := 1
const FOOD_GROWTH := 1

const BONUS_CHANCE := 0.2
const BONUS_COLOR := Color(0.909, 0.8, 0.186, 1.0)
const BONUS_SCORE := 2
const BONUS_GROWTH := 2

const SPARK_COUNT := 10
const SPARK_LIFETIME := 0.35
const SPARK_SPEED_MIN := 40.0
const SPARK_SPEED_MAX := 90.0
const SPARK_COLOR := Color(1.0, 0.85, 0.2)
const BONUS_SPARK_COLOR := Color(0.3, 1.0, 0.4)
const POPUP_SIZE := Vector2(32.0, 12.0)

const BOMB_COUNT := 4
const BOMB_COLOR := Color(0.1, 0.1, 0.12)
const BOMB_HIGHLIGHT_COLOR := Color(0.4, 0.4, 0.45)
const BOMB_FUSE_COLOR := Color(0.85, 0.55, 0.15)

const EXPLOSION_SPARK_COUNT := 28
const EXPLOSION_SPARK_LIFETIME := 0.5
const EXPLOSION_SPARK_SPEED_MIN := 60.0
const EXPLOSION_SPARK_SPEED_MAX := 160.0
const EXPLOSION_COLORS := [Color(1.0, 0.85, 0.2), Color(1.0, 0.45, 0.1), Color(0.85, 0.15, 0.05)]

@onready var move_timer: Timer = $MoveTimer
@onready var score_label: Label = $ScoreLabel
@onready var game_over_menu: Control = $GameOverMenu
@onready var restart_button: Button = $GameOverMenu/CenterBox/MenuBox/RestartButton
@onready var exit_button: Button = $GameOverMenu/CenterBox/MenuBox/ExitButton
@onready var popup_label: Label = $PopupLabel

var body: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var next_direction := Vector2i.RIGHT
var food_pos := Vector2i.ZERO
var food_is_bonus := false
var bombs: Array[Vector2i] = []
var score := 0
var game_over := false
var sparks: Array[Dictionary] = []

func _ready() -> void:
	move_timer.wait_time = MOVE_INTERVAL
	move_timer.timeout.connect(_on_move_timer_timeout)
	restart_button.pressed.connect(_reset)
	exit_button.pressed.connect(_on_exit_pressed)
	popup_label.size = POPUP_SIZE
	_reset()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _process(delta: float) -> void:
	if sparks.is_empty():
		return
	for spark in sparks:
		spark.pos += spark.vel * delta
		spark.life -= delta
	sparks = sparks.filter(func(s): return s.life > 0.0)
	queue_redraw()

func _reset() -> void:
	game_over = false
	game_over_menu.hide()
	score = 0
	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT

	@warning_ignore("integer_division")
	var start_x := GRID_WIDTH / 2
	@warning_ignore("integer_division")
	var start_y := GRID_HEIGHT / 2
	body.clear()
	for i in range(INITIAL_LENGTH):
		body.append(Vector2i(start_x - i, start_y))

	_place_food()
	_place_bombs()
	_update_score_label()
	sparks.clear()
	popup_label.hide()
	score_label.scale = Vector2.ONE
	move_timer.start()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return

	var desired := Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		desired = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		desired = Vector2i.DOWN
	elif event.is_action_pressed("ui_left"):
		desired = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		desired = Vector2i.RIGHT
	else:
		return

	# Buffer the turn; ignore direct reversals so the snake can't run into its own neck.
	if desired != -direction:
		next_direction = desired

func _on_move_timer_timeout() -> void:
	if game_over:
		return

	direction = next_direction
	var new_head: Vector2i = body[0] + direction

	if new_head.x < 0 or new_head.x >= GRID_WIDTH or new_head.y < 0 or new_head.y >= GRID_HEIGHT:
		_game_over()
		return

	if bombs.has(new_head):
		body.insert(0, new_head)
		_explode(new_head)
		return

	var ate_food := new_head == food_pos
	# The tail cell vacates this tick unless the snake is growing, so it's a legal move target.
	var body_to_check := body if ate_food else body.slice(0, body.size() - 1)
	if body_to_check.has(new_head):
		_game_over()
		return

	body.insert(0, new_head)
	if ate_food:
		var points := BONUS_SCORE if food_is_bonus else FOOD_SCORE
		var growth := BONUS_GROWTH if food_is_bonus else FOOD_GROWTH
		score += points
		_update_score_label()
		_spawn_pickup_feedback(new_head, points, food_is_bonus)
		for i in range(growth - 1):
			body.append(body[body.size() - 1])
		_place_food()
	else:
		body.remove_at(body.size() - 1)

	queue_redraw()

func _game_over() -> void:
	game_over = true
	move_timer.stop()
	game_over_menu.show()
	restart_button.grab_focus()

func _explode(cell: Vector2i) -> void:
	var center := Vector2(cell) * CELL_SIZE + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	for i in range(EXPLOSION_SPARK_COUNT):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(EXPLOSION_SPARK_SPEED_MIN, EXPLOSION_SPARK_SPEED_MAX)
		var life := EXPLOSION_SPARK_LIFETIME * randf_range(0.6, 1.0)
		sparks.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": life,
			"max_life": life,
			"color": EXPLOSION_COLORS[randi() % EXPLOSION_COLORS.size()],
		})
	queue_redraw()
	_game_over()

func _place_food() -> void:
	var free_cells: Array[Vector2i] = []
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell := Vector2i(x, y)
			if not body.has(cell) and not bombs.has(cell):
				free_cells.append(cell)
	if free_cells.is_empty():
		_game_over()
		return
	food_pos = free_cells[randi() % free_cells.size()]
	food_is_bonus = randf() < BONUS_CHANCE

func _place_bombs() -> void:
	bombs.clear()
	for i in range(BOMB_COUNT):
		var free_cells: Array[Vector2i] = []
		for x in range(GRID_WIDTH):
			for y in range(GRID_HEIGHT):
				var cell := Vector2i(x, y)
				if not body.has(cell) and cell != food_pos and not bombs.has(cell):
					free_cells.append(cell)
		if free_cells.is_empty():
			return
		bombs.append(free_cells[randi() % free_cells.size()])

func _update_score_label() -> void:
	score_label.text = "Score: %d   Length: %d" % [score, body.size()]

func _spawn_pickup_feedback(cell: Vector2i, points: int, bonus: bool) -> void:
	var center := Vector2(cell) * CELL_SIZE + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	var spark_color := BONUS_SPARK_COLOR if bonus else SPARK_COLOR

	for i in range(SPARK_COUNT):
		var angle := (TAU / SPARK_COUNT) * i + randf_range(-0.25, 0.25)
		var speed := randf_range(SPARK_SPEED_MIN, SPARK_SPEED_MAX)
		sparks.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": SPARK_LIFETIME,
			"max_life": SPARK_LIFETIME,
			"color": spark_color,
		})

	popup_label.text = "+%d" % points
	popup_label.add_theme_color_override("font_color", BONUS_COLOR if bonus else Color(1, 0.85, 0.2))
	popup_label.position = center - POPUP_SIZE * 0.5 - Vector2(0.0, CELL_SIZE * 0.5)
	popup_label.modulate = Color(1, 1, 1, 1)
	popup_label.show()
	var popup_tween := create_tween()
	popup_tween.tween_property(popup_label, "position:y", popup_label.position.y - 12.0, 0.45)
	popup_tween.parallel().tween_property(popup_label, "modulate:a", 0.0, 0.3).set_delay(0.15)
	popup_tween.tween_callback(popup_label.hide)

	score_label.scale = Vector2(1.35, 1.35)
	var score_tween := create_tween()
	score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	queue_redraw()

# A stroke centered exactly on a rect drawn at the canvas origin gets half its width
# clipped off-screen on the top/left, while the bottom/right edges stay fully visible.
# Insetting the stroke rect by half the width keeps it entirely on-screen on all sides.
func _draw_outlined_rect(rect: Rect2) -> void:
	var inset := OUTLINE_WIDTH * 0.5
	var outline_rect := Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(OUTLINE_WIDTH, OUTLINE_WIDTH))
	draw_rect(outline_rect, OUTLINE_COLOR, false, OUTLINE_WIDTH)

func _draw() -> void:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell_color := BG_COLOR if (x + y) % 2 == 0 else BG_COLOR_ALT
			draw_rect(Rect2(Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), cell_color)
	var board_rect := Rect2(Vector2.ZERO, Vector2(GRID_WIDTH, GRID_HEIGHT) * CELL_SIZE)
	_draw_outlined_rect(board_rect)

	var food_color := BONUS_COLOR if food_is_bonus else FOOD_COLOR
	var food_rect := Rect2(Vector2(food_pos) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
	draw_rect(food_rect, food_color)
	_draw_outlined_rect(food_rect)

	for bomb in bombs:
		var center := Vector2(bomb) * CELL_SIZE + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
		var radius := CELL_SIZE * 0.35
		draw_line(center, center + Vector2(3.0, -CELL_SIZE * 0.4), BOMB_FUSE_COLOR, 1.5)
		draw_circle(center, radius, BOMB_COLOR)
		draw_circle(center - Vector2(2.0, 2.0), CELL_SIZE * 0.1, BOMB_HIGHLIGHT_COLOR)
		draw_circle(center, radius - OUTLINE_WIDTH * 0.5, OUTLINE_COLOR, false, OUTLINE_WIDTH)

	for i in range(body.size()):
		var color := HEAD_COLOR if i == 0 else SNAKE_COLOR
		var seg_rect := Rect2(Vector2(body[i]) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(seg_rect, color)
		_draw_outlined_rect(seg_rect)

	for spark in sparks:
		var t: float = spark.life / spark.max_life
		var color: Color = spark.color
		color.a = t
		draw_rect(Rect2(spark.pos - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), color)

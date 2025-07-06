extends Sprite2D
class_name Piece

const MOVE_TIME = 0.15
enum {
	PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING
}
@onready var game := get_node("../..")
@onready var TILE_SIZE = Global.TILE_SIZE
var team := "white"
var piece_value: int
var last_move_round: int
var piece_id := PAWN: 
	set = set_id
var pos: Vector2i 

func _ready():
	if team == "black":
		texture = preload("res://assets/black.png")
	position = pos * TILE_SIZE

func set_id(id):
	frame = id
	piece_value = [1, 3, 3, 5, 9, 0][id]
	piece_id = id

func move_animation(new_pos: Vector2i):
	var new_position: Vector2 = new_pos * TILE_SIZE
	z_index += 1
	await create_tween() \
		.tween_property(self, "position", new_position, MOVE_TIME) \
		.set_ease(Tween.EASE_IN_OUT).finished
	z_index -= 1

func get_moves(board: Array) -> Dictionary:
	match piece_id:
		PAWN: return Moves.pawn(pos, board, game.round_num)
		KNIGHT: return Moves.basic(pos, board, Moves.L_SHAPE)
		BISHOP: return Moves.line(pos, board, Moves.DIAGONAL)
		ROOK: return Moves.line(pos, board, Moves.ORTHOGONAL)
		QUEEN: return Moves.line(pos, board, Moves.OCTO)
		KING: return Moves.king(pos, board)
	return {}

func promote_menu(new_pos: Vector2i):
	var menu := $Promotion
	var vbox := $Promotion/VBoxContainer
	var options := ButtonGroup.new()
	for i in [4,1,3,2]:
		var piece_texture := AtlasTexture.new()
		piece_texture.atlas = texture
		piece_texture.region.position = Vector2(TILE_SIZE * i, 0)
		piece_texture.region.size = Vector2.ONE * TILE_SIZE
		var option := Button.new()
		option.icon = piece_texture
		option.toggle_mode = true
		option.button_group = options
		option.set_meta("id", i)
		vbox.add_child(option)
	
	if team == "white":
		menu.position.x = new_pos.x * TILE_SIZE
	else:
		menu.position.x = (7 - new_pos.x) * TILE_SIZE
	if new_pos.x == 7:
		menu.position.x -= TILE_SIZE * 0.5
	
	menu.show()
	await options.pressed
	menu.hide()
	piece_id = options.get_pressed_button().get_meta("id")
	for option in options.get_buttons():
		option.queue_free()

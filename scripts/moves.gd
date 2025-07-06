class_name Moves

enum {MOVE, CAPTURE, CASTLE}

const ORTHOGONAL = [[1, 0], [-1, 0], [0, 1], [0, -1]]
const DIAGONAL = [[1, 1], [-1, -1], [-1, 1], [1, -1]]
const OCTO = ORTHOGONAL + DIAGONAL

const L_SHAPE = [[ 2,  1], [ 1,  2], [-1,  2], [-2,  1], 
				 [-2, -1], [-1, -2], [ 1, -2], [ 2, -1]]

static func not_in_range(x, y):
	return x < 0 or x > 7 or y < 0 or y > 7

static func new_move() -> Dictionary:
	return {"type": MOVE}

static func new_capture(take_piece) -> Dictionary:
	return {"type": CAPTURE, "take_piece": take_piece}

static func new_castle(side) -> Dictionary:
	return {"type": CASTLE, "side": side}

static func basic(pos: Vector2i, board: Array, directions: Array) -> Dictionary:
	var moves := {}

	if pos.y < 0 or pos.y >= board.size():
		return moves
	if pos.x < 0 or pos.x >= board[pos.y].size():
		return moves

	var piece = board[pos.y][pos.x]
	if piece == null:
		return moves

	var color = piece.team
	for dir in directions:
		var x = pos.x + dir[0]
		var y = pos.y + dir[1]
		if not_in_range(x, y):
			continue
		var tile = board[y][x]
		if tile == null:
			moves[Vector2i(x, y)] = new_move()
		elif color != tile.team:
			moves[Vector2i(x, y)] = new_capture(tile)
	return moves

static func line(pos: Vector2i, board: Array, directions: Array) -> Dictionary:
	var moves := {}

	if pos.y < 0 or pos.y >= board.size():
		return moves
	if pos.x < 0 or pos.x >= board[pos.y].size():
		return moves

	var piece = board[pos.y][pos.x]
	if piece == null:
		return moves

	var color = piece.team
	for dir in directions:
		for i in range(1, 9):
			var x = pos.x + (dir[0] * i)
			var y = pos.y + (dir[1] * i)
			if not_in_range(x, y):
				break
			var tile = board[y][x]
			if tile == null:
				moves[Vector2i(x, y)] = new_move()
				continue
			if color != tile.team:
				moves[Vector2i(x, y)] = new_capture(tile)
			break
	return moves

static func pawn(pos: Vector2i, board: Array, round_num: int) -> Dictionary:
	var moves := {}

	if pos.y < 0 or pos.y >= board.size():
		return moves
	if pos.x < 0 or pos.x >= board[pos.y].size():
		return moves

	var pawn_piece = board[pos.y][pos.x]
	if pawn_piece == null:
		return moves

	var pawn_color = pawn_piece.team
	var move_dir := 1 if pawn_color == "black" else -1
	var original_rank := 1 if pawn_color == "black" else 6

	var possible_moves := [Vector2i(0, move_dir)]
	if pos.y == original_rank:
		possible_moves.append(Vector2i(0, move_dir * 2))

	for move in possible_moves:
		var new_y = pos.y + move.y
		var new_x = pos.x + move.x
		if not_in_range(new_x, new_y):
			break
		if board[new_y][new_x] != null:
			break
		moves[pos + move] = new_move()

	for attack_dir in [-1, 1]:
		var x = pos.x + attack_dir
		var y = pos.y + move_dir
		if not_in_range(x, y):
			continue
		var target_tile = board[y][x]
		if target_tile == null:
			continue
		if pawn_color != target_tile.team:
			moves[Vector2i(x, y)] = new_capture(target_tile)

	var rank_before_promoting = 1 if pawn_color == "white" else 6
	if pos.y == rank_before_promoting:
		for move in moves:
			moves[move]["promote"] = true

	var cannot_en_passant = move_dir * 3 + original_rank != pos.y
	if cannot_en_passant:
		return moves

	for side in [-1, 1]:
		var side_x = pos.x + side
		if not_in_range(side_x, pos.y):
			continue
		var tile = board[pos.y][side_x]
		if tile == null or tile.team == pawn_color or tile.piece_id != Piece.PAWN:
			continue
		if tile.last_move_round == round_num - 1:
			moves[Vector2i(side_x, pos.y + move_dir)] = new_capture(tile)

	return moves

static func king(pos: Vector2i, board: Array) -> Dictionary:
	var moves := {}

	if pos.y < 0 or pos.y >= board.size():
		return moves
	if pos.x < 0 or pos.x >= board[pos.y].size():
		return moves

	var king_piece = board[pos.y][pos.x]
	if king_piece == null:
		return moves

	moves.merge(basic(pos, board, OCTO))

	if not king_piece.last_move_round:
		var can_castle := true
		var rook_pos := -1
		for piece in board[pos.y]:
			if piece == null:
				continue
			if piece.piece_id == Piece.KING:
				if can_castle and rook_pos == 0:
					moves[Vector2i(pos.x - 2, pos.y)] = new_castle("long")
				can_castle = true
			elif piece.piece_id == Piece.ROOK:
				if piece.last_move_round or piece.team != king_piece.team:
					can_castle = false
				rook_pos = piece.pos.x
			else:
				can_castle = false
		if can_castle and rook_pos == 7:
			moves[Vector2i(pos.x + 2, pos.y)] = new_castle("short")

	return moves

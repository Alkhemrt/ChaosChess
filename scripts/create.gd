class_name Create

const Piece = preload("res://scenes/chess_peice.tscn")

const DEFAULT_BOARD := [
	["R", "N", "B", "Q", "K", "B", "N", "R"],
	["P", "P", "P", "P", "P", "P", "P", "P"],
	["" , "" , "" , "" , "" , "" , "" , "" ],
	["" , "" , "" , "" , "" , "" , "" , "" ],
	["" , "" , "" , "" , "" , "" , "" , "" ],
	["" , "" , "" , "" , "" , "" , "" , "" ],
	["p", "p", "p", "p", "p", "p", "p", "p"],
	["r", "n", "b", "q", "k", "b", "n", "r"],
]

const CUSTOM_BOARD := [
	["", "", "", "", "", "", "", ""],
	["", "", "", "", "", "", "", ""],
	["", "", "", "", "", "", "", ""],
	["", "", "", "", "", "", "", ""],
	["", "", "", "", "", "", "", ""],
	["", "", "", "", "", "", "", ""],
	["", "", "", "", "", "", "", ""],
	["", "", "", "", "", "", "", ""],
]

enum Symbols {P, N, B, R, Q, K}

static func create_piece(symbol: String, pos: Vector2i) -> Piece:
	var color := "white" if symbol == symbol.to_lower() else "black"
	var piece := Piece.instantiate()
	piece.piece_id = Symbols[symbol.to_upper()]
	piece.team = color
	piece.pos = pos
	return piece

static func create_board(from_board: Array) -> Dictionary:
	var board := [[], [], [], [], [], [], [], []]
	var anchor_node := Node2D.new()
	for y in range(8):
		for x in range(8):
			if !from_board[y][x]:
				board[y].append(null)
				continue
		
			var piece = create_piece(from_board[y][x], Vector2i(x, y))
			board[y].append(piece)
			anchor_node.add_child(piece)
	
	return {"board": board, "node": anchor_node}

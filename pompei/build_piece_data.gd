class_name BuildPieceData
extends Resource

@export var display_name := "Piece"
@export var icon: Texture2D
@export var scene: PackedScene                 # the real piece that gets placed

# Box used to test "is something in the way?" (local space of the piece)
@export var footprint := Vector3(2.0, 2.0, 2.0)
@export var footprint_offset := Vector3(0.0, 1.05, 0.0)   # keep it a touch above the ground

@export var grid_size := 0.0                   # 0 = free placement, 2.0 = snap to 2m grid
@export var rotation_step_deg := 15.0
@export var snap_to_other_pieces := true       # use Marker3D "Snap*" points on pieces
@export var max_slope_deg := 35.0              # steeper ground than this is invalid

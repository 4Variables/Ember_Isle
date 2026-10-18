extends VBoxContainer

@export var spawner: NpcSpawner
@export var alert_row_scene: PackedScene
@export var panel: Control   # hidden while there are no alerts

var _rows := {}   # Npc -> AlertRow

func _ready() -> void:
	spawner.npc_spawned.connect(_on_npc_spawned)
	_update_panel()

func _on_npc_spawned(npc: Npc, _area: SpawnArea) -> void:
	npc.poison_alert_changed.connect(_on_poison_alert_changed)
	npc.tree_exiting.connect(_remove_row.bind(npc))

func _on_poison_alert_changed(npc: Npc, level: Npc.PoisonAlert) -> void:
	if level == Npc.PoisonAlert.NONE:
		_remove_row(npc)
		return
	var row: AlertRow = _rows.get(npc)
	if row == null:
		row = alert_row_scene.instantiate()
		add_child(row)
		_rows[npc] = row
	row.show_alert(npc.display_name, level == Npc.PoisonAlert.CRITICAL)
	_update_panel()

func _remove_row(npc: Npc) -> void:
	if _rows.has(npc):
		_rows[npc].queue_free()
		_rows.erase(npc)
		_update_panel()

func _update_panel() -> void:
	var has_alerts := not _rows.is_empty()
	if has_alerts and not panel.visible:
		panel.modulate.a = 0.0
		panel.visible = true
		create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)
	elif not has_alerts:
		panel.visible = false

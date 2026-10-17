extends StaticBody3D
class_name ClearableObstacle

signal cleared(obstacle: ClearableObstacle)

@export var work_required: float = 1.0
@export var interact_prompt: String = "Clear fallen tree"

var work_done := 0.0

func add_work(amount: float) -> void:
	if work_done >= work_required:
		return
	work_done += amount
	if work_done >= work_required:
		clear()

func clear() -> void:
	var region := get_parent()
	while region != null and not region is NavigationRegion3D:
		region = region.get_parent()

	# Remove before baking so the parser no longer sees this collider.
	get_parent().remove_child(self)
	if region != null:
		rebake(region)
	else:
		push_warning("%s is not under a NavigationRegion3D; the navmesh won't update." % name)
	cleared.emit(self)
	queue_free()

static func rebake(region: NavigationRegion3D) -> void:
	# A region can only run one bake at a time; queue another one for when it finishes.
	if region.is_baking():
		if not region.bake_finished.is_connected(region.bake_navigation_mesh):
			region.bake_finished.connect(region.bake_navigation_mesh, CONNECT_ONE_SHOT)
	else:
		region.bake_navigation_mesh()

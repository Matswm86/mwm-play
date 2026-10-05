class_name TvForkliftModel
extends TvCharacterModel

## The Maple Highlands forklift (ASSETS_M2.md 1.3): a static model with no skeleton that stands in
## for a character. Forks face +Z like a character's front; it bobs a little while driving.

var _body: Node3D
var _t: float = 0.0


func setup_forklift(key: String = "forklift") -> TvForkliftModel:
	_body = TvModels.make(key)
	add_child(_body)
	for mi in _body.find_children("*", "MeshInstance3D", true, false):
		TvShadowCull.track(mi as GeometryInstance3D)
	return self


func set_axe_model(_upgraded: bool) -> void:
	pass


func update_state(move_speed: float, _carrying: bool, _chopping: bool) -> void:
	_t += get_process_delta_time()
	_body.position.y = sin(_t * 12.0) * 0.01 if move_speed > 0.1 else 0.0

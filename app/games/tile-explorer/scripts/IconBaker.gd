extends Node
class_name TeIconBaker

# Bakes the procedural 2D icon art (Icons.gd) into ImageTextures so the 3D
# tiles can show it on their top faces. Runs once at startup, then all
# SubViewports are freed. Keeps the no-external-assets ethos.

const BAKE_SIZE: int = 256
# Icons are authored for r=48 with absolute stroke widths; draw them at that
# radius under a uniform canvas scale so strokes scale proportionally. Art
# overflows r by up to 1.17x (cat ears), hence the 56 px half-extent.
const ICON_DRAW_RADIUS: float = 48.0
const ART_HALF_EXTENT: float = 56.0


class IconCanvas:
	extends Node2D
	var icon_id: int = 0

	func _draw() -> void:
		var s: float = float(BAKE_SIZE) * 0.5 / ART_HALF_EXTENT
		draw_set_transform(Vector2(BAKE_SIZE * 0.5, BAKE_SIZE * 0.5), 0.0, Vector2(s, s))
		TeIcons.draw_icon(self, icon_id, ICON_DRAW_RADIUS)


class SlotCanvas:
	extends Node2D

	func _draw() -> void:
		var rect := Rect2(10, 10, BAKE_SIZE - 20, BAKE_SIZE - 20)
		TeDrawing.draw_rounded_rect(self, rect, 46, Color(0.18, 0.09, 0.03, 0.45))


# Single rounded-square texture for the tray slot markers.
static func bake_slot(host: Node) -> ImageTexture:
	var vp := SubViewport.new()
	vp.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(SlotCanvas.new())
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.generate_mipmaps()
	vp.queue_free()
	return ImageTexture.create_from_image(img)


# Returns Array[ImageTexture], one per icon id, mipmapped.
static func bake_icons(host: Node) -> Array:
	var viewports: Array = []
	for id in TeIcons.count():
		var vp := SubViewport.new()
		vp.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var canvas := IconCanvas.new()
		canvas.icon_id = id
		vp.add_child(canvas)
		host.add_child(vp)
		viewports.append(vp)
	# Two frames so every UPDATE_ONCE target is guaranteed flushed.
	await RenderingServer.frame_post_draw
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var textures: Array = []
	for vp in viewports:
		var img: Image = vp.get_texture().get_image()
		img.generate_mipmaps()
		textures.append(ImageTexture.create_from_image(img))
		vp.queue_free()
	return textures

class_name SpriteSheet
extends RefCounted
## Monta um SpriteFrames a partir de um spritesheet em grade, por código.
##
## anims = { "nome": [linha, qtd_frames, fps, loop], ... }

static func build_frames(texture: Texture2D, frame_size: int, anims: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	for anim_name: String in anims:
		var cfg: Array = anims[anim_name]
		var row: int = cfg[0]
		var count: int = cfg[1]
		var fps: float = cfg[2]
		var loop: bool = cfg[3]

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, loop)
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * frame_size, row * frame_size, frame_size, frame_size)
			frames.add_frame(anim_name, atlas)
	return frames

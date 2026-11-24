shader_type canvas_item;

// Colour the flash blends towards.
uniform vec4 flash_color : source_color = vec4(1.0);
// 1.0 at the moment of impact, fading to 0.0.
uniform float hit_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, hit_amount);
}

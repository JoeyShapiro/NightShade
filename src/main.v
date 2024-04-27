module main

import time

// Example shader triangle adapted to V from https://github.com/floooh/sokol-samples/blob/1f2ad36/sapp/triangle-sapp.c
import sokol.sapp
import sokol.gfx
import sokol.sgl
import fontstash
import sokol.sfons
import os

// Use `v shader` or `sokol-shdc` to generate the necessary `.h` file
// Using `v shader -v .` in this directory will show some additional
// info - and what you should include to make things work.
#include "@VMODROOT/simple_shader.h" # # It should be generated with `v shader .`

// simple_shader_desc is a C function declaration defined by
// the `@program` entry in the `simple_shader.glsl` shader file.
// When the shader is compiled this function name is generated
// by the shader compiler for easier inclusion of universal shader code
// in C (and V) code.
fn C.simple_shader_desc(gfx.Backend) &gfx.ShaderDesc

// Vertex_t makes it possible to model vertex buffer data
// for use with the shader system
struct Vertex_t {
	// Position
	x f32
	y f32
	z f32
	// Color
	r f32
	g f32
	b f32
	a f32
}

struct AppState {
mut:
	pass_action  gfx.PassAction
	font_context &fontstash.Context
	font_normal  int
	
	pixels []f32
	start_epoch time.StopWatch
	fps f32
	tps f32
	last_frame_time i64
	last_tick_time i64
	max_fps f32
	min_fps f32
}

fn main() {
	mut pixels := []f32{}
	density := 20
	for x in 30 .. 100 {
		if x % density == 0 {
			continue
		}
		for y in 30 .. 100 {
			if y % density == 0 {
				continue
			}
			pixels << f32(x + density)
			pixels << f32(y + density)
		}
	}
	stop_watch := time.new_stopwatch()
	mut state := &AppState{
		pixels: pixels
		start_epoch: stop_watch
		last_frame_time: stop_watch.elapsed().milliseconds()
		last_tick_time: stop_watch.elapsed().milliseconds()
		min_fps: 999999999.0

		pass_action: gfx.create_clear_pass_action(0.3, 0.3, 0.32, 1.0)
		font_context: unsafe { nil } // &fontstash.Context(0)
	}

	title := 'Night Shade'
	desc := sapp.Desc{
		user_data: state
		init_userdata_cb: init
		frame_userdata_cb: frame
		window_title: title.str
		html5_canvas_name: title.str
	}
	sapp.run(&desc)
}

fn init(mut state AppState) {
	desc := sapp.create_desc()
	gfx.setup(&desc)
	s := &sgl.Desc{}
	sgl.setup(s)
	state.font_context = sfons.create(512, 512, 1)
	// or use DroidSerif-Regular.ttf
	if bytes := os.read_bytes(os.resource_abs_path(os.join_path('RobotoMono-Regular.ttf')))
	{
		println('loaded font: ${bytes.len}')
		state.font_normal = state.font_context.add_font_mem('sans', bytes, false)
	} else {
		println("failed to load font at ${os.resource_abs_path(os.join_path('..', 'assets', 'fonts', 'RobotoMono-Regular.ttf'))}")
	}
}

fn frame(mut state AppState) {
	now := state.start_epoch.elapsed().milliseconds()

	state.tps = 1000.0 / f32(now - state.last_tick_time)
	state.fps = 1000.0 / f32(now - state.last_frame_time)
	state.last_tick_time = now

	if now - state.last_frame_time < 1000 / 120 {
		return
	}
	state.last_frame_time = now

	if state.fps > state.max_fps {
		state.max_fps = state.fps
	}
	if state.fps < state.min_fps {
		state.min_fps = state.fps
	}

	state.render_font()
	pass := sapp.create_default_pass(state.pass_action)
	gfx.begin_pass(&pass)
	sgl.draw()
	gfx.end_pass()
	gfx.commit()
}

fn (state &AppState) render_font() {
	mut sx := f32(0.0)
	mut sy := f32(0.0)
	mut dx := f32(0.0)
	mut dy := f32(0.0)
	lh := f32(0.0)
	white := sfons.rgba(255, 255, 255, 255)
	black := sfons.rgba(0, 0, 0, 255)
	brown := sfons.rgba(192, 128, 0, 128)
	blue := sfons.rgba(0, 192, 255, 255)

	font_context := state.font_context
	font_context.clear_state()
	sgl.defaults()
	sgl.matrix_mode_projection()
	sgl.ortho(0.0, f32(sapp.width()), f32(sapp.height()), 0.0, -1.0, 1.0)
	sx = 0
	sy = 50
	dx = sx
	dy = sy
	font_context.set_font(state.font_normal)
	font_context.set_size(100.0)
	ascender := f32(0.0)
	descender := f32(0.0)
	font_context.vert_metrics(&ascender, &descender, &lh)
	dx = sx
	dy += lh
	font_context.set_color(white)
	dx = font_context.draw_text(dx, dy, 'The quick ')
	font_context.set_font(state.font_normal)
	font_context.set_size(48.0)
	font_context.set_color(brown)
	dx = font_context.draw_text(dx, dy, 'brown ')
	font_context.set_font(state.font_normal)
	font_context.set_size(24.0)
	font_context.set_color(white)
	dx = font_context.draw_text(dx, dy, 'fox ')
	dx = sx
	dy += lh * 1.2
	font_context.set_size(20.0)
	font_context.set_font(state.font_normal)
	font_context.set_color(blue)
	font_context.draw_text(dx, dy, 'Now is the time for all good men to come to the aid of the party.')
	dx = 300
	dy = 350
	font_context.set_alignment(.left | .baseline)
	font_context.set_size(60.0)
	font_context.set_font(state.font_normal)
	font_context.set_color(white)
	font_context.set_spacing(5.0)
	font_context.set_blur(6.0)
	font_context.draw_text(dx, dy, 'Blurry...')
	dx = 300
	dy += 50.0
	font_context.set_size(28.0)
	font_context.set_font(state.font_normal)
	font_context.set_color(white)
	font_context.set_spacing(0.0)
	font_context.set_blur(3.0)
	font_context.draw_text(dx, dy + 2, 'DROP SHADOW')
	font_context.set_color(black)
	font_context.set_blur(0)
	font_context.draw_text(dx, dy, 'DROP SHADOW')
	font_context.set_size(18.0)
	font_context.set_font(state.font_normal)
	font_context.set_color(white)
	dx = 50
	dy = 350
	line(f32(dx - 10), f32(dy), f32(dx + 250), f32(dy))
	font_context.set_alignment(.left | .top)
	dx = font_context.draw_text(dx, dy, 'Top')
	dx += 10
	font_context.set_alignment(.left | .middle)
	dx = font_context.draw_text(dx, dy, 'Middle')
	dx += 10
	font_context.set_alignment(.left | .baseline)
	dx = font_context.draw_text(dx, dy, 'Baseline')
	dx += 10
	font_context.set_alignment(.left | .bottom)
	font_context.draw_text(dx, dy, 'Bottom')
	dx = 150
	dy = 400
	line(f32(dx), f32(dy - 30), f32(dx), f32(dy + 80.0))
	font_context.set_alignment(.left | .baseline)
	font_context.draw_text(dx, dy, 'Left')
	dy += 30
	font_context.set_alignment(.center | .baseline)
	font_context.draw_text(dx, dy, 'Center')
	dy += 30
	font_context.set_alignment(.right | .baseline)
	font_context.draw_text(dx, dy, 'Right')
	dy += 30
	font_context.set_alignment(.left | .baseline)
	font_context.draw_text(dx, dy, 'tps: ${state.tps}')
	dy += 30
	font_context.draw_text(dx, dy, 'FPS: ${state.fps}')
	dy += 30
	font_context.draw_text(dx, dy, 'Max FPS: ${state.max_fps}')
	dy += 30
	font_context.draw_text(dx, dy, 'Min FPS: ${state.min_fps}')

	sfons.flush(font_context)
}

fn line(sx f32, sy f32, ex f32, ey f32) {
	sgl.begin_lines()
	sgl.c4b(255, 255, 0, 128)
	sgl.v2f(sx, sy)
	sgl.v2f(ex, ey)
	sgl.end()
}


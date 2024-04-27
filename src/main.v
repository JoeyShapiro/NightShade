module main

import time

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

	width int
	height int
	shader_pipeline gfx.Pipeline
	bind            gfx.Bindings
	
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
		width: 1280
		height: 720

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
		width: state.width
		height: state.height

		user_data: state
		init_userdata_cb: init
		frame_userdata_cb: frame
		window_title: title.str
		html5_canvas_name: title.str

		cleanup_userdata_cb: cleanup
		sample_count: 4 // Enables MSAA (Multisample anti-aliasing) x4 on rendered output, this can be omitted.
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
	if bytes := os.read_bytes(os.resource_abs_path('JetBrainsMono-Regular.ttf'))
	{
		println('loaded font: ${bytes.len}')
		state.font_normal = state.font_context.add_font_mem('sans', bytes, false)
	} else {
		println("failed to load font at ${os.resource_abs_path('RobotoMono-Regular.ttf')}")
	}

	vertices := [
		Vertex_t{-1.0, 1.0, 0.5, 1.0, 0.0, 0.0, 1.0}, // TL
		Vertex_t{-1.0, -1.0, 0.5, 0.0, 1.0, 0.0, 1.0}, // BL
		Vertex_t{1.0, 1.0, 0.5, 0.0, 0.0, 1.0, 1.0}, // TR

		Vertex_t{1.0, 1.0, 0.5, 1.0, 0.0, 0.0, 1.0}, // TR
		Vertex_t{1.0, -1.0, 0.5, 0.0, 1.0, 0.0, 1.0}, // BR
		Vertex_t{-1.0, -1.0, 0.5, 0.0, 0.0, 1.0, 1.0}, // BL
	]

	// Create a vertex buffer with the 3 vertices defined above.
	mut vertex_buffer_desc := gfx.BufferDesc{
		label: c'triangle-vertices'
	}
	unsafe { vmemset(&vertex_buffer_desc, 0, int(sizeof(vertex_buffer_desc))) }

	vertex_buffer_desc.size = usize(vertices.len * int(sizeof(Vertex_t)))
	vertex_buffer_desc.data = gfx.Range{
		ptr: vertices.data
		size: vertex_buffer_desc.size
	}

	state.bind.vertex_buffers[0] = gfx.make_buffer(&vertex_buffer_desc)

	// Create shader from the code-generated sg_shader_desc (gfx.ShaderDesc in V).
	// Note the function `C.simple_shader_desc()` (also defined above) - this is
	// the function that returns the compiled shader code/desciption we have
	// written in `simple_shader.glsl` and compiled with `v shader .` (`sokol-shdc`).
	shader := gfx.make_shader(C.simple_shader_desc(gfx.query_backend()))

	eprintln('${gfx.query_backend()} backend selected')

	// Create a pipeline object (default render states are fine for triangle)
	mut pipeline_desc := gfx.PipelineDesc{}
	// This will zero the memory used to store the pipeline in.
	unsafe { vmemset(&pipeline_desc, 0, int(sizeof(pipeline_desc))) }

	// Populate the essential struct fields
	pipeline_desc.shader = shader
	pipeline_desc.layout.attrs[C.ATTR_vs_position].format = .float3 // x,y,z as f32
	pipeline_desc.layout.attrs[C.ATTR_vs_color0].format = .float4 // r, g, b, a as f32
	// The .label is optional but can aid debugging sokol shader related issues
	// When things get complex - and you get tired :)
	pipeline_desc.label = c'triangle-pipeline'

	state.shader_pipeline = gfx.make_pipeline(&pipeline_desc)
}

fn cleanup(user_data voidptr) {
	gfx.shutdown()
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

	gfx.apply_pipeline(state.shader_pipeline)
	gfx.apply_bindings(&state.bind)
	gfx.draw(0, 6, 1)
	sgl.draw()

	gfx.end_pass()
	gfx.commit()
}

fn (state &AppState) render_font() {
	mut dx := f32(0.0)
	mut dy := f32(0.0)
	lh := f32(0.0)
	white := sfons.rgba(255, 255, 255, 255)

	font_context := state.font_context
	font_context.clear_state()
	sgl.defaults()
	sgl.matrix_mode_projection()
	sgl.ortho(0.0, f32(sapp.width()), f32(sapp.height()), 0.0, -1.0, 1.0)
	font_context.set_font(state.font_normal)
	ascender := f32(0.0)
	descender := f32(0.0)
	font_context.vert_metrics(&ascender, &descender, &lh)
	dy += lh
	font_context.set_size(18.0)
	font_context.set_color(white)
	font_context.set_alignment(.left | .baseline)
	font_context.draw_text(dx, dy, 'tps: ${state.tps}')
	dy += 18
	font_context.draw_text(dx, dy, 'FPS: ${state.fps}')
	dy += 18
	font_context.draw_text(dx, dy, 'Max FPS: ${state.max_fps}')
	dy += 18
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


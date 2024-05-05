module main

import time

import sokol.sapp
import sokol.gfx
import sokol.sgl
import fontstash
import sokol.sfons
import os
import gg
import gg.m4
import gx
import math
import obj

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
	// shader_pipeline gfx.Pipeline
	// bind            gfx.Bindings
	
	pixels []f32
	start_epoch time.StopWatch
	fps f32
	tps f32
	last_frame_time i64
	last_tick_time i64
	max_fps f32
	min_fps f32

	gg          &gg.Context = unsafe { nil }
	texture     gfx.Image
	sampler     gfx.Sampler
	init_flag   bool

	// model
	obj_part &obj.ObjPart = unsafe { nil }
	n_vertex u32
	mouse_x int
	mouse_y int
}

const bg_color = gx.white

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

	state.gg = gg.new_context(
		width: 1280
		height: 720
		create_window: true
		window_title: 'Night Shade'
		user_data: state
		bg_color: bg_color
		frame_fn: frame
		init_fn: init
		cleanup_fn: cleanup
		event_fn: my_event_manager
	)
	state.gg.run() // this seems to override the sapp.run() call

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
	s := &sgl.Desc{
		max_vertices: 128 * 65536
	}
	sgl.setup(s)
	state.font_context = sfons.create(512, 512, 1)
	// or use DroidSerif-Regular.ttf
	if bytes := os.read_bytes(os.resource_abs_path('assets/fonts/JetBrainsMono-Regular.ttf'))
	{
		println('loaded font: ${bytes.len}')
		state.font_normal = state.font_context.add_font_mem('sans', bytes, false)
	} else {
		println("failed to load font at ${os.resource_abs_path('RobotoMono-Regular.ttf')}")
	}

	// Create shader from the code-generated sg_shader_desc (gfx.ShaderDesc in V).
	// Note the function `C.simple_shader_desc()` (also defined above) - this is
	// the function that returns the compiled shader code/desciption we have
	// written in `simple_shader.glsl` and compiled with `v shader .` (`sokol-shdc`).
	// shader := gfx.make_shader(C.simple_shader_desc(gfx.query_backend()))

	// eprintln('${gfx.query_backend()} backend selected')

	// // Create a pipeline object (default render states are fine for triangle)
	// mut pipeline_desc := gfx.PipelineDesc{}
	// // This will zero the memory used to store the pipeline in.
	// unsafe { vmemset(&pipeline_desc, 0, int(sizeof(pipeline_desc))) }

	// // Populate the essential struct fields
	// pipeline_desc.shader = shader
	// pipeline_desc.layout.attrs[C.ATTR_vs_position].format = .float3 // x,y,z as f32
	// pipeline_desc.layout.attrs[C.ATTR_vs_color0].format = .float4 // r, g, b, a as f32
	// // pipeline_desc.layout.attrs[C.ATTR_]
	// // The .label is optional but can aid debugging sokol shader related issues
	// // When things get complex - and you get tired :)
	// pipeline_desc.label = c'triangle-pipeline'

	// state.shader_pipeline = gfx.make_pipeline(&pipeline_desc)

	mut object := &obj.ObjPart{}
	obj_file_lines := obj.read_lines_from_file('utahTeapot.obj')
	object.parse_obj_buffer(obj_file_lines, true)
	object.summary()
	state.obj_part = object

	// 1x1 pixel white, default texture
	unsafe {
		tmp_txt := malloc(4)
		tmp_txt[0] = u8(0xFF)
		tmp_txt[1] = u8(0xFF)
		tmp_txt[2] = u8(0xFF)
		tmp_txt[3] = u8(0xFF)
		state.texture, state.sampler = obj.create_texture(1, 1, tmp_txt)
		free(tmp_txt)
	}
	// glsl
	state.obj_part.init_render_data(state.texture, state.sampler)
	state.init_flag = true
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

	// gfx.draw(0, 6, 1)

	// ws := gg.window_size_real_pixels()
	// gfx.apply_viewport(0, 0, ws.width, ws.height, true)
	draw_model(state, m4.Vec4{})

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
	font_context.draw_text(dx, dy, 'fps: ${state.fps}')
	dy += 18
	font_context.draw_text(dx, dy, 'Max fps: ${state.max_fps}')
	dy += 18
	font_context.draw_text(dx, dy, 'Min fps: ${state.min_fps}')
	dy += 18
	font_context.draw_text(dx, dy, 'backend: ${gfx.query_backend()}')

	sfons.flush(font_context)
}

fn line(sx f32, sy f32, ex f32, ey f32) {
	sgl.begin_lines()
	sgl.c4b(255, 255, 0, 128)
	sgl.v2f(sx, sy)
	sgl.v2f(ex, ey)
	sgl.end()
}

@[inline]
fn vec4(x f32, y f32, z f32, w f32) m4.Vec4 {
	return m4.Vec4{
		e: [x, y, z, w]!
	}
}

fn calc_matrices(w f32, h f32, rx f32, ry f32, in_scale f32, pos m4.Vec4) obj.Mats {
	proj := m4.perspective(60, w / h, 0.01, 100.0) // set far plane to 100 fro the zoom function
	view := m4.look_at(vec4(f32(0.0), 0, 6, 0), vec4(f32(0), 0, 0, 0), vec4(f32(0), 1,
		0, 0))
	view_proj := view * proj

	rxm := m4.rotate(m4.rad(rx), vec4(f32(1), 0, 0, 0))
	rym := m4.rotate(m4.rad(ry), vec4(f32(0), 1, 0, 0))

	model_pos := m4.unit_m4().translate(pos)

	model_m := (rym * rxm) * model_pos
	scale_m := m4.scale(vec4(in_scale, in_scale, in_scale, 1))

	mv := scale_m * model_m // model view
	nm := mv.inverse().transpose() // normal matrix
	mvp := mv * view_proj // model view projection

	return obj.Mats{
		mv: mv
		mvp: mvp
		nm: nm
	}
}

fn draw_model(state AppState, model_pos m4.Vec4) u32 {
	ws := gg.window_size_real_pixels()
	dw := ws.width / 2
	dh := ws.height / 2

	mut scale := f32(1)
	if state.obj_part.radius > 1 {
		scale = 1 / (state.obj_part.radius)
	} else {
		scale = state.obj_part.radius
	}
	scale *= 3

	// *** vertex shader uniforms ***
	rot := [f32(state.mouse_y), f32(state.mouse_x)]
	mut zoom_scale := scale + 0.0 / (state.obj_part.radius * 4)
	mats := calc_matrices(dw, dh, rot[0], rot[1], zoom_scale, model_pos)

	mut tmp_vs_param := obj.Tmp_vs_param{
		mv: mats.mv
		mvp: mats.mvp
		nm: mats.nm
	}

	// *** fragment shader uniforms ***
	time_ticks := f32(state.last_tick_time) / 1000
	radius_light := f32(state.obj_part.radius)
	x_light := f32(math.cos(time_ticks) * radius_light)
	z_light := f32(math.sin(time_ticks) * radius_light)

	mut tmp_fs_params := obj.Tmp_fs_param{}
	tmp_fs_params.light = m4.vec3(x_light, radius_light, z_light)

	sd := obj.Shader_data{
		vs_data: unsafe { &tmp_vs_param }
		vs_len: int(sizeof(tmp_vs_param))
		fs_data: unsafe { &tmp_fs_params }
		fs_len: int(sizeof(tmp_fs_params))
	}

	return state.obj_part.bind_and_draw_all(sd)
}

/******************************************************************************
* events handling
******************************************************************************/
fn my_event_manager(mut ev gg.Event, mut state AppState) {
	if ev.typ == .mouse_move {
		state.mouse_x = int(ev.mouse_x)
		state.mouse_y = int(ev.mouse_y)
	}
	if ev.typ == .key_down {
		if ev.key_code == .escape {
			println('escape key pressed, exiting')
		} else if ev.key_code == .w {
			state.mouse_x = int(100)
		}
	}

	if ev.typ == .touches_began || ev.typ == .touches_moved {
		if ev.num_touches > 0 {
			touch_point := ev.touches[0]
			state.mouse_x = int(touch_point.pos_x)
			state.mouse_y = int(touch_point.pos_y)
		}
	}
}

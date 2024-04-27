module main

import gg
import gx
import time

struct App {
mut:
	gg     &gg.Context = unsafe { nil }
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
	mut app := &App{
		pixels: pixels
		start_epoch: stop_watch
		last_frame_time: stop_watch.elapsed().milliseconds()
		last_tick_time: stop_watch.elapsed().milliseconds()
		min_fps: 999999999.0
	}
	app.gg = gg.new_context(
		bg_color: gx.rgb(174, 198, 255)
		width: 1280
		height: 720
		window_title: 'Set Pixels'
		frame_fn: frame
		user_data: app
	)
	app.gg.run()
}

fn frame(mut app App) {
	// time.sleep(time.millisecond * 500)
	now := app.start_epoch.elapsed().milliseconds()

	app.tps = 1000.0 / f32(now - app.last_tick_time)
	app.fps = 1000.0 / f32(now - app.last_frame_time)
	app.last_tick_time = now

	if now - app.last_frame_time < 1000 / 120 {
		return
	}
	app.last_frame_time = now

	app.gg.begin()

	// Draw a blue pixel near each corner. (Find your magnifying glass)
	app.gg.draw_pixel(2, 2, gx.blue)
	app.gg.draw_pixel(app.gg.width - 2, 2, gx.blue)
	app.gg.draw_pixel(app.gg.width - 2, app.gg.height - 2, gx.blue)
	app.gg.draw_pixel(2, app.gg.height - 2, gx.blue)

	app.gg.draw_circle_filled(100, 100, 50, gx.red)
	// eprintln('Simulation time: ${now}ms')
	app.gg.draw_text_def(0, 0, 'Simulation time: ${now}ms')
	app.gg.draw_text_def(0, 10, 'TPS: ${app.tps}')
	app.gg.draw_text_def(0, 20, 'FPS: ${app.fps}')

	if app.fps > app.max_fps {
		app.max_fps = app.fps
	}
	if app.fps < app.min_fps {
		app.min_fps = app.fps
	}

	app.gg.draw_text_def(0, 30, 'Max FPS: ${app.max_fps}')
	app.gg.draw_text_def(0, 40, 'Min FPS: ${app.min_fps}')

	// Draw pixels in a grid-like pattern.
	app.gg.draw_pixels(app.pixels, gx.red)
	app.gg.end()
}

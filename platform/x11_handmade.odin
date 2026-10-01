package main

import "core:fmt"
import vmem "core:mem/virtual"
import x11 "vendor:x11/xlib"

MAX_WIDTH :: 1920
MAX_HEIGHT :: 1080
bitmap_width := 800
bitmap_height := 600
byte_per_pixel := 4


draw :: proc(bitmap_mem: []byte, x_offset, y_offset: int) {
	pitch := bitmap_width * byte_per_pixel
	for y := 0; y < int(bitmap_height); y += 1 {
		for x := 0; x < int(bitmap_width); x += 1 {
			blue := u32(u8(x + x_offset))
			green := u32(u8(y + y_offset))
			red := u32(0)
			alpha := u32(255)
			color := alpha << 24 | red << 16 | green << 8 | blue
			(^u32)(&bitmap_mem[y*pitch + x*byte_per_pixel])^ = color

			//blue := u8(x + x_offset)
			//green := u8(y + y_offset)
			// bitmap_mem[y*pitch + x*byte_per_pixel] = blue
			// bitmap_mem[y*pitch + x*byte_per_pixel + 1] = green
			// bitmap_mem[y*pitch + x*byte_per_pixel + 2] = 0   // red
			// bitmap_mem[y*pitch + x*byte_per_pixel + 3] = 255 // alpha

 		}
	}
}

main :: proc() {
	display := x11.OpenDisplay(nil)
	assert(display != nil, "Failed to Open Display!")
	defer x11.CloseDisplay(display)

	screen := x11.DefaultScreen(display)
	root := x11.RootWindow(display, screen)

	window := x11.CreateSimpleWindow(display, root, 0, 0, u32(bitmap_width), u32(bitmap_height), 1, 0, 0)
	x11.StoreName(display, window, "Handmade Hero Odin")

	wm_delete := x11.InternAtom(display, "WM_DELETE_WINDOW", false)
	x11.SetWMProtocols(display, window, &wm_delete, 1)

	event_mask := x11.EventMask{.StructureNotify, .Exposure, .KeyPress, .FocusChange}
	x11.SelectInput(display, window, event_mask)
	x11.MapWindow(display, window)
	gc := x11.DefaultGC(display, screen)
	defer x11.DestroyWindow(display, window)

	// allocating back buffer for the max 1080p size
	bitmap_mem, err := vmem.reserve_and_commit(uint(MAX_WIDTH * MAX_HEIGHT * byte_per_pixel))
	assert(err == nil, "Cannot allocate memory for bitmap!")

	pitch := bitmap_width * byte_per_pixel
	image := x11.CreateImage(display, x11.DefaultVisual(display, screen), 24, .ZPixmap, 0, raw_data(bitmap_mem), u32(bitmap_width), u32(bitmap_height), 32, i32(pitch))
	draw(bitmap_mem, 0, 0)

	x_offset := 0
	y_offset := 0
	running := true
	for running {
		for x11.Pending(display) > 0 {
			event: x11.XEvent
			x11.NextEvent(display, &event)

			#partial switch event.type {
			case .ConfigureNotify:
				new_width := int(event.xconfigure.width)
				new_height := int(event.xconfigure.height)
				fmt.printf("Window Size Changed: %d x %d\n", new_width, new_height)
				// reset the bitmap width and height and image's size.
				if bitmap_width != new_width || bitmap_height != new_height {
					bitmap_width = new_width
					bitmap_height = new_height
					image.width = i32(bitmap_width)
					image.height = i32(bitmap_height)
					image.bytes_per_line = i32(bitmap_width * byte_per_pixel)
				}
				draw(bitmap_mem, x_offset, y_offset)

			case .ClientMessage:
				if x11.Atom(event.xclient.data.l[0]) == wm_delete {
					fmt.println("Window Closed.")
					running = false
				}

			case .DestroyNotify:
				fmt.println("Window Destroyed.")
				running = false

			case .FocusIn:
				fmt.println("Window gained focus (Activate).")

			case .FocusOut:
				fmt.println("Window lost focus.")

			case .KeyPress:
				fmt.println("Key pressed – quitting.")
				running = false

			case:
				fmt.printf("Event %v came in!\n", event.type)
			}
		}
		draw(bitmap_mem, x_offset, y_offset)
		x11.PutImage(display, window, gc, image, 0, 0, 0, 0, u32(bitmap_width), u32(bitmap_height))
		x11.Flush(display)
		x_offset += 1
		y_offset += 2
	}
}

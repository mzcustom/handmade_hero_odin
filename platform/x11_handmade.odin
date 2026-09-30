package main

import "core:fmt"
import x11 "vendor:x11/xlib"

main :: proc() {
	display := x11.OpenDisplay(nil)
	assert(display != nil, "Failed to Open Display!")
	defer x11.CloseDisplay(display)

	screen := x11.DefaultScreen(display)
	root := x11.RootWindow(display, screen)

	window := x11.CreateSimpleWindow(display, root, 0, 0, 800, 600, 1, 0, 0)
	x11.StoreName(display, window, "Handmade Hero Odin")

	wm_delete := x11.InternAtom(display, "WM_DELETE_WINDOW", false)
	x11.SetWMProtocols(display, window, &wm_delete, 1)

	event_mask := x11.EventMask{.StructureNotify, .Exposure, .KeyPress, .FocusChange}
	x11.SelectInput(display, window, event_mask)
	x11.MapWindow(display, window)
	defer x11.DestroyWindow(display, window)

	running := true
	for running {
		event: x11.XEvent
		x11.NextEvent(display, &event)

		#partial switch event.type {
		case .ConfigureNotify:
			cfg := event.xconfigure
			fmt.printf("Window Size Changed: %d x %d\n", cfg.width, cfg.height)

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
}

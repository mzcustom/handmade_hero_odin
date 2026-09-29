package main

import "base:runtime"
import "core:fmt"
import win "core:sys/windows"

main_window_callback :: proc "stdcall" (
	window: win.HWND,
	message: u32,
	w_param: uintptr,
	l_param: int,
) -> int {
	res := 0
	context = runtime.default_context()

	switch message {
	case win.WM_SIZE:
		fmt.println("Window Size Changed.")
	case win.WM_DESTROY:
		fmt.println("Window Destroyed.")
	case win.WM_CLOSE:
		fmt.println("Window Closed.")
	case win.WM_ACTIVATEAPP:
		fmt.println("Window Active APP event triggered.")
	case:
		res = win.DefWindowProcW(window, message, w_param, l_param)
	}

	return res
}

main :: proc() {
	window := win.WNDCLASSW {
		style         = win.CS_OWNDC | win.CS_HREDRAW | win.CS_VREDRAW,
		lpfnWndProc   = main_window_callback,
		hInstance     = win.HINSTANCE(win.GetModuleHandleW(nil)),
		//	hIcon:         HICON,
		//	hCursor:       HCURSOR,
		lpszClassName = "MainWindow",
	}

	window_cls := win.RegisterClassW(&window)
	assert(window_cls != 0, "Registering Window class failed!")

	window_handle := win.CreateWindowExW(
		0,
		window.lpszClassName,
		"Handmade Hero Odin",
		win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
		0,
		0,
		0,
		0,
		nil,
		nil,
		window.hInstance,
		nil,
	)
	assert(window_handle != nil, "Creating Window failed!")

	for {
		msg: win.MSG
		msg_res := win.GetMessageW(&msg, nil, 0, 0)
		if msg_res > 0 {
			win.TranslateMessage(&msg)
			win.DispatchMessageW(&msg)
		} else {
			break
		}
	}
}

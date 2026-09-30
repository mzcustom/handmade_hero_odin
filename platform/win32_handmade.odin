package main

import "base:runtime"
import "core:fmt"
import vmem "core:mem/virtual"
import win "core:sys/windows"

running := true

bitmap_info: win.BITMAPINFO
bitmap_memory: []byte
bitmap_width: i32
bitmap_height: i32
byte_per_pixel := 4

render_grad :: proc(x_offset, y_offset: int) {
	pitch := int(bitmap_width) * byte_per_pixel
	//color := ([]byte){0xFf, 0x00, 0x00, 0x00}
	for y := 0; y < int(bitmap_height); y += 1 {
		for x := 0; x < int(bitmap_width); x += 1 {
			curr_pixel := y*pitch + x*byte_per_pixel
			bitmap_memory[curr_pixel] = u8(x + x_offset)
			bitmap_memory[curr_pixel+1] = u8(y+ y_offset)
			bitmap_memory[curr_pixel+2] = 0
			bitmap_memory[curr_pixel+3] = 0
			//(^u32)(&bitmap_memory[curr_pixel])^ = 0x00FF0000
 			//copy(bitmap_memory[curr_pixel:curr_pixel+4], color)
		}
	}
}

win32_create_or_resize_DIB_section :: proc(width, height: i32) {
	bitmap_memory_size := uint(width * height * i32(byte_per_pixel)) // 4 byte pixel for memory alignment. Or RGBA anyway.
	if(bitmap_memory != nil) {
		vmem.release(raw_data(bitmap_memory), bitmap_memory_size)
	}
	bitmap_width = width
	bitmap_height = height

	bitmap_info.bmiHeader.biSize = size_of(bitmap_info.bmiHeader)
	bitmap_info.bmiHeader.biWidth = bitmap_width
	bitmap_info.bmiHeader.biHeight = -bitmap_height  //negative for memory layout to match top-down orientation of the canvas
	bitmap_info.bmiHeader.biPlanes = 1
	bitmap_info.bmiHeader.biBitCount = 32
	bitmap_info.bmiHeader.biCompression = win.BI_RGB

	err: runtime.Allocator_Error
	bitmap_memory, err = vmem.reserve_and_commit(bitmap_memory_size)
	assert(err == nil, "Cannot allocate memory for bitmap!")

}

win32_update_window :: proc(device_context: win.HDC, window_rect: ^win.RECT) {
	window_width := window_rect.right - window_rect.left
	window_height := window_rect.bottom - window_rect.top

	win.StretchDIBits(device_context,
		0, 0, bitmap_width, bitmap_height,
	 	0, 0, window_width, window_height,
		raw_data(bitmap_memory), &bitmap_info,
		win.DIB_RGB_COLORS, win.SRCCOPY)
}

win32_main_window_callback :: proc "stdcall" (
	window: win.HWND,
	message: u32,
	w_param: uintptr,
	l_param: int,
) -> int {
	res := 0
	context = runtime.default_context()

	switch message {
	case win.WM_SIZE:
		cr: win.RECT
		win.GetClientRect(window, &cr)
		width := cr.right - cr.left
		height := cr.bottom - cr.top
		win32_create_or_resize_DIB_section(width, height)
		fmt.println("Window Size Changed.")

	case win.WM_DESTROY:
		running = false
		fmt.println("Window Destroyed.")

	case win.WM_CLOSE:
		running = false
		fmt.println("Window Closed.")

	case win.WM_ACTIVATEAPP:
		fmt.println("Window Active APP event triggered.")

	case win.WM_PAINT:
		paint: win.PAINTSTRUCT
		device_context := win.BeginPaint(window, &paint)
		// rc := paint.rcPaint
		// x := rc.left
		// y := rc.top
		// w := rc.right - rc.left
		// h := rc.bottom - rc.top
		client_rect: win.RECT
		win.GetClientRect(window, &client_rect)
		win32_update_window(device_context, &client_rect)
		win.EndPaint(window, &paint)

		fmt.println("Update Window Paint")

	case:
		res = win.DefWindowProcW(window, message, w_param, l_param)
	}

	return res
}

main :: proc() {
	window := win.WNDCLASSW {
		lpfnWndProc   = win32_main_window_callback,
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
		800,
		600,
		nil,
		nil,
		window.hInstance,
		nil,
	)
	assert(window_handle != nil, "Creating Window failed!")

	x_offset := 0
	y_offset := 0
	for running {
		msg: win.MSG
		for win.PeekMessageW(&msg, nil, 0, 0, win.PM_REMOVE) {
			if msg.message == win.WM_QUIT {
				running = false
			}
			win.TranslateMessage(&msg)
			win.DispatchMessageW(&msg)
		}

		render_grad(x_offset, y_offset)
		dc := win.GetDC(window_handle)
		rect: win.RECT
		win.GetClientRect(window_handle, &rect)
		win32_update_window(dc, &rect)
		win.ReleaseDC(window_handle, dc)

		x_offset += 1
	}
}

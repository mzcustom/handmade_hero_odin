package main

import "base:runtime"
import "core:fmt"
import vmem "core:mem/virtual"
import win "core:sys/windows"


BACK_BUFFER_WIDTH :: i32(1280)
BACK_BUFFER_HEIGHT :: i32(720)

running := true
byte_per_pixel := 4
global_back_buffer := Win32_Back_Buffer{}

Win32_Back_Buffer :: struct {
	info: win.BITMAPINFO,
	memory: []byte,
	width: i32,
	height: i32,
	pitch: int,
}

render_grad :: proc(buf: ^Win32_Back_Buffer, x_offset, y_offset: int) {
	//color := ([]byte){0xFf, 0x00, 0x00, 0x00}
	for y := 0; y < int(buf.height); y += 1 {
		for x := 0; x < int(buf.width); x += 1 {
			curr_pixel := y*buf.pitch + x*byte_per_pixel
			buf.memory[curr_pixel] = u8(x + x_offset)
			buf.memory[curr_pixel+1] = u8(y+ y_offset)
			buf.memory[curr_pixel+2] = 0
			buf.memory[curr_pixel+3] = 0
			//(^u32)(&bitmap_memory[curr_pixel])^ = 0x00FF0000
 			//copy(bitmap_memory[curr_pixel:curr_pixel+4], color)
		}
	}
}

win32_get_window_dimension :: proc(window: win.HWND) -> (i32, i32) {
	rect: win.RECT
	win.GetClientRect(window, &rect)
	return rect.right - rect.left, rect.bottom - rect.top
}

win32_create_or_resize_DIB_section :: proc(buf: ^Win32_Back_Buffer, width, height: i32) {
	if(buf.memory != nil) {
		vmem.release(raw_data(buf.memory), len(buf.memory))
	}
	buf.width = width
	buf.height = height
	buf.pitch = int(buf.width) * byte_per_pixel
	bitmap_memory_size := uint(width * height * i32(byte_per_pixel)) // 4 byte pixel for memory alignment. Or RGBA anyway.

	buf.info.bmiHeader.biSize = size_of(buf.info.bmiHeader)
	buf.info.bmiHeader.biWidth = buf.width
	buf.info.bmiHeader.biHeight = -buf.height  //negative for memory layout to match top-down orientation of the canvas
	buf.info.bmiHeader.biPlanes = 1
	buf.info.bmiHeader.biBitCount = 32
	buf.info.bmiHeader.biCompression = win.BI_RGB

	err: runtime.Allocator_Error
	buf.memory, err = vmem.reserve_and_commit(bitmap_memory_size)
	assert(err == nil, "Cannot allocate memory for bitmap!")

}

win32_display_buffer_in_window :: proc(device_context: win.HDC, buf: ^Win32_Back_Buffer, window_width, window_height: i32) {
	win.StretchDIBits(device_context,
	 	0, 0, window_width, window_height,
		0, 0, buf.width, buf.height,
		raw_data(buf.memory), &buf.info,
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
		fmt.println("Window Size Changed.")

	case win.WM_DESTROY:
		running = false
		fmt.println("Window Destroyed.")

	case win.WM_CLOSE:
		running = false
		fmt.println("Window Closed.")

	case win.WM_ACTIVATEAPP:
		fmt.println("Window Active APP event triggered.")

	case win.WM_KEYUP, win.WM_KEYDOWN, win.WM_SYSKEYDOWN, win.WM_SYSKEYUP:
		code := w_param
		was_down := l_param & (1 << 30) != 0
		is_down := l_param & (1 << 31) == 0
		if is_down != was_down {
			if code == 'W' {
				fmt.println("W")
			} else if code == 'A' {
				fmt.println("A")
			} else if code == 'S' {
				fmt.println("S")
			} else if code == 'D' {
				fmt.println("D")
			} else if code == 'Q' {
				fmt.println("Q")
			} else if code == 'E' {
				fmt.println("E")
			} else if code == win.VK_UP {
				fmt.println("UP")
			} else if code == win.VK_DOWN {
				fmt.println("DOWN")
			} else if code == win.VK_LEFT {
				fmt.println("LEFT")
			} else if code == win.VK_RIGHT {
				fmt.println("RIGHT")
			} else if code == win.VK_ESCAPE {
				fmt.printf("ESC: ")
				if(is_down) {
					fmt.printf("is down ")
				}
				if(was_down) {
					fmt.printf("was down ")
				}
				fmt.printf("\n")
			} else if code == win.VK_SPACE {
				fmt.println("SPACE")
			}
		}

	case win.WM_PAINT:
		paint: win.PAINTSTRUCT
		device_context := win.BeginPaint(window, &paint)
		w, h := win32_get_window_dimension(window)
		win32_display_buffer_in_window(device_context, &global_back_buffer, w, h)
		win.EndPaint(window, &paint)

		fmt.println("Update Window Paint")

	case:
		res = win.DefWindowProcW(window, message, w_param, l_param)
	}

	return res
}

main :: proc() {
	win32_create_or_resize_DIB_section(&global_back_buffer, BACK_BUFFER_WIDTH, BACK_BUFFER_HEIGHT) // allocating global back buffer
	window := win.WNDCLASSW {
		style = win.CS_HREDRAW | win.CS_VREDRAW | win.CS_OWNDC,
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
		BACK_BUFFER_WIDTH,
		BACK_BUFFER_HEIGHT,
		nil,
		nil,
		window.hInstance,
		nil,
	)
	assert(window_handle != nil, "Creating Window failed!")

	dc := win.GetDC(window_handle)
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

		render_grad(&global_back_buffer, x_offset, y_offset)
		w, h := win32_get_window_dimension(window_handle)
		win32_display_buffer_in_window(dc, &global_back_buffer, w, h)

		x_offset += 1
		y_offset += 2
	}
}

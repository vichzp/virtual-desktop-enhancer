; ======================================================================
; Core methods
; ======================================================================

_IsCursorHoveringTaskbar() {
	MouseGetPos,, posY, mouseHoveringID

	if (TaskbarIDs.Length() == 0) {
		WinGet, taskbarPrimaryID, ID, ahk_class Shell_TrayWnd
		TaskbarIDs.Push(taskbarPrimaryID)

		WinGet, taskbarSecondary, List, ahk_class Shell_SecondaryTrayWnd
		Loop, %taskbarSecondary% {
			TaskbarIDs.Push(taskbarSecondary%A_Index%)
		}
	}

	For index, taskbarId in TaskbarIDs {
		if (mouseHoveringID == taskbarId) {
			return true
		}
	}

	WinGetPos,, Y,, H, A
	onBottomEdge := H - Y - posY - 1
	if (Y == 0 && onBottomEdge == 0) {
		return true
	}
}

_GetCurrentWindowID() {
	WinGet, activeHwnd, ID, A
	return activeHwnd
}

_GetCurrentWindowTitle() {
	WinGetTitle, activeHwnd, A
	return activeHwnd
}

_TruncateString(string:="", n := 10) {
	return (StrLen(string) > n ? SubStr(string, 1, n-3) . "..." : string)
}

_GetDesktopName(n := 1) {
	name := DesktopNames%n%
	if (!name) {
		name := "Desktop " . n
	}
	return name
}

; Set the name of the nth desktop to the value of a given string.
_SetDesktopName(n := 1, name := 0) {
	if (!name) {
		; Default value: "Desktop N".
		name := "Desktop " %n%
	}
	DesktopNames%n% := name
}

_GetNextDesktopNumber() {
	i := _GetCurrentDesktopNumber()
	if (GeneralDesktopWrapping == 1) {
		i := (i >= _GetNumberOfCyclableDesktops() ? 1 : i + 1)
	} else {
		i := (i >= _GetNumberOfCyclableDesktops() ? i : i + 1)
	}

	return i
}

_GetPreviousDesktopNumber() {
	i := _GetCurrentDesktopNumber()
	if (i > _GetNumberOfCyclableDesktops()) {
		i := _GetNumberOfCyclableDesktops()
	} else if (GeneralDesktopWrapping == 1) {
		i := (i == 1 ? _GetNumberOfCyclableDesktops() : i - 1)
	} else {
		i := (i == 1 ? i : i - 1)
	}

	return i
}

_GetCurrentDesktopNumber() {
	return DllCall(GetCurrentDesktopNumberProc) + 1
}

_GetNumberOfDesktops() {
	return DllCall(GetDesktopCountProc)
}

_GetNumberOfCyclableDesktops() {
	if (GeneralNumberOfCyclableDesktops >= 1) {
		return Min(numDesktops, GeneralNumberOfCyclableDesktops)
	}
	return numDesktops
}

_MoveCurrentWindowToDesktop(n := 1) {
	activeHwnd := _GetCurrentWindowID()
	DllCall(MoveWindowToDesktopNumberProc, UInt, activeHwnd, UInt, n - 1)
}

_ChangeDesktop(n := 1) {
	Loop, %numDesktops% {
		Menu, Tray, Uncheck, % _GetDesktopName(A_Index)
		if (n == A_Index) {
			nextName := DesktopNames%A_Index%
			Menu, Tray, Check, %nextName%
		}
	}
	DllCall(GoToDesktopNumberProc, Int, n - 1)
}

_CallWindowProc(proc, window:="") {
	if (window == "") {
		window := _GetCurrentWindowID()
	}
	return DllCall(proc, UInt, window)
}

_PinWindow(windowID:="") {
	_CallWindowProc(PinWindowProc, windowID)
}

_UnpinWindow(windowID:="") {
	_CallWindowProc(UnpinWindowProc, windowID)
}

_GetIsWindowPinned(windowID:="") {
	return _CallWindowProc(IsPinnedWindowProc, windowID)
}

_PinApp(windowID:="") {
	_CallWindowProc(PinAppProc, windowID)
}

_UnpinApp(windowID:="") {
	_CallWindowProc(UnpinAppProc, windowID)
}

_GetIsAppPinned(windowID:="") {
	return _CallWindowProc(IsPinnedAppProc, windowID)
}

_RunProgram(program:="", settingName:="") {
	if (program <> "") {
		if (FileExist(program)) {
			Run, % program
		}
		else {
			MsgBox, 16, Error, The program "%program%" is not valid. `nPlease reconfigure the "%settingName%" setting. `n`nPlease read the README for instructions.
		}
	}
}

_RunProgramWhenSwitchingToDesktop(n := 1) {
	_RunProgram(RunProgramWhenSwitchingToDesktop%n%, "[RunProgramWhenSwitchingToDesktop] " . n)
}

_RunProgramWhenSwitchingFromDesktop(n := 1) {
	_RunProgram(RunProgramWhenSwitchingFromDesktop%n%, "[RunProgramWhenSwitchingFromDesktop] " . n)
}

_ChangeBackground(n := 1) {
	line := Wallpapers%n%
	isHex := RegExMatch(line, "^0x([0-9A-Fa-f]{1,6})", hexMatchTotal)
	if (isHex) {
		hexColorReversed := SubStr("00000" . hexMatchTotal1, -5)

		RegExMatch(hexColorReversed, "^([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})", match)
		hexColor := "0x" . match3 . match2 . match1, hexColor += 0

		DllCall("SystemParametersInfo", UInt, 0x14, UInt, 0, Str, "", UInt, 1)
		DllCall("SetSysColors", "Int", 1, "Int*", 1, "UInt*", hexColor)
	}
	else {
		filePath := line

		isRelative := (substr(filePath, 1, 1) == ".")
		if (isRelative) {
			filePath := (A_WorkingDir . substr(filePath, 2))
		}
		if (filePath and FileExist(filePath)) {
			DllCall("SystemParametersInfo", UInt, 0x14, UInt, 0, Str, filePath, UInt, 1)
		}
	}
}

_ChangeAppearance(n := 1) {
	Menu, Tray, Tip, % _GetDesktopName(n)
	iconFile := Icons%n% ? Icons%n% : n . ".png"
	if (FileExist(GeneralIconDir . iconFile)) {
		Menu, Tray, Icon, %GeneralIconDir%%iconFile%
	}
	else {
		Menu, Tray, Icon, %GeneralIconDir%+.png
	}
}

; Only give focus to the foremost window if it has been requested.
_FocusIfRequested() {
	if (doFocusAfterNextSwitch) {
		_Focus()
		doFocusAfterNextSwitch=0
	}
}

; Give focus to the foremost window on the desktop.
_Focus() {
	if (!isDisabled) {
		foremostWindowId := _GetForemostWindowIdOnDesktop(_GetCurrentDesktopNumber())
		WinActivate, ahk_id %foremostWindowId%
	}
}

; Select the ahk_id of the foremost window in a given virtual desktop.
_GetForemostWindowIdOnDesktop(n) {
	; Desktop count starts at 1 for this script, but at 0 for Windows.
	n -= 1

	; winIDList contains a list of windows IDs ordered from the top to the bottom for each desktop.
	WinGet winIDList, list
	Loop % winIDList {
		windowID := % winIDList%A_Index%
		windowIsOnDesktop := DllCall(IsWindowOnDesktopNumberProc, UInt, WindowID, UInt, n)
		; Select the first (and foremost) window which is in the specified desktop.
		if (WindowIsOnDesktop == 1) {
			return WindowID
		}
	}
}

_ShowTooltip(message := "") {
	params := {}
	params.message := message
	params.lifespan := TooltipsLifespan
	params.position := TooltipsCentered
	params.fontSize := TooltipsFontSize
	params.fontWeight := TooltipsFontInBold
	params.fontColor := TooltipsFontColor
	params.backgroundColor := TooltipsBackgroundColor
	Toast(params)
}

_ShowTooltipForDesktopSwitch(n := 1) {
	_ShowTooltip(_GetDesktopName(n))
}

_ShowTooltipForPinnedWindow(windowTitle) {
	_ShowTooltip("Window """ . _TruncateString(windowTitle, 30) . """ pinned.")
}

_ShowTooltipForUnpinnedWindow(windowTitle) {
	_ShowTooltip("Window """ . _TruncateString(windowTitle, 30) . """ unpinned.")
}

_ShowTooltipForPinnedApp(windowTitle) {
	_ShowTooltip("App """ . _TruncateString(windowTitle, 30) . """ pinned.")
}

_ShowTooltipForUnpinnedApp(windowTitle) {
	_ShowTooltip("App """ . _TruncateString(windowTitle, 30) . """ unpinned.")
}

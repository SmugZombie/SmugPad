#SingleInstance, off

; Create the sub-menus for the menu bar:
Menu, FileMenu, Add, &New, FileNew
Menu, FileMenu, Add, &Open, FileOpen
Menu, FileMenu, Add, &Save, FileSave
Menu, FileMenu, Add, Save &As, FileSaveAs
Menu, FileMenu, Add  ; Separator line.
Menu, FileMenu, Add, E&xit, FileExit
Menu, HelpMenu, Add, &About, HelpAbout

; Create the menu bar by attaching the sub-menus to it:
Menu, MyMenuBar, Add, &File, :FileMenu
Menu, MyMenuBar, Add, &Help, :HelpMenu

; Attach the menu bar to the window:
Gui, Menu, MyMenuBar

AppName := "SmugPad"
AppDeveloper := "Ron Egli <ron@r-egli.com> (github.com/smugzombie)"
AppVersion := "0.15.0"
Hash := ""
ForceSave := 0
StartingDirectory := A_ScriptDir . "\cache\" 
checkDir(StartingDirectory)
CurrentId := guidGen()

; Create the main Edit control and display the window:
Gui, +Resize  ; Make the window resizable.
Gui, Add, Edit, vMainEdit WantTab W600 R20 gPrepToSave,
Gui, Font, s5
;Gui, Add, Text, vStatus W250, Unsaved
Gui, Show,, %AppName% - %CurrentId%
CurrentFileName := StartingDirectory . CurrentId . ".txt"  ; Indicate that there is no current file.
goSub, SaveCurrentFile
return

FileNew:
GuiControl,, MainEdit  ; Clear the Edit control.
return

FileOpen:
Gui +OwnDialogs  ; Force the user to dismiss the FileSelectFile dialog before returning to the main window.
FileSelectFile, SelectedFileName, 3, %StartingDirectory%, Open File, Text Documents (*.txt)
if not SelectedFileName  ; No file selected.
    return
Gosub FileRead
return

FileRead:  ; Caller has set the variable SelectedFileName for us.
FileRead, MainEdit, %SelectedFileName%  ; Read the file's contents into the variable.
if ErrorLevel
{
    MsgBox Could not open "%SelectedFileName%".
    return
}
GuiControl,, MainEdit, %MainEdit%  ; Put the text into the control.
CurrentFileName := SelectedFileName
Gui, Show,, %CurrentFileName%   ; Show file name in title bar.
return

FileSave:
if not CurrentFileName   ; No filename selected yet, so do Save-As instead.
    Goto FileSaveAs
Gosub SaveCurrentFile
return

FileSaveAs:
Gui +OwnDialogs  ; Force the user to dismiss the FileSelectFile dialog before returning to the main window.
FileSelectFile, SelectedFileName, S16, %StartingDirectory%, Save File, Text Documents (*.txt)
if not SelectedFileName  ; No file selected.
    return
CurrentFileName := SelectedFileName
ForceSave := 1
Gosub SaveCurrentFile
return

PrepToSave:
    SetTimer, SaveCurrentFile, 2000
return

SaveCurrentFile:  ; Caller has ensured that CurrentFileName is not blank.
GuiControlGet, MainEdit  ; Retrieve the contents of the Edit control.
if(ForceSave == 1){
    ; Do it!
}else{
    ; If we don't have anything to save, don't save it
    if(MainEdit == "") {
        Sleep 10000
        goSub, SaveCurrentFile
        return
    }
    ; Check to see if the hash changed since last time
    if(Hash == md5(MainEdit)){
        Sleep 10000
        goSub, SaveCurrentFile
        return
    }  
}

if FileExist(CurrentFileName)
{
    FileDelete %CurrentFileName%
    if ErrorLevel
    {
        MsgBox The attempt to overwrite "%CurrentFileName%" failed.
        return
    }
}

ForceSave := 0
Hash := md5(MainEdit)

FileAppend, %MainEdit%, %CurrentFileName%  ; Save the contents to the file.
; Upon success, Show file name in title bar (in case we were called by FileSaveAs):

StringReplace, CleanFileName, CurrentFileName, %StartingDirectory%, , All
FormatTime, TimeString

Gui, Show, NoActivate, %CleanFileName% - (Saved: %TimeString%)
;GuiControl,, Status, Last Saved: (%TimeString%)
Sleep 5000
goSub, SaveCurrentFile
return

HelpAbout:
Gui, About:+owner1  ; Make the main window (Gui #1) the owner of the "about box".
Gui +Disabled  ; Disable main window.
Gui, About:Add, Text,, Text for about box.
Gui, About:Add, Button, Default, OK
Gui, About:Show
return

AboutButtonOK:  ; This section is used by the "about box" above.
AboutGuiClose:
AboutGuiEscape:
Gui, 1:-Disabled  ; Re-enable the main window (must be done prior to the next step).
Gui Destroy  ; Destroy the about box.
return

GuiDropFiles:  ; Support drag & drop.
Loop, Parse, A_GuiEvent, `n
{
    SelectedFileName := A_LoopField  ; Get the first file only (in case there's more than one).
    break
}
Gosub FileRead
return

GuiSize:
if (ErrorLevel = 1)  ; The window has been minimized. No action needed.
    return
; Otherwise, the window has been resized or maximized. Resize the Edit control to match.
NewWidth := A_GuiWidth - 20
NewHeight := A_GuiHeight - 20
GuiControl, Move, MainEdit, W%NewWidth% H%NewHeight%
return

FileExit:     ; User chose "Exit" from the File menu.
GuiClose:  ; User closed the window.
ExitApp

checkDir(dir){
    If !FileExist(dir) {
        FileCreateDir, %dir%
        If ErrorLevel
            MsgBox, 48, Error, An error occurred when creating the directory.`n`n%dir%
    }
}

guidGen(){
    shellobj := ComObjCreate("Scriptlet.TypeLib")
    shellexec := shellobj.GUID
    StringReplace, shellexec, shellexec, {, , All
    StringReplace, shellexec, shellexec, }, , All
    return shellexec
}

b64Encode(string)
{
    VarSetCapacity(bin, StrPut(string, "UTF-8")) && len := StrPut(string, &bin, "UTF-8") - 1 
    if !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", 0, "uint*", size))
        throw Exception("CryptBinaryToString failed", -1)
    VarSetCapacity(buf, size << 1, 0)
    if !(DllCall("crypt32\CryptBinaryToString", "ptr", &bin, "uint", len, "uint", 0x1, "ptr", &buf, "uint*", size))
        throw Exception("CryptBinaryToString failed", -1)
    return StrGet(&buf)
}

b64Decode(string)
{
    if !(DllCall("crypt32\CryptStringToBinary", "ptr", &string, "uint", 0, "uint", 0x1, "ptr", 0, "uint*", size, "ptr", 0, "ptr", 0))
        throw Exception("CryptStringToBinary failed", -1)
    VarSetCapacity(buf, size, 0)
    if !(DllCall("crypt32\CryptStringToBinary", "ptr", &string, "uint", 0, "uint", 0x1, "ptr", &buf, "uint*", size, "ptr", 0, "ptr", 0))
        throw Exception("CryptStringToBinary failed", -1)
    return StrGet(&buf, size, "UTF-8")
}

md5(string)     ;   // by SKAN | rewritten by jNizM
{
    hModule := DllCall("LoadLibrary", "Str", "advapi32.dll", "Ptr")
    , VarSetCapacity(MD5_CTX, 104, 0), DllCall("advapi32\MD5Init", "Ptr", &MD5_CTX)
    , DllCall("advapi32\MD5Update", "Ptr", &MD5_CTX, "AStr", string, "UInt", StrLen(string))
    , DllCall("advapi32\MD5Final", "Ptr", &MD5_CTX)
    loop, 16
        o .= Format("{:02" (case ? "X" : "x") "}", NumGet(MD5_CTX, 87 + A_Index, "UChar"))
    DllCall("FreeLibrary", "Ptr", hModule)
    StringLower, o,o
    return o
}

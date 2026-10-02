; Polderrace 3D, Windows installer (NSIS 3). Built by .github/workflows/godot.yml:
;   makensis -DVERSION=<n> -DEXE=<path to Polderrace.exe> -DREADME=<path to README.md> -DOUTFILE=<setup.exe> polderrace.nsi
; Installs for the current user only (no administrator rights needed) into %LOCALAPPDATA%\Programs\Polderrace,
; puts "Polderrace 3D" on the desktop and in the Start menu, and registers an uninstaller under Apps & features.
; Uninstalling keeps the save data (garage, career, records in %APPDATA%\Godot\app_userdata\Polderrace 3D).

!ifndef VERSION
  !define VERSION "dev"
!endif
!ifndef EXE
  !define EXE "..\build\windows\Polderrace.exe"
!endif
!ifndef README
  !define README "..\README.md"
!endif
!ifndef OUTFILE
  !define OUTFILE "..\build\installer\Polderrace-Setup.exe"
!endif
!define APP "Polderrace 3D"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Polderrace3D"

Unicode true
Name "${APP}"
OutFile "${OUTFILE}"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\Polderrace"
InstallDirRegKey HKCU "${UNINST_KEY}" "InstallLocation"
SetCompressor /SOLID lzma
BrandingText "${APP} ${VERSION}"

!include "MUI2.nsh"
!define MUI_ICON "..\icon.ico"
!define MUI_UNICON "..\icon.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\Polderrace.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Polderrace nu starten"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Dutch"

Section "Polderrace"
  SetOutPath "$INSTDIR"
  File "/oname=Polderrace.exe" "${EXE}"
  File "/oname=LEESMIJ.md" "${README}"
  WriteUninstaller "$INSTDIR\Verwijderen.exe"
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\Polderrace.exe"
  CreateShortcut "$SMPROGRAMS\${APP}.lnk" "$INSTDIR\Polderrace.exe"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${APP}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "Yip"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\Polderrace.exe"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Verwijderen.exe"'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\${APP}.lnk"
  Delete "$SMPROGRAMS\${APP}.lnk"
  Delete "$INSTDIR\Polderrace.exe"
  Delete "$INSTDIR\LEESMIJ.md"
  Delete "$INSTDIR\Verwijderen.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINST_KEY}"
SectionEnd

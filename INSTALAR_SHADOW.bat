@echo off
chcp 65001 >nul
title Instalador Trip Rate SHADOW
setlocal

rem === CAMBIAR: usuario y repositorio de GitHub ===
set "USUARIO=relp1124el-a11y"
set "REPO=shadow-descargas"

set "APK_URL=https://github.com/%USUARIO%/%REPO%/releases/latest/download/SHADOW.apk"
set "PT_URL=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
set "PAQUETE=com.rick.triprate.shadow"
set "SERVICIO=com.rick.triprate.shadow/com.rick.triprate.AccessibilityReaderService"
set "DIR=%~dp0shadow_tools"
if not exist "%DIR%" mkdir "%DIR%"

echo.
echo === PASO 1: herramientas de Android (ADB) ===
if exist "%DIR%\platform-tools\adb.exe" goto adb_listo
echo Descargando ADB, espera un momento...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest '%PT_URL%' -OutFile '%DIR%\pt.zip'"
powershell -NoProfile -Command "Expand-Archive -Force '%DIR%\pt.zip' '%DIR%'"
del "%DIR%\pt.zip" >nul 2>&1
if not exist "%DIR%\platform-tools\adb.exe" goto error_adb
:adb_listo
echo ADB listo.

echo.
echo === PASO 2: descargando SHADOW ===
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest '%APK_URL%' -OutFile '%DIR%\SHADOW.apk'"
if not exist "%DIR%\SHADOW.apk" goto error_apk
echo APK descargado.

echo.
echo === PASO 3: activar la depuracion USB en el celular ===
echo   1. Ajustes ^> Acerca del telefono ^> Informacion de software.
echo   2. Toca 7 veces "Numero de compilacion" (pedira el PIN).
echo   3. Ajustes ^> Opciones de desarrollador ^> activa "Depuracion por USB".
echo   4. Conecta el cable USB al computador.
echo   5. Cuando el celular pregunte "Permitir depuracion USB", toca PERMITIR.
echo.
cd /d "%DIR%\platform-tools"
adb start-server >nul 2>&1

:esperar
set "EST="
for /f "skip=1 tokens=2" %%a in ('adb devices') do if not defined EST set "EST=%%a"
if "%EST%"=="device" goto conectado
if "%EST%"=="unauthorized" goto no_autorizado
echo Esperando el celular conectado con depuracion USB...
timeout /t 3 >nul
goto esperar

:no_autorizado
echo Mira la pantalla del celular y toca PERMITIR.
timeout /t 3 >nul
goto esperar

:conectado
echo Celular detectado.

echo.
echo === PASO 4: instalando SHADOW ===
adb install -r "%DIR%\SHADOW.apk" 2>&1 | find "Success" >nul
if errorlevel 1 goto error_install
echo SHADOW instalado.

echo.
echo === PASO 5: permisos ===
adb shell appops set %PAQUETE% SYSTEM_ALERT_WINDOW allow
adb shell appops set %PAQUETE% GET_USAGE_STATS allow
adb shell pm grant %PAQUETE% android.permission.POST_NOTIFICATIONS >nul 2>&1

set "ACTUAL="
for /f "delims=" %%s in ('adb shell settings get secure enabled_accessibility_services') do set "ACTUAL=%%s"
echo %ACTUAL% | find "AccessibilityReaderService" >nul
if not errorlevel 1 goto acc_ok
if "%ACTUAL%"=="null" (set "NUEVO=%SERVICIO%") else (set "NUEVO=%ACTUAL%:%SERVICIO%")
adb shell settings put secure enabled_accessibility_services "%NUEVO%"
adb shell settings put secure accessibility_enabled 1
:acc_ok

adb shell monkey -p %PAQUETE% -c android.intent.category.LAUNCHER 1 >nul 2>&1

echo.
echo ================================================
echo  LISTO. SHADOW quedo instalado y abierto.
echo  Si algun permiso no quedo activo, la app lo pedira.
echo  Ya puedes desconectar el cable y desactivar
echo  la depuracion USB.
echo ================================================
pause
exit /b 0

:error_adb
echo ERROR: no se pudo descargar ADB. Revisa tu internet y vuelve a abrir este archivo.
pause
exit /b 1

:error_apk
echo ERROR: no se pudo descargar el APK. Revisa tu internet y vuelve a abrir este archivo.
pause
exit /b 1

:error_install
echo ERROR: la instalacion fallo. Causas comunes: otra version firmada distinta
echo instalada en el celular (desinstalala primero) o poco espacio.
pause
exit /b 1

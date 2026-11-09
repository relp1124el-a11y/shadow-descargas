@echo off
chcp 65001 >nul
title Instalador Trip Rate SHADOW
setlocal EnableDelayedExpansion

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

cd /d "%DIR%\platform-tools"
adb start-server >nul 2>&1

rem Si la depuracion ya esta activa no hace falta ninguna guia.
call :estado_adb
if "%EST%"=="device" goto conectado

echo.
echo === PASO 3: reconocer tu celular ===
echo Conecta el celular al computador con el cable USB.
echo Si el celular pregunta para que usar el USB, elige "Transferir archivos".
echo.
pause

set "MARCA="
set "EQUIPO="
rem Antes de activar la depuracion, Windows solo puede ver la marca por el cable y, a veces, el nombre del equipo.
for /f "usebackq tokens=1,* delims=|" %%a in (`powershell -NoProfile -Command "$m=@{'04E8'='SAMSUNG';'2717'='XIAOMI';'22B8'='MOTOROLA';'12D1'='HUAWEI';'22D9'='OPPO';'2A70'='ONEPLUS';'2D95'='VIVO';'18D1'='GOOGLE';'1004'='LG';'0FCE'='SONY';'19D2'='ZTE'}; $d=Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -match 'VID_([0-9A-F]{4})' -and $m.ContainsKey($Matches[1]) } | Select-Object -First 1; if($d){ $null=$d.DeviceID -match 'VID_([0-9A-F]{4})'; $w=Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPClass -eq 'WPD' } | Select-Object -First 1; Write-Output ($m[$Matches[1]]+'|'+$w.Name) }"`) do (
    set "MARCA=%%a"
    set "EQUIPO=%%b"
)

if defined MARCA (
    echo Detecte un celular marca !MARCA! !EQUIPO!
    echo.
    goto mostrar_guia
)

:elegir_marca
echo No pude reconocer el celular por el cable. Elige la marca:
echo   1. Samsung
echo   2. Xiaomi, Redmi o POCO
echo   3. Motorola
echo   4. Huawei u Honor
echo   5. OPPO o Realme
echo   6. vivo
echo   7. Tecno, Infinix o itel
echo   8. Otra marca
set "OP="
set /p "OP=Escribe el numero y presiona Enter: "
if "%OP%"=="1" set "MARCA=SAMSUNG"
if "%OP%"=="2" set "MARCA=XIAOMI"
if "%OP%"=="3" set "MARCA=MOTOROLA"
if "%OP%"=="4" set "MARCA=HUAWEI"
if "%OP%"=="5" set "MARCA=OPPO"
if "%OP%"=="6" set "MARCA=VIVO"
if "%OP%"=="7" set "MARCA=TECNO"
if "%OP%"=="8" set "MARCA=OTRA"
if not defined MARCA goto elegir_marca

:mostrar_guia
echo.
echo === PASO 4: activar la depuracion USB en tu celular ===
echo Los nombres pueden variar un poco segun la version de tu telefono.
echo.
call :guia_%MARCA% 2>nul || call :guia_OTRA
echo.
echo Al final, en el celular saldra "Permitir depuracion USB": marca
echo "Permitir siempre" y toca PERMITIR.
echo.

:esperar
call :estado_adb
if "%EST%"=="device" goto conectado
if "%EST%"=="unauthorized" goto no_autorizado
echo Esperando el celular con la depuracion USB activa...
timeout /t 3 >nul
goto esperar

:no_autorizado
echo Mira la pantalla del celular y toca PERMITIR.
timeout /t 3 >nul
goto esperar

:conectado
rem Ya con depuracion, se puede leer el telefono de verdad.
for /f "delims=" %%m in ('adb shell getprop ro.product.manufacturer') do set "FAB=%%m"
for /f "delims=" %%m in ('adb shell getprop ro.product.model') do set "MODELO=%%m"
for /f "delims=" %%m in ('adb shell getprop ro.build.version.release') do set "ANDROID=%%m"
echo.
echo Celular conectado: !FAB! !MODELO!, Android !ANDROID!

echo.
echo === PASO 5: instalando SHADOW ===
adb install -r "%DIR%\SHADOW.apk" 2>&1 | find "Success" >nul
if errorlevel 1 goto error_install
echo SHADOW instalado.

echo.
echo === PASO 6: permisos ===
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

:estado_adb
set "EST="
for /f "skip=1 tokens=2" %%a in ('adb devices') do if not defined EST set "EST=%%a"
exit /b 0

:guia_SAMSUNG
echo   1. Ajustes ^> Acerca del telefono ^> Informacion de software.
echo   2. Toca 7 veces "Numero de compilacion". Te pedira el PIN.
echo   3. Vuelve a Ajustes ^> Opciones de desarrollador (esta al final).
echo   4. Activa "Depuracion por USB".
echo   Si existe "Bloqueador automatico" en Ajustes ^> Seguridad y privacidad,
echo   apagalo mientras instalas: bloquea la instalacion por cable.
exit /b 0

:guia_XIAOMI
echo   1. Ajustes ^> Sobre el telefono.
echo   2. Toca 7 veces "Version de HyperOS" o "Version de MIUI".
echo   3. Ajustes ^> Ajustes adicionales ^> Opciones de desarrollador.
echo   4. Activa "Depuracion USB" y tambien "Instalar via USB".
echo   Xiaomi puede pedir iniciar sesion en tu cuenta y usar datos moviles.
exit /b 0

:guia_MOTOROLA
echo   1. Ajustes ^> Acerca del telefono.
echo   2. Toca 7 veces "Numero de compilacion".
echo   3. Ajustes ^> Sistema ^> Opciones de desarrollador.
echo   4. Activa "Depuracion por USB".
exit /b 0

:guia_HUAWEI
echo   1. Ajustes ^> Acerca del telefono.
echo   2. Toca 7 veces "Numero de compilacion".
echo   3. Ajustes ^> Sistema y actualizaciones ^> Opciones de desarrollador.
echo   4. Activa "Depuracion USB".
exit /b 0

:guia_OPPO
echo   1. Ajustes ^> Acerca del dispositivo ^> Version.
echo   2. Toca 7 veces "Numero de compilacion".
echo   3. Ajustes ^> Ajustes adicionales ^> Opciones de desarrollador.
echo   4. Activa "Depuracion USB".
exit /b 0

:guia_ONEPLUS
goto guia_OPPO

:guia_VIVO
echo   1. Ajustes ^> Mas ajustes ^> Acerca del telefono.
echo   2. Toca 7 veces "Numero de compilacion" o "Version de software".
echo   3. Ajustes ^> Mas ajustes ^> Opciones de desarrollador.
echo   4. Activa "Depuracion USB".
exit /b 0

:guia_TECNO
echo   1. Ajustes ^> Mi telefono o Acerca del telefono.
echo   2. Toca 7 veces "Numero de compilacion".
echo   3. Ajustes ^> Sistema ^> Opciones de desarrollador.
echo   4. Activa "Depuracion USB".
exit /b 0

:guia_GOOGLE
echo   1. Ajustes ^> Informacion del telefono.
echo   2. Toca 7 veces "Numero de compilacion".
echo   3. Ajustes ^> Sistema ^> Opciones para desarrolladores.
echo   4. Activa "Depuracion por USB".
exit /b 0

:guia_OTRA
echo   1. En Ajustes busca "Acerca del telefono".
echo   2. Toca 7 veces "Numero de compilacion". Si no lo ves, usa la
echo      lupa de Ajustes y escribe "compilacion".
echo   3. En la lupa de Ajustes escribe "desarrollador" y entra.
echo   4. Activa "Depuracion USB".
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

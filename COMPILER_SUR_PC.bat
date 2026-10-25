@echo off
chcp 65001 >nul
title Compilation Automatique APK - OptiFile Manager
echo ============================================================================
echo        CREATION AUTOMATIQUE DE L'APK OPTIFILE MANAGER (ANDROID)
echo ============================================================================
echo.

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Flutter n'est pas detecte sur cet ordinateur.
    echo Si vous ne souhaitez rien installer sur votre PC, utilisez la methode
    echo "Sans installation (Cloud GitHub Actions)" expliquee dans le guide !
    echo.
    pause
    exit /b 1
)

echo [1/4] Generation de la structure native Android/iOS (Gradle)...
call flutter create --org com.example --project-name optifile_manager build_workspace
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Echec lors de l'initialisation du projet Flutter.
    pause
    exit /b 1
)

echo [2/4] Injection du code source OptiFile et des permissions...
copy /Y "sources_optifile\pubspec.yaml" "build_workspace\pubspec.yaml" >nul
copy /Y "sources_optifile\main.dart" "build_workspace\lib\main.dart" >nul
copy /Y "sources_optifile\AndroidManifest.xml" "build_workspace\android\app\src\main\AndroidManifest.xml" >nul
copy /Y "sources_optifile\MainActivity.kt" "build_workspace\android\app\src\main\kotlin\com\example\optifile_manager\MainActivity.kt" >nul

cd build_workspace

echo [3/4] Telechargement des librairies (photo_manager, storage_space...)...
call flutter pub get

echo [4/4] Compilation du fichier APK en cours (patientez 1 a 2 minutes)...
call flutter build apk --release

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "..\OptiFile_v1.0.0.apk" >nul
    cd ..
    echo.
    echo ============================================================================
    echo [SUCCES] Votre fichier OptiFile_v1.0.0.apk a ete cree avec succes !
    echo Il se trouve directement dans ce dossier : %CD%\OptiFile_v1.0.0.apk
    echo ============================================================================
    explorer.exe /select,"%CD%\OptiFile_v1.0.0.apk"
) else (
    echo.
    echo [ERREUR] La compilation n'a pas pu aboutir. Verifiez qu'Android Studio est installe.
)

pause

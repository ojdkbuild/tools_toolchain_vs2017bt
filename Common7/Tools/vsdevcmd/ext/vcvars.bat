
if "%VSCMD_TEST%" NEQ "" goto :test
if "%VSCMD_ARG_CLEAN_ENV%" NEQ "" goto :clean_env

@REM ------------------------------------------------------------------------
@REM Support user-specified version of the Visual C++ Toolset to initialize.
@REM Initialization of the environment for different VC++ versions are
@REM mutually exclusive, so we use this script to invoke the correct script
@REM based upon user-specified versioning. 
@REM The latest/default toolset is read from :
@REM    * Auxiliary\Build\Microsoft.VCToolsVersion.default.txt
@REM The latest/default redist directory is read from :
@REM    * Auxiliary\Build\Microsoft.VCRedistVersion.default.txt

if "%VSCMD_ARG_VCVARS_VER%" NEQ "" (
    set "__VCVARS_VERSION=%VSCMD_ARG_VCVARS_VER%"
) else if "%VCVARS_USER_VERSION%" NEQ "" (
    if "%VSCMD_DEBUG%" GEQ "1" @echo [DEBUG:%~nx0] VCVARS_USER_VERSION = "%VCVARS_USER_VERSION%"
    set "__VCVARS_VERSION=%VCVARS_USER_VERSION%"
) else if "%VCToolsVersion%" NEQ "" (
    if "%VSCMD_DEBUG%" GEQ "1" @echo [DEBUG:%~nx0] VCToolsVersion = "%VCToolsVersion%"
    set "__VCVARS_VERSION=%VCToolsVersion%"
    set "__VSCMD_PREINIT_VCToolsVersion=%VCToolsVersion%"
)

@REM Support the VS 2015 Visual C++ Toolset
if "%__VCVARS_VERSION%" == "14.0" (
    goto :vcvars140_version
)

@REM If VCVARS_VERSION was not specified, then default initialize the environment
if "%__VCVARS_VERSION%" == "" (
    goto :check_platform
)

:check_vcvars_ver_exists
@REM If we've reached this point, we've detected an override of the toolset version.

@REM Check if full version was provided and the target directory exists. If so, we can proceed to environment setup.
if EXIST "%VSINSTALLDIR%\VC\Tools\MSVC\%__VCVARS_VERSION%" (
    goto :check_platform
)

@REM Directory was not found. Check for MAJOR.MINOR.VERSION formatted string. If it is
@REM in this form, we need an exact match only and should ERROR otherwise.  We'll check
@REM for this by looking for two '.' in the version number as a first approximation.
for /F "tokens=1,2,* delims=." %%a in ("%__VCVARS_VERSION%") DO (
   if "%%c" NEQ "" (
       @echo [ERROR:%~nx0] Version '%__VCVARS_VERSION%' is not valid; directory does not exist
       set __VCVARS_SCRIPT_ERROR=1
       goto :end
   )
)

@REM Check if a partial version was provided (e.g. MAJOR.MINOR only).  In this case,
@REM select the first directory we find that matches that prefix.
set __VCVARS_VER_TMP=
setlocal enableDelayedExpansion
for /F %%a IN ('dir "%VSINSTALLDIR%\VC\Tools\MSVC\" /b /ad-h /o-n') DO (
    set __VCVARS_DIR=%%a
    set __VCVARS_DIR_REP=!__VCVARS_DIR:%__VCVARS_VERSION%=_vcvars_found!
    if "!__VCVARS_DIR!" NEQ "!__VCVARS_DIR_REP!" (
        set "__VCVARS_VER_TMP=!__VCVARS_DIR!"
        goto :check_vcvars_ver_exists_end
    )
)
:check_vcvars_ver_exists_end 

endlocal & set __VCVARS_VER_TMP=%__VCVARS_VER_TMP%

@REM go to :check_platform if a version match was found
if "%__VCVARS_VER_TMP%" NEQ "" (
    set "__VCVARS_VERSION=%__VCVARS_VER_TMP%"
    goto :check_platform
)

@echo [ERROR:%~nx0] Toolset directory for version '%__VCVARS_VERSION%' was not found.
set __VCVARS_SCRIPT_ERROR=1
goto :end

@REM ------------------------------------------------------------------------
:check_platform

if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Checking architecture { host , tgt } : { %VSCMD_ARG_HOST_ARCH% , %VSCMD_ARG_TGT_ARCH% }

call :detect_env_overrides

@REM Generate folder paths
if /I "%VSCMD_ARG_HOST_ARCH%" == "x86" (
    set __VCVARS_HOST_DIR=\HostX86
    set __VCVARS_HOST_NATIVEDIR=\x86
)
if /I "%VSCMD_ARG_HOST_ARCH%" == "x64" (
    set __VCVARS_HOST_DIR=\HostX64
    set __VCVARS_HOST_NATIVEDIR=\x64
)
if /I "%VSCMD_ARG_HOST_ARCH%" == "arm" (
    set __VCVARS_HOST_DIR=\HostARM
    set __VCVARS_HOST_NATIVEDIR=\arm
)
if /I "%VSCMD_ARG_HOST_ARCH%" == "arm64" (
    set __VCVARS_HOST_DIR=\HostARM64
    set __VCVARS_HOST_NATIVEDIR=\arm64
)

if /I "%VSCMD_ARG_TGT_ARCH%" == "x86" set __VCVARS_TARGET_DIR=\x86
if /I "%VSCMD_ARG_TGT_ARCH%" == "x64" set __VCVARS_TARGET_DIR=\x64
if /I "%VSCMD_ARG_TGT_ARCH%" == "arm" set __VCVARS_TARGET_DIR=\ARM
if /I "%VSCMD_ARG_TGT_ARCH%" == "arm64" set __VCVARS_TARGET_DIR=\ARM64

if "%__VCVARS_HOST_DIR%" == "" (
    @echo [ERROR:%~nx0] Unknown host architecture '%VSCMD_ARG_HOST_ARCH%'
    set __VCVARS_SCRIPT_ERROR=1
    goto :end
)

if "%__VCVARS_TARGET_DIR%" == "" (
    @echo [ERROR:%~nx0] Unknown target architecture '%VSCMD_ARG_TGT_ARCH%'
    set __VCVARS_SCRIPT_ERROR=1
    goto :end
)

set "__VCVARS_BIN_DIR=%__VCVARS_HOST_DIR%%__VCVARS_TARGET_DIR%"
set "__VCVARS_LIB_DIR=%__VCVARS_TARGET_DIR%"

goto :vcvars_environment

@REM ------------------------------------------------------------------------
:detect_env_overrides

set "__VCVARS_NATIVE_BIN_OVERRIDE="
set "__VCVARS_BIN_OVERRIDE="
set "__VCVARS_VC_LIB_DESKTOP_OVERRIDE="
set "__VCVARS_VC_LIB_STORE_OVERRIDE="
set "__VCVARS_VC_LIB_ONECORE_OVERRIDE="
set "__VCVARS_ATL_LIB_OVERRIDE="
set "__VCVARS_IFC_PATH_OVERRIDE="
set "__VCVARS_VC_INCLUDE_OVERRIDE="
set "__VCVARS_ATLMFC_INCLUDE_OVERRIDE="
set "__VCVARS_NO_OVERRIDE="

set "VCLIB_GENERAL_OVERRIDE="

@REM -- Setting binary path overrides --
@REM Set binary overrides for x86 host
if /I "%VSCMD_ARG_HOST_ARCH%" == "x86" (
    if "%VC_ExecutablePath_x86_x86%" NEQ "" (
        set "__VCVARS_NATIVE_BIN_OVERRIDE=%VC_ExecutablePath_x86_x86%"
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "x86" (
        if "%VC_ExecutablePath_x86_x86%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_x86_x86%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "x64" (
        if "%VC_ExecutablePath_x86_x64%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_x86_x64%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "ARM" (
        if "%VC_ExecutablePath_x86_ARM%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_x86_ARM%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "ARM64" (
        if "%VC_ExecutablePath_x86_ARM64%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_x86_ARM64%"
        )
    )
)

@REM Set binary overrides for x64 host
if /I "%VSCMD_ARG_HOST_ARCH%" == "x64" (
    if "%VC_ExecutablePath_x64_x64%" NEQ "" (
        set "__VCVARS_NATIVE_BIN_OVERRIDE=%VC_ExecutablePath_x64_x64%"
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "x86" (
        if "%VC_ExecutablePath_x64_x86%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_x64_x86%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "x64" (
        if "%VC_ExecutablePath_x64_x64%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_x64_x64%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "ARM" (
        if "%VC_ExecutablePath_x64_ARM%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_x64_ARM%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "ARM64" (
        if "%VC_ExecutablePath_x64_ARM64%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_x64_ARM64%"
        )
    )
)

@REM Set binary overrides for ARM host
if /I "%VSCMD_ARG_HOST_ARCH%" == "ARM" (
    if "%VC_ExecutablePath_ARM_ARM%" NEQ "" (
        set "__VCVARS_NATIVE_BIN_OVERRIDE=%VC_ExecutablePath_ARM_ARM%"
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "x86" (
        if "%VC_ExecutablePath_ARM_x86%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_ARM_x86%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "x64" (
        if "%VC_ExecutablePath_ARM_x64%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_ARM_x64%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "ARM" (
        if "%VC_ExecutablePath_ARM_ARM%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_ARM_ARM%"
        )
    )

    if /I "%VSCMD_ARG_TGT_ARCH%" == "ARM64" (
        if "%VC_ExecutablePath_ARM_ARM64%" NEQ "" (
            set "__VCVARS_BIN_OVERRIDE=%VC_ExecutablePath_ARM_ARM64%"
        )
    )
)

@REM -- Setting library path overrides --
@REM Set library overrides for x86 target
if /I "%VSCMD_ARG_TGT_ARCH%" == "x86" (
    if "%VC_LibraryPath_VC_x86%" NEQ "" (
         set "VCLIB_GENERAL_OVERRIDE=%VC_LibraryPath_VC_x86%"
    )

    if "%VC_LibraryPath_VC_x86_Desktop%" NEQ "" (
         set "__VCVARS_VC_LIB_DESKTOP_OVERRIDE=%VC_LibraryPath_VC_x86_Desktop%"
    )

    if "%VC_LibraryPath_VC_x86_Store%" NEQ "" (
         set "__VCVARS_VC_LIB_STORE_OVERRIDE=%VC_LibraryPath_VC_x86_Store%"
    )

    if "%VC_LibraryPath_VC_x86_OneCore%" NEQ "" (
         set "__VCVARS_VC_LIB_ONECORE_OVERRIDE=%VC_LibraryPath_VC_x86_OneCore%"
    )

    if "%VC_LibraryPath_ATL_x86%" NEQ "" (
         set "__VCVARS_ATL_LIB_OVERRIDE=%VC_LibraryPath_ATL_x86%"
    )
)

@REM Set overrides for x64 target
if /I "%VSCMD_ARG_TGT_ARCH%" == "x64" (
    if "%VC_LibraryPath_VC_x64%" NEQ "" (
         set "VCLIB_GENERAL_OVERRIDE=%VC_LibraryPath_VC_x64%"
    )

    if "%VC_LibraryPath_VC_x64_Desktop%" NEQ "" (
         set "__VCVARS_VC_LIB_DESKTOP_OVERRIDE=%VC_LibraryPath_VC_x64_Desktop%"
    )

    if "%VC_LibraryPath_VC_x64_Store%" NEQ "" (
         set "__VCVARS_VC_LIB_STORE_OVERRIDE=%VC_LibraryPath_VC_x64_Store%"
    )

    if "%VC_LibraryPath_VC_x64_OneCore%" NEQ "" (
         set "__VCVARS_VC_LIB_ONECORE_OVERRIDE=%VC_LibraryPath_VC_x64_OneCore%"
    )

    if "%VC_LibraryPath_ATL_x64%" NEQ "" (
         set "__VCVARS_ATL_LIB_OVERRIDE=%VC_LibraryPath_ATL_x64%"
    )
)

@REM Set overrides for ARM target
if /I "%VSCMD_ARG_TGT_ARCH%" == "ARM" (
    if "%VC_LibraryPath_VC_ARM%" NEQ "" (
         set "VCLIB_GENERAL_OVERRIDE=%VC_LibraryPath_VC_ARM%"
    )

    if "%VC_LibraryPath_VC_ARM_Desktop%" NEQ "" (
         set "__VCVARS_VC_LIB_DESKTOP_OVERRIDE=%VC_LibraryPath_VC_ARM_Desktop%"
    )

    if "%VC_LibraryPath_VC_ARM_Store%" NEQ "" (
         set "__VCVARS_VC_LIB_STORE_OVERRIDE=%VC_LibraryPath_VC_ARM_Store%"
    )

    if "%VC_LibraryPath_VC_ARM_OneCore%" NEQ "" (
         set "__VCVARS_VC_LIB_ONECORE_OVERRIDE=%VC_LibraryPath_VC_ARM_OneCore%"
    )

    if "%VC_LibraryPath_ATL_ARM%" NEQ "" (
         set "__VCVARS_ATL_LIB_OVERRIDE=%VC_LibraryPath_ATL_ARM%"
    )
)

@REM Set overrides for ARM64 target
if /I "%VSCMD_ARG_TGT_ARCH%" == "ARM64" (
    if "%VC_LibraryPath_VC_ARM64%" NEQ "" (
         set "VCLIB_GENERAL_OVERRIDE=%VC_LibraryPath_VC_ARM64%"
    )

    if "%VC_LibraryPath_VC_ARM64_Desktop%" NEQ "" (
         set "__VCVARS_VC_LIB_DESKTOP_OVERRIDE=%VC_LibraryPath_VC_ARM64_Desktop%"
    )

    if "%VC_LibraryPath_VC_ARM64_Store%" NEQ "" (
         set "__VCVARS_VC_LIB_STORE_OVERRIDE=%VC_LibraryPath_VC_ARM64_Store%"
    )

    if "%VC_LibraryPath_VC_ARM64_OneCore%" NEQ "" (
         set "__VCVARS_VC_LIB_ONECORE_OVERRIDE=%VC_LibraryPath_VC_ARM64_OneCore%"
    )

    if "%VC_LibraryPath_ATL_ARM64%" NEQ "" (
         set "__VCVARS_ATL_LIB_OVERRIDE=%VC_LibraryPath_ATL_ARM64%"
    )
)

@REM -- Setting includes path overrides --
if "%VC_IFCPath%" NEQ "" (
    set "__VCVARS_IFC_PATH_OVERRIDE=%VC_IFCPath%"
)

if "%VC_VC_IncludePath%" NEQ "" (
    set "__VCVARS_VC_INCLUDE_OVERRIDE=%VC_VC_IncludePath%"
)

if "%VC_ATLMFC_IncludePath%" NEQ "" (
    set "__VCVARS_ATLMFC_INCLUDE_OVERRIDE=%VC_ATLMFC_IncludePath%"
)

@REM Translate general VC Lib setting to specific.
if "%VCLIB_GENERAL_OVERRIDE%" NEQ "" (
    if /I "%_VC_Target_Library_Platform%"=="Desktop" (
        if "%__VCVARS_VC_LIB_DESKTOP_OVERRIDE%"=="" (
            if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Using general VC Library path "%VCLIB_GENERAL_OVERRIDE%" as Desktop VC Library path
            set "__VCVARS_VC_LIB_DESKTOP_OVERRIDE=%VCLIB_GENERAL_OVERRIDE%"
        )
    )

    if /I "%_VC_Target_Library_Platform%"=="Store" (
        if "%__VCVARS_VC_LIB_STORE_OVERRIDE%"=="" (
            if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Using general VC Library path "%VCLIB_GENERAL_OVERRIDE%" as Store VC Library path
            set "__VCVARS_VC_LIB_STORE_OVERRIDE=%VCLIB_GENERAL_OVERRIDE%"
        )
    )

    if /I "%_VC_Target_Library_Platform%"=="OneCore" (
        if "%__VCVARS_VC_LIB_ONECORE_OVERRIDE%"=="" (
            if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Using general VC Library path "%VCLIB_GENERAL_OVERRIDE%" as OneCore VC Library path
            set "__VCVARS_VC_LIB_ONECORE_OVERRIDE=%VCLIB_GENERAL_OVERRIDE%"
        )
    )
)

@REM Override for always-added x86 store references
if "%VC_LibraryPath_VC_x86_Store%" NEQ "" (
     set "__VCVARS_X86_STORE_REF_OVERRIDE=%VC_LibraryPath_VC_x86_Store%\references"
)

if "%VSCMD_DEBUG%" GEQ "2" (
    if "%__VCVARS_BIN_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected binaries path override: "%__VCVARS_BIN_OVERRIDE%"
    if "%__VCVARS_VC_LIB_DESKTOP_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected Desktop VC library path override: "%__VCVARS_VC_LIB_DESKTOP_OVERRIDE%"
    if "%__VCVARS_VC_LIB_STORE_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected Store VC library path override: "%__VCVARS_VC_LIB_STORE_OVERRIDE%"
    if "%__VCVARS_VC_LIB_ONECORE_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected OneCore VC library path override: "%__VCVARS_VC_LIB_ONECORE_OVERRIDE%"
    if "%__VCVARS_ATL_LIB_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected ATL library path override: "%__VCVARS_ATL_LIB_OVERRIDE%"
    if "%__VCVARS_IFC_PATH_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected IFC path override: "%__VCVARS_IFC_PATH_OVERRIDE%"
    if "%__VCVARS_VC_INCLUDE_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected VC includes path override: "%__VCVARS_VC_INCLUDE_OVERRIDE%"
    if "%__VCVARS_ATLMFC_INCLUDE_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected ATLMFC includes path override: "%__VCVARS_ATLMFC_INCLUDE_OVERRIDE%"
    if "%__VCVARS_X86_STORE_REF_OVERRIDE%" NEQ "" @echo [DEBUG:%~nx0] Detected x86 Store References path override: "%__VCVARS_X86_STORE_REF_OVERRIDE%"
)

set VCLIB_GENERAL_OVERRIDE=

exit /B 0

@REM ------------------------------------------------------------------------
:vcvars_environment

if NOT EXIST "%VSINSTALLDIR%VC\" (
    @REM Once this script has been moved into a VC++-specific component, this
    @REM debug message should be converted to an ERROR.
    if "%VSCMD_DEBUG%" GEQ "1" @echo [DEBUG:%~nx0] Could not find directory "%VSINSTALLDIR%VC\"
    goto :end
)

set "VCINSTALLDIR=%VSINSTALLDIR%VC\"
set "VCIDEInstallDir=%VSINSTALLDIR%Common7\IDE\VC\"

goto :export_env

@REM ------------------------------------------------------------------------
:test

set __VSCMD_TEST_FailCount=0

setlocal

@REM -- check for cl.exe on the path --
@echo [TEST:%~nx0] Checking for cl.exe...
where cl.exe > NUL 2>&1
if "%ERRORLEVEL%" NEQ "0" (
    @echo [ERROR:%~nx0] 'where cl.exe' failed
    set /A __VSCMD_TEST_FailCount=__VSCMD_TEST_FailCount+1
)

@REM -- Check for dumpbin.exe on the path.
@REM -- Verifies tools that only exist in native targeting directories
@REM -- are also on the path (for Cross Targeting scenarios)
@echo [TEST:%~nx0] Checking for dumpbin.exe...
where dumpbin.exe > NUL 2>&1
if "%ERRORLEVEL%" NEQ "0" (
    @echo [ERROR:%~nx0] 'where dumpbin.exe' failed
    set /A __VSCMD_TEST_FailCount=__VSCMD_TEST_FailCount+1
)

@REM -- check for msvcrt.lib in LIB --
@echo [TEST:%~nx0] Checking for msvcrt.lib in LIB...
set TEST_LIB=%LIB%
call :test_lib
if "%ERRORLEVEL%" NEQ "0" (
    @echo [ERROR:%~nx0] could not find 'msvcrt.lib' in LIB
    set /A __VSCMD_TEST_FailCount=__VSCMD_TEST_FailCount+1
)

@echo [TEST:%~nx0] Checking for vcruntime.h in INCLUDE...
@REM -- check for vcruntime.h in INCLUDE --
set TEST_INCLUDE=%INCLUDE%
call :test_include
if "%ERRORLEVEL%" NEQ "0" (
    @echo [ERROR:%~nx0] could not find 'vcruntime.h' in INCLUDE
    set /A __VSCMD_TEST_FailCount=__VSCMD_TEST_FailCount+1
)

@REM end local execution and export __vscmd_test_failcount out of the 'setlocal' region
endlocal & set __VSCMD_Test_FailCount=%__VSCMD_TEST_FailCount%

:test_end
if "%__VSCMD_TEST_FailCount%" NEQ "0" (
    set __VSCMD_TEST_FailCount=
    exit /B 1
)

exit /B 0

@REM ------------------------------------------------------------------------
:test_lib

if "%LIB%"=="" (
    @echo [ERROR:%~nx0] LIB environment variable was empty
    exit /B 1
)

for /F "tokens=1* delims=;" %%A in ("%TEST_LIB%") do (

   if EXIST "%%A\msvcrt.lib" (
      exit /B 0
   )

   set TEST_LIB=%%B
   goto :test_lib
)

exit /B 1

@REM ------------------------------------------------------------------------
:test_include
if "%INCLUDE%"=="" (
    @echo [ERROR:%~nx0] INCLUDE environment variable was empty
    exit /B 1
)

for /F "tokens=1* delims=;" %%A in ("%TEST_INCLUDE%") do (

   if EXIST "%%A\vcruntime.h" (
      exit /B 0
   )

   set TEST_INCLUDE=%%B
   goto :test_include
)

exit /B 1

@REM return value other than 0 if tests failed.
if "%__VSCMD_TEST_FailCount%" NEQ "0" (
   set __VSCMD_Test_FailCount=
   exit /B 1
)

set __VSCMD_Test_FailCount=
exit /B 0

:clean_env

set VCINSTALLDIR=
set VCToolsInstallDir=
set VCToolsRedistDir=
set VCIDEInstallDir=
set Platform=
set CommandPromptType=
set PreferredToolArchitecture=
set VCTargetsUnderVCInstall=
set ExtensionSdkDir=
set VCToolsVersion=%__VSCMD_PREINIT_VCToolsVersion%
set __VSCMD_PREINIT_VCToolsVersion=

goto :end

@REM ------------------------------------------------------------------------
:export_env

if "%VSCMD_VCVARSALL_INIT%" NEQ "" (
    set Platform=%VSCMD_ARG_TGT_ARCH%
)
if /I "%VSCMD_ARG_HOST_ARCH%" NEQ "%VSCMD_ARG_TGT_ARCH%" (
    set CommandPromptType=Cross
    if /I "%VSCMD_ARG_HOST_ARCH%"=="x64" set PreferredToolArchitecture=x64
) else (
    set CommandPromptType=Native
    set PreferredToolArchitecture=
)

@REM Check for ExtensionSdkDir
@if exist "%ProgramFiles%\Microsoft SDKs\Windows Kits\10\ExtensionSDKs" set ExtensionSdkDir=%ProgramFiles%\Microsoft SDKs\Windows Kits\10\ExtensionSDKs
@if exist "%ProgramFiles(x86)%\Microsoft SDKs\Windows Kits\10\ExtensionSDKs" set ExtensionSdkDir=%ProgramFiles(x86)%\Microsoft SDKs\Windows Kits\10\ExtensionSDKs

@REM Add VCPackages
call :add_to_path_optional "%VSINSTALLDIR%Common7\IDE\VC\VCPackages" "%__VCVARS_NO_OVERRIDE%"


@REM Add MSVC
set "__VCVARS_DEFAULT_CONFIG_FILE=%VCINSTALLDIR%Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"

@REM if __VCVARS_VERSION is defined, user override was detected. Use this instead of default.
if "%__VCVARS_VERSION%" NEQ "" (
    set __VCVARS_TOOLS_VERSION=%__VCVARS_VERSION%
    goto :export_env_vctoolsinstalldir
)

if not exist "%__VCVARS_DEFAULT_CONFIG_FILE%" (
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not find configuration file "%__VCVARS_DEFAULT_CONFIG_FILE%".
    goto :end
)

@REM Use 'type' with double quotes to escape parentheses.
for /F %%A in ('type "%__VCVARS_DEFAULT_CONFIG_FILE%"') do (
    set "__VCVARS_TOOLS_VERSION=%%A"
)

if "%__VCVARS_TOOLS_VERSION%"=="" (
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not determine VC++ tools version.
    goto :end
)

:export_env_vctoolsinstalldir
if exist "%VCINSTALLDIR%Tools\MSVC\%__VCVARS_TOOLS_VERSION%\" (
    set "VCToolsInstallDir=%VCINSTALLDIR%Tools\MSVC\%__VCVARS_TOOLS_VERSION%\"
    set "VCToolsVersion=%__VCVARS_TOOLS_VERSION%"
) else (
    set VCToolsInstallDir=
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not find VC++ tools version "%__VCVARS_TOOLS_VERSION%" under "%VCINSTALLDIR%Tools\MSVC\".
    goto :end
)

set "__VCVARS_DEFAULT_REDIST_FILE=%VCINSTALLDIR%Auxiliary\Build\Microsoft.VCRedistVersion.default.txt"

if not exist "%__VCVARS_DEFAULT_REDIST_FILE%" (
    if "%VSCMD_DEBUG%" GEQ "1" @echo [DEBUG:%~nx0] Could not find configuration file "%__VCVARS_DEFAULT_REDIST_FILE%", skipping.
    goto :skip_default_redist_file
)

@REM Use 'type' with double quotes to escape parentheses.
for /F %%A in ('type "%__VCVARS_DEFAULT_REDIST_FILE%"') do (
    set "__VCVARS_REDIST_VERSION=%%A"
)

if "%VSCMD_DEBUG%" GEQ "2" @echo __VCVARS_REDIST_VERSION=%__VCVARS_REDIST_VERSION%

if exist "%VCINSTALLDIR%Redist\MSVC\%__VCVARS_REDIST_VERSION%\" (
    set "VCToolsRedistDir=%VCINSTALLDIR%Redist\MSVC\%__VCVARS_REDIST_VERSION%\"
) else (
    set VCToolsRedistDir=
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not find VC++ tools version "%__VCVARS_TOOLS_VERSION%" under "%VCINSTALLDIR%Redist\MSVC\".
)

@REM if the Microsoft.VCRedistVersion.default.txt
:skip_default_redist_file

@REM set the IFCPATH directory for modules
call :set_ifcpath_optional "%VCToolsInstallDir%ifc%__VCVARS_TARGET_DIR%" "%__VCVARS_IFC_PATH_OVERRIDE%"

@REM for cross compiler scenarios, add the native host compiler toolset directory to PATH
@REM before adding the cross compiler directory.
if /I "%CommandPromptType%"=="Cross" (
    call :add_to_path_optional "%VCToolsInstallDir%bin%__VCVARS_HOST_DIR%%__VCVARS_HOST_NATIVEDIR%" "%__VCVARS_NATIVE_BIN_OVERRIDE%"
)
call :add_to_path_optional "%VCToolsInstallDir%bin%__VCVARS_BIN_DIR%" "%__VCVARS_BIN_OVERRIDE%"
call :add_to_include_optional "%VCToolsInstallDir%include" "%__VCVARS_VC_INCLUDE_OVERRIDE%"
call :add_to_include_optional "%VCToolsInstallDir%ATLMFC\include" "%__VCVARS_ATLMFC_INCLUDE_OVERRIDE%"
call :add_to_libpath_optional "%VCToolsInstallDir%lib\x86\store\references" "%__VCVARS_X86_STORE_REF_OVERRIDE%"

@REM Set LIB based upon target platform
if /I "%VSCMD_ARG_APP_PLAT%"=="Desktop" (
    call :add_to_lib_optional "%VCToolsInstallDir%lib%__VCVARS_LIB_DIR%" "%__VCVARS_VC_LIB_DESKTOP_OVERRIDE%"
    call :add_to_lib_optional "%VCToolsInstallDir%ATLMFC\lib%__VCVARS_LIB_DIR%" "%__VCVARS_ATL_LIB_OVERRIDE%"
    call :add_to_libpath_optional "%VCToolsInstallDir%lib%__VCVARS_LIB_DIR%" "%__VCVARS_VC_LIB_DESKTOP_OVERRIDE%"
    call :add_to_libpath_optional "%VCToolsInstallDir%ATLMFC\lib%__VCVARS_LIB_DIR%" "%__VCVARS_ATL_LIB_OVERRIDE%"
)

@REM ... set _checkWin81 so it will not match if the Windows 8.1 SDK has been selected/specified.
set "__checkWin81=%WindowsSdkDir:8.1=FOUND%"
if "%__checkWin81%" NEQ "%WindowsSdkDir%" goto :check_win81_app_platform

@REM Windows 10 SDK only past this point
if /I "%VSCMD_ARG_APP_PLAT%"=="UWP" (
    call :add_to_lib_optional "%VCToolsInstallDir%lib%__VCVARS_LIB_DIR%\store\" "%__VCVARS_VC_LIB_STORE_OVERRIDE%"
    call :add_to_libpath_optional "%ExtensionSDKDir%\Microsoft.VCLibs\14.0\References\CommonConfiguration\neutral" "%__VCVARS_NO_OVERRIDE%"
)

if /I "%VSCMD_ARG_APP_PLAT%"=="OneCore" (
    call :add_to_lib_optional "%VCToolsInstallDir%lib\onecore%__VCVARS_LIB_DIR%" "%__VCVARS_VC_LIB_ONECORE_OVERRIDE%"
    call :add_to_libpath_optional "%VCToolsInstallDir%lib\onecore%__VCVARS_LIB_DIR%" "%__VCVARS_VC_LIB_ONECORE_OVERRIDE%"
)
goto :end

@REM ------------------------------------------------------------------------
@REM add_to_path_optional <path> <override>
:add_to_path_optional
if "%~2"=="" (
    set "__VCVARS_ADD_TO_PATH=%~1"
) else (
    set "__VCVARS_ADD_TO_PATH=%~2"
)

if exist "%__VCVARS_ADD_TO_PATH%" (
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Adding "%__VCVARS_ADD_TO_PATH%"
    set "PATH=%__VCVARS_ADD_TO_PATH%;%PATH%"
    exit /B 0
) else (
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not add directory to PATH: "%__VCVARS_ADD_TO_PATH%"
    exit /B 1
)

@REM ------------------------------------------------------------------------
@REM add_to_lib_optional <path> <override>
:add_to_lib_optional
if "%~2"=="" (
    set "__VCVARS_ADD_TO_LIB=%~1"
) else (
    set "__VCVARS_ADD_TO_LIB=%~2"
)

if exist "%__VCVARS_ADD_TO_LIB%" (
    set "LIB=%__VCVARS_ADD_TO_LIB%;%LIB%"
    exit /B 0
) else (
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not add directory to LIB: "%__VCVARS_ADD_TO_LIB%"
    exit /B 1
)

@REM ------------------------------------------------------------------------
@REM add_to_libpath_optional <path> <override>
:add_to_libpath_optional
if "%~2"=="" (
    set "__VCVARS_ADD_TO_LIBPATH=%~1"
) else (
    set "__VCVARS_ADD_TO_LIBPATH=%~2"
)

if exist "%__VCVARS_ADD_TO_LIBPATH%" (
    set "LIBPATH=%__VCVARS_ADD_TO_LIBPATH%;%LIBPATH%"
    exit /B 0
) else (
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not add directory to LIBPATH: "%__VCVARS_ADD_TO_LIBPATH%"
    exit /B 1
)

@REM ------------------------------------------------------------------------
@REM add_to_include_optional <path> <override>
:add_to_include_optional
if "%~2"=="" (
    set "__VCVARS_ADD_TO_INCLUDE=%~1"
) else (
    set "__VCVARS_ADD_TO_INCLUDE=%~2"
)

if exist "%__VCVARS_ADD_TO_INCLUDE%" (
    set "INCLUDE=%__VCVARS_ADD_TO_INCLUDE%;%INCLUDE%"
    exit /B 0
) else (
    if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not add directory to INCLUDE: "%__VCVARS_ADD_TO_INCLUDE%"
    exit /B 1
)

@REM ------------------------------------------------------------------------
@REM set_ifcpath_optional <path> <override>
:set_ifcpath_optional

@REM IFCPATH is expected to be a single path, not a path list. Modules created
@REM by the user (or from another library) would be explicitly referenced via
@REM compiler command line argument.

if "%~2"=="" (
    set "__VCVARS_SET_IFCPATH=%~1"
) else (
    set "__VCVARS_SET_IFCPATH=%~2"
)

if "%IFCPATH%"=="" (
    if exist "%__VCVARS_SET_IFCPATH%" (
        set "IFCPATH=%__VCVARS_SET_IFCPATH%"
        exit /B 0
    ) else (
        if "%VSCMD_DEBUG%" GEQ "2" @echo [DEBUG:%~nx0] Could not add directory to IFCPATH: "%__VCVARS_SET_IFCPATH%"
        exit /B 1
    )
) else (
    if "%VSCMD_DEBUG%" GEQ "1" @echo [DEBUG:%~nx0] IFCPATH was not modified. IFCPATH already set: "%IFCPATH%".
    exit /B 1
)

@REM ------------------------------------------------------------------------
:check_win81_app_platform

if /I "%VSCMD_ARG_APP_PLAT%"=="UWP" goto :report_win81_app_platform_error
if /I "%VSCMD_ARG_APP_PLAT%"=="OneCore" goto :report_win81_app_platform_error

goto :end

:report_win81_app_platform_error
@echo [ERROR:%~nx0] The %VSCMD_ARG_APP_PLAT% Application Platform requires a Windows 10 SDK.
@echo [ERROR:%~nx0] WindowsSdkDir = "%WindowsSdkDir%"
set __VCVARS_SCRIPT_ERROR=1


@REM ------------------------------------------------------------------------
:report_architecture_error

set __VCVARS_SCRIPT_ERROR=1
@echo [ERROR:%~nx0] host/target architecture is not supported : { %VSCMD_ARG_HOST_ARCH% , %VSCMD_ARG_TGT_ARCH% }
goto :end

@REM ------------------------------------------------------------------------
:vcvars140_version
@REM Initialization script for the 14.0 / v140 toolset. This script does not
@REM sit in vsdevcmd\ext directly, so it will not be automatically invoked
@REM as part of normal "EXT" processing.
call "%~dp0\vcvars\vcvars140.bat"
if "%ERRORLEVEL%" NEQ "0" set __VCVARS_SCRIPT_ERROR=1
goto :end

@REM ------------------------------------------------------------------------
:end
set __VCVARS_HOST_DIR=
set __VCVARS_HOST_NATIVEDIR=
set __VCVARS_TARGET_DIR=
set __VCVARS_BIN_DIR=
set __VCVARS_LIB_DIR=
set __VCVARS_TOOLS_VERSION=
set __VCVARS_REDIST_VERSION=
set __VCVARS_DEFAULT_CONFIG_FILE=
set __VCVARS_DEFAULT_REDIST_FILE=
set __VCVARS_VERSION=
set __VCVARS_NATIVE_BIN_OVERRIDE=
set __VCVARS_BIN_OVERRIDE=
set __VCVARS_VC_LIB_DESKTOP_OVERRIDE=
set __VCVARS_VC_LIB_STORE_OVERRIDE=
set __VCVARS_VC_LIB_ONECORE_OVERRIDE=
set __VCVARS_ATL_LIB_OVERRIDE=
set __VCVARS_IFC_PATH_OVERRIDE=
set __VCVARS_VC_INCLUDE_OVERRIDE=
set __VCVARS_ATLMFC_INCLUDE_OVERRIDE=
set __VCVARS_ADD_TO_PATH=
set __VCVARS_ADD_TO_LIB=
set __VCVARS_ADD_TO_LIBPATH=
set __VCVARS_ADD_TO_INCLUDE=
set __VCVARS_SET_IFCPATH=
set __VCVARS_VER_TMP=

set __checkWin81=

if "%__VCVARS_SCRIPT_ERROR%" NEQ "" (
   set __VCVARS_SCRIPT_ERROR=
   exit /B 1
)
exit /B 0

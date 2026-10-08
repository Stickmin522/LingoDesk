param([switch]$TestX64)
$ErrorActionPreference='Stop'
$deskRoot=$PSScriptRoot
$deskVersion=(Select-String -LiteralPath "$deskRoot\app\pubspec.yaml" -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
$deskSdk=if($env:ANDROID_HOME){$env:ANDROID_HOME}elseif($env:ANDROID_SDK_ROOT){$env:ANDROID_SDK_ROOT}else{Join-Path $env:LOCALAPPDATA 'Android\Sdk'}
if(!$env:JAVA_HOME){throw 'Set JAVA_HOME to your JDK 17 or newer installation before building.'}
$deskJdk=$env:JAVA_HOME
$deskAlias=Join-Path $env:TEMP 'LingoDeskApk'
if(!(Test-Path -LiteralPath $deskAlias)){New-Item -ItemType Junction -Path $deskAlias -Target $deskRoot | Out-Null}
if((Get-Item -LiteralPath $deskAlias).Target -ne $deskRoot){throw 'LingoDeskApk alias belongs to a different project. Choose a different alias.'}
$deskBundledFlutter=Join-Path $deskAlias '.tools\flutter\bin\flutter.bat'
$deskFlutter=if($env:FLUTTER_ROOT){Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'}elseif(Test-Path $deskBundledFlutter){$deskBundledFlutter}else{(Get-Command flutter -ErrorAction Stop).Source}
if(Test-Path (Join-Path $deskRoot '.tools\cargo')){$env:CARGO_HOME=Join-Path $deskRoot '.tools\cargo'}
if(Test-Path (Join-Path $deskRoot '.tools\rustup')){$env:RUSTUP_HOME=Join-Path $deskRoot '.tools\rustup'}
if($env:CARGO_HOME){$env:PATH=(Join-Path $env:CARGO_HOME 'bin')+';'+$env:PATH}
$env:JAVA_HOME=$deskJdk
$env:ANDROID_HOME=$deskSdk
if(Test-Path (Join-Path $deskAlias '.tools\pub')){$env:PUB_CACHE=Join-Path $deskAlias '.tools\pub'}
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
function Invoke-Checked([string]$Executable,[string[]]$Arguments){ & $Executable @Arguments; if($LASTEXITCODE-ne 0){throw "$Executable failed ($LASTEXITCODE)"} }
if(!(Test-Path $deskFlutter)){throw 'Set FLUTTER_ROOT or add Flutter to PATH.'}
$deskSigning=Join-Path $deskRoot '.signing'
if(!(Test-Path "$deskSigning\release.jks")){
    New-Item -ItemType Directory -Force -Path $deskSigning | Out-Null
    $deskPassword=[Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    $env:DESK_SIGN_PASSWORD=$deskPassword
    Invoke-Checked "$deskJdk\bin\keytool.exe" @('-genkeypair','-keystore',"$deskSigning\release.jks",'-storepass:env','DESK_SIGN_PASSWORD','-keypass:env','DESK_SIGN_PASSWORD','-alias','desk','-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=Listening Desk, O=Personal')
    "storePassword=$deskPassword`nkeyPassword=$deskPassword" | Set-Content "$deskSigning\key.properties" -Encoding utf8
    Remove-Item Env:DESK_SIGN_PASSWORD
}
$deskTarget=if($TestX64){'x86_64-linux-android'}else{'aarch64-linux-android'}
$deskAbi=if($TestX64){'x86_64'}else{'arm64-v8a'}
$deskPlatform=if($TestX64){'android-x64'}else{'android-arm64'}
$deskEnvTarget=$deskTarget.Replace('-','_')
$deskNdk=Join-Path $deskSdk 'ndk\26.1.10909125\toolchains\llvm\prebuilt\windows-x86_64\bin'
Set-Item "Env:CARGO_TARGET_$($deskEnvTarget.ToUpper())_LINKER" "$deskNdk\clang.exe"
Set-Item "Env:CARGO_TARGET_$($deskEnvTarget.ToUpper())_RUSTFLAGS" "-C link-arg=--target=$($deskTarget)29 -C link-arg=-Wl,-z,max-page-size=16384"
Set-Item "Env:CC_$deskEnvTarget" "$deskNdk\clang.exe"
Set-Item "Env:AR_$deskEnvTarget" "$deskNdk\llvm-ar.exe"
Set-Item "Env:CFLAGS_$deskEnvTarget" "--target=$($deskTarget)29"
$deskCargoArgs=@('build','--manifest-path',"$deskRoot\rust\Cargo.toml",'--locked','--release','--target',$deskTarget)
if($TestX64){$deskCargoArgs+=@('--features','test-harness')}
Invoke-Checked 'cargo' $deskCargoArgs
# Real ASCII staging avoids gen_snapshot canonicalizing a Chinese source path.
$deskStage=Join-Path $env:TEMP 'LingoDeskBuild'
New-Item -ItemType Directory -Force -Path "$deskStage\app","$deskStage\.signing" | Out-Null
& robocopy "$deskRoot\app" "$deskStage\app" /E /XD build .dart_tool .gradle /NFL /NDL /NJH /NJS /NP
if($LASTEXITCODE-ge 8){throw 'Source staging failed'}
Copy-Item "$deskSigning\key.properties","$deskSigning\release.jks" "$deskStage\.signing"
New-Item -ItemType Directory -Force -Path "$deskStage\app\android\app\src\main\jniLibs\$deskAbi" | Out-Null
Copy-Item "$deskRoot\rust\target\$deskTarget\release\liblecsync_core.so" "$deskStage\app\android\app\src\main\jniLibs\$deskAbi\liblecsync_core.so"
Push-Location "$deskStage\app"
try{
    Invoke-Checked $deskFlutter @('pub','get')
    $deskMode=if($TestX64){'debug'}else{'release'}
    $deskArgs=@('build','apk',"--$deskMode",'--target-platform',$deskPlatform)
    if($TestX64){$deskArgs+='--android-project-arg=testX64=true'}
    Invoke-Checked $deskFlutter $deskArgs
    $deskOutput=if($TestX64){"$deskRoot\outputs\test-only\desk-x64-test.apk"}else{"$deskRoot\outputs\听译台-$deskVersion-arm64.apk"}
    New-Item -ItemType Directory -Force -Path (Split-Path $deskOutput) | Out-Null
    Copy-Item "$deskStage\app\build\app\outputs\apk\$deskMode\app-$deskMode.apk" $deskOutput
    Invoke-Checked "$deskSdk\build-tools\37.0.0\apksigner.bat" @('verify',$deskOutput)
    Invoke-Checked "$deskSdk\build-tools\37.0.0\zipalign.exe" @('-c','-P','16','4',$deskOutput)
    Get-FileHash -LiteralPath $deskOutput -Algorithm SHA256
}finally{Pop-Location}

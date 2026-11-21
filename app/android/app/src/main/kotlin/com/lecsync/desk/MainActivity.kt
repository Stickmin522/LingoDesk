package com.lecsync.desk

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var bridge: Bridge?=null
    private var pending: MethodChannel.Result?=null
    private var resuming=false
    private var title=""
    private var exportSnapshot: Pair<String, JSONObject>? = null
    private var player: MediaPlayer?=null
    private val executor=Executors.newSingleThreadExecutor()
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        discardFinishedDraft(cleanupOnly = savedInstanceState != null)
        super.onCreate(savedInstanceState)
    }
    private fun discardFinishedDraft(cleanupOnly: Boolean = false) {
        NativeCore.command(JSONObject().put("op", "discardRecording")
            .put("cleanupOnly", cleanupOnly)
            .put("directory", SettingsStore.directory(this)).toString())
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) { super.configureFlutterEngine(flutterEngine); bridge=Bridge(this,flutterEngine,this) }
    override fun onResume() { super.onResume(); visible=true; SessionService.instance?.refreshOverlay() }
    override fun onStop() { super.onStop(); visible=false; if(!isChangingConfigurations && pending==null) SessionService.instance?.refreshOverlay() }
    override fun onDestroy() {
        if (isFinishing) discardFinishedDraft()
        bridge?.close()
        stopPlayback()
        executor.shutdown()
        super.onDestroy()
    }
    fun requestStart(recordTitle: String,result: MethodChannel.Result) {
        if(pending!=null) {result.error("busy","正在等待授权",null);return}
        val state=JSONObject(NativeCore.command("{\"op\":\"snapshot\"}"))
        if(state.optString("phase") !in listOf("idle","ended")){result.error("busy","已有录音正在运行",null);return}
        if (state.optBoolean("pendingSave")) {
            result.error("busy", "录音尚未保存", null)
            return
        }
        if(SettingsStore.readKey(this).isBlank()){result.error("key","请先保存 LecSync API Key",null);return}
        stopPlayback(); resuming=false; pending=result; title=recordTitle
        val permissions=mutableListOf<String>()
        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED)permissions.add(Manifest.permission.RECORD_AUDIO)
        if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        if(permissions.isNotEmpty()) requestPermissions(permissions.toTypedArray(),101) else requestProjection()
    }
    fun requestResume(result:MethodChannel.Result){
        if(pending!=null){result.error("busy","正在等待授权",null);return}
        resuming=true;pending=result
        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED)requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),101)else requestProjection()
    }
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray){super.onRequestPermissionsResult(requestCode,permissions,grantResults);if(requestCode==101){if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){pending?.error("permission","录音需要麦克风权限（系统音频捕获也需要此权限）",null);pending=null}else requestProjection()}}
    private fun requestProjection(){if(resuming&&SessionService.instance?.needsProjection()==false){SessionService.instance?.control("resume");pending?.success("{}");pending=null;resuming=false;return};if(SettingsStore.read(this).optString("source")=="mic") launchRecording(Activity.RESULT_CANCELED,null) else {
        val manager=getSystemService(MediaProjectionManager::class.java)
        val intent=if(Build.VERSION.SDK_INT>=34)manager.createScreenCaptureIntent(android.media.projection.MediaProjectionConfig.createConfigForDefaultDisplay())else manager.createScreenCaptureIntent()
        startActivityForResult(intent,102)
    }}
    private fun launchRecording(code:Int,data:Intent?){try{val intent=Intent(this,SessionService::class.java).setAction(if(resuming)"resumeProjection"else"start").putExtra("config",SettingsStore.config(this,title).toString()).putExtra("resultCode",code).putExtra("projection",data);startForegroundService(intent);pending?.success("{}")}catch(e:Exception){pending?.error("start",e.message,null)}finally{pending=null;resuming=false}}
    fun setOverlay(enabled:Boolean,result:MethodChannel.Result){if(!enabled){SettingsStore.save(this,JSONObject().put("overlay",false));SessionService.instance?.refreshOverlay();result.success("{}");return};if(pending!=null){result.error("busy","正在等待授权",null);return};if(!Settings.canDrawOverlays(this)){pending=result;startActivityForResult(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,Uri.parse("package:$packageName")),103)}else enableOverlay(result)}
    private fun enableOverlay(result:MethodChannel.Result?){try{SettingsStore.save(this,JSONObject().put("overlay",true));SessionService.instance?.enableOverlay();result?.success("{}")}catch(e:Exception){result?.error("overlay",e.message,null)}}
    @Deprecated("Activity result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            102 -> if (resultCode == Activity.RESULT_OK && data != null) {
                launchRecording(resultCode, data)
            } else {
                pending?.error("permission", "已取消系统音频授权", null)
                pending = null
            }
            103 -> {
                val result = pending
                pending = null
                if (Settings.canDrawOverlays(this)) enableOverlay(result)
                else result?.error("permission", "未开启显示在其他应用上层权限", null)
            }
            104 -> finishExport(resultCode, data?.data)
        }
    }

    fun exportRecord(input: JSONObject, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "正在等待另一个操作", null)
            return
        }
        input.put("op", "export").put("directory", SettingsStore.directory(this))
        val snapshot = JSONObject(NativeCore.command(input.toString()))
        if (snapshot.has("error")) {
            result.error("export", snapshot.optString("error"), null)
            return
        }
        val format = input.optString("format", "txt")
        pending = result
        exportSnapshot = format to snapshot
        try {
            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType(when (format) {
                    "wav" -> "audio/wav"
                    "json" -> "application/json"
                    "srt" -> "application/x-subrip"
                    else -> "text/plain"
                })
                .putExtra(Intent.EXTRA_TITLE, snapshot.getString("filename")), 104)
        } catch (error: Exception) {
            pending = null
            exportSnapshot = null
            throw error
        }
    }

    private fun finishExport(resultCode: Int, uri: Uri?) {
        val result = pending
        val export = exportSnapshot
        pending = null
        exportSnapshot = null
        if (resultCode != Activity.RESULT_OK || uri == null || export == null) {
            result?.success("{\"cancelled\":true}")
            return
        }
        val (format, snapshot) = export
        executor.execute {
            val saved = runCatching {
                contentResolver.openOutputStream(uri)?.use { output ->
                    if (format == "wav") {
                        File(snapshot.getString("audioPath")).inputStream().use { it.copyTo(output) }
                    } else {
                        output.write(snapshot.getString("content").toByteArray(Charsets.UTF_8))
                    }
                } ?: error("无法写入选定文件")
            }
            runOnUiThread {
                saved.fold({ result?.success("{\"saved\":true}") }, { result?.error("export", it.message, null) })
            }
        }
    }

    fun playRecord(input:JSONObject){stopPlayback();val v=JSONObject(NativeCore.command(JSONObject().put("op","load").put("directory",SettingsStore.directory(this)).put("id",input.getString("id")).toString()));if(v.has("error") && !v.has("id"))error(v.optString("error"));player=MediaPlayer().apply{setDataSource(v.getString("audioPath"));setOnPreparedListener{it.start()};setOnCompletionListener{stopPlayback()};prepareAsync()}}
    fun stopPlayback(){player?.release();player=null}
    fun openLecSyncConsole(){
        val intent=Intent(Intent.ACTION_VIEW,Uri.parse("https://www.lecsync.com/dashboard/api"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
        // Resolve the user's browser, rather than another app claiming this website.
        intent.selector=Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_BROWSER)
        startActivity(intent)
    }
    companion object {@Volatile var visible=false}
}



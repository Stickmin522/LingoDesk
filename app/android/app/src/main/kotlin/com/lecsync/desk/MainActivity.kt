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
    private var exportRequest: JSONObject?=null
    private var player: MediaPlayer?=null
    private val executor=Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) { super.configureFlutterEngine(flutterEngine); bridge=Bridge(this,flutterEngine,this) }
    override fun onResume() { super.onResume(); visible=true; SessionService.instance?.refreshOverlay() }
    override fun onStop() { super.onStop(); visible=false; if(!isChangingConfigurations && pending==null) SessionService.instance?.refreshOverlay() }
    override fun onDestroy() { bridge?.close(); stopPlayback(); executor.shutdown(); super.onDestroy() }
    fun requestStart(recordTitle: String,result: MethodChannel.Result) {
        if(pending!=null) {result.error("busy","正在等待授权",null);return}
        val state=JSONObject(NativeCore.command("{\"op\":\"snapshot\"}"))
        if(state.optString("phase") !in listOf("idle","ended")){result.error("busy","已有录音正在运行",null);return}
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
    override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?){super.onActivityResult(requestCode,resultCode,data);when(requestCode){102->if(resultCode==Activity.RESULT_OK&&data!=null)launchRecording(resultCode,data)else{pending?.error("permission","已取消系统音频授权",null);pending=null};103->{val r=pending;pending=null;if(Settings.canDrawOverlays(this))enableOverlay(r)else r?.error("permission","未开启显示在其他应用上层权限",null)};104->{val r=pending;val req=exportRequest;pending=null;exportRequest=null;if(resultCode!=Activity.RESULT_OK || data?.data==null || req==null){r?.success("{\"cancelled\":true}");return};val uri=data.data!!;executor.execute{val success=runCatching{val response=JSONObject(NativeCore.command(req.toString()));if(response.has("error"))error(response.optString("error"));contentResolver.openOutputStream(uri)?.use{out->if(req.optString("format")=="wav") File(response.getString("audioPath")).inputStream().use{it.copyTo(out)} else out.write(response.getString("content").toByteArray(Charsets.UTF_8))}?:error("无法写入选定文件")};runOnUiThread{success.fold({r?.success("{\"saved\":true}")},{r?.error("export",it.message,null)})}}}}}
    fun exportRecord(input:JSONObject,result:MethodChannel.Result){if(pending!=null){result.error("busy","正在等待另一个操作",null);return};input.put("op","export").put("directory",SettingsStore.directory(this));val response=JSONObject(NativeCore.command(input.toString()));if(response.has("error")){result.error("export",response.optString("error"),null);return};pending=result;exportRequest=input;val format=input.optString("format","txt");startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(when(format){"wav"->"audio/wav";"json"->"application/json";"srt"->"application/x-subrip";else->"text/plain"}).putExtra(Intent.EXTRA_TITLE,response.getString("filename")),104)}
    fun playRecord(input:JSONObject){stopPlayback();val v=JSONObject(NativeCore.command(JSONObject().put("op","load").put("directory",SettingsStore.directory(this)).put("id",input.getString("id")).toString()));if(v.has("error"))error(v.optString("error"));player=MediaPlayer().apply{setDataSource(v.getString("audioPath"));setOnPreparedListener{it.start()};setOnCompletionListener{stopPlayback()};prepareAsync()}}
    fun stopPlayback(){player?.release();player=null}
    companion object {@Volatile var visible=false}
}



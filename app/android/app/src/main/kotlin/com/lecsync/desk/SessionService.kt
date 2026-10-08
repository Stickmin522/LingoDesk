package com.lecsync.desk

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.media.*
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import android.provider.Settings
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.min

class SessionService : Service() {
    private val handler=Handler(Looper.getMainLooper())
    private val audioWorker=Executors.newSingleThreadExecutor()
    private val generation=AtomicInteger()
    @Volatile private var mic:AudioRecord?=null
    @Volatile private var system:AudioRecord?=null
    private var projection:MediaProjection?=null
    private var source="mic"
    private var device="default"
    private var previousPhase=""
    private var capturing=false
    private var overlayEngine:FlutterEngine?=null
    private var overlayBridge:Bridge?=null
    private var overlayView:FlutterView?=null
    private var params:WindowManager.LayoutParams?=null
    private var overlayRoot:OverlayFrame?=null
    private var overlayDismissed=false
    private var recordingTypes=0
    private var sessionActive=false
    private var stoppingProjection=false
    private var wake:PowerManager.WakeLock?=null
    override fun onBind(intent:Intent?):IBinder?=null
    override fun onCreate(){super.onCreate();instance=this;wake=getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"$packageName:recording").apply{setReferenceCounted(false)};getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("recording","录音与悬浮字幕",NotificationManager.IMPORTANCE_LOW));handler.post(poll)}
    override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
        try {
            when(intent?.action){
                "start"->{
                    val state=JSONObject(NativeCore.command("{\"op\":\"snapshot\"}"))
                    if(state.optString("phase") !in listOf("idle","ended"))return START_NOT_STICKY
                    val config=JSONObject(intent.getStringExtra("config")?:error("缺少配置"));source=config.optString("source","mic");device=config.optString("device","default")
                    sessionActive=true;overlayDismissed=false
                    recordingTypes=(if(source!="system"&&Build.VERSION.SDK_INT>=30)ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else 0) or (if(source!="mic")ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION else 0)
                    foreground("正在连接",recordingTypes)
                    if(source!="mic")grantProjection(intent)
                    previousPhase="";val response=JSONObject(NativeCore.command(JSONObject().put("op","start").put("config",config).toString()));if(response.has("error"))error(response.optString("error"))
                }
                "overlay"->{overlayDismissed=false;if(!sessionActive)foreground("悬浮字幕已开启",specialType());prepareOverlay();refreshOverlay()}
                "resumeProjection"->{grantProjection(intent);control("resume")}
                "pause","resume","stop"->control(intent.action!!)
            }
        }catch(e:Exception){warn(e.message?:"录音启动失败");NativeCore.command(JSONObject().put("op","fail").put("message",e.message?:"录音启动失败").toString());stopAudio();releaseProjection();recordingTypes=0;sessionActive=false;if(SettingsStore.read(this).optBoolean("overlay"))foreground("录音启动失败",specialType())else stopSelf()}
        return START_NOT_STICKY
    }
    private fun specialType()=if(Build.VERSION.SDK_INT>=34)ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
    private fun foreground(text:String,types:Int){
        val open=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification=Notification.Builder(this,"recording").setSmallIcon(com.lecsync.desk.R.drawable.ic_notification).setContentTitle("听译台").setContentText(text).setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true).build()
        startForeground(7,notification,types)
    }
    private fun grantProjection(intent:Intent){
        val data=if(Build.VERSION.SDK_INT>=33)intent.getParcelableExtra("projection",Intent::class.java)else @Suppress("DEPRECATION") intent.getParcelableExtra("projection")
        projection=getSystemService(MediaProjectionManager::class.java).getMediaProjection(intent.getIntExtra("resultCode",Activity.RESULT_CANCELED),data?:error("缺少系统音频授权"))
        projection?.registerCallback(object:MediaProjection.Callback(){override fun onStop(){if(projection!=null&&!stoppingProjection){projection=null;warn("系统撤销了音频捕获授权，采集已暂停；回到应用点击继续可重新授权。记录尚未结束。");control("pause")}}},handler)
    }
    fun needsProjection()=source!="mic"&&projection==null
    fun control(op:String){if(op=="pause"||op=="stop")stopAudio();NativeCore.command(JSONObject().put("op",op).toString());Bridge.broadcast()}
    private fun warn(message:String){NativeCore.command(JSONObject().put("op","warn").put("message",message).toString());Bridge.broadcast()}
    private val poll=object:Runnable{override fun run(){
        val state=JSONObject(NativeCore.command("{\"op\":\"snapshot\"}"));val p=state.optString("phase","idle")
        if(p=="recording"){if(wake?.isHeld==false)wake?.acquire()}else if(wake?.isHeld==true)wake?.release()
        if(p!=previousPhase){previousPhase=p
            if(p=="recording"&&!capturing)startAudio()
            if(p in listOf("paused","ended","stopping","pausing"))stopAudio()
            if(p=="ended"){releaseProjection();recordingTypes=0;sessionActive=false;if(SettingsStore.read(this@SessionService).optBoolean("overlay"))foreground("录音已保存 · 悬浮字幕已开启",specialType())else{Bridge.broadcast();stopSelf();return}}
            else if(sessionActive)foreground(when(p){"recording"->"正在录音与翻译";"paused"->"已暂停 · 不上传音频";"connecting"->"正在连接";else->"正在处理"},recordingTypes)
        }
        Bridge.broadcast();handler.postDelayed(this,250)
    }}
    private fun buildAudio(playback:Boolean):AudioRecord {
        val format=AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(16000).setChannelMask(AudioFormat.CHANNEL_IN_MONO).build()
        val minimum=AudioRecord.getMinBufferSize(16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT)
        check(minimum>0){"此设备不支持 16 kHz 音频采集"}
        val builder=AudioRecord.Builder().setAudioFormat(format).setBufferSizeInBytes(maxOf(minimum*4,6400))
        if(playback){val capture=AudioPlaybackCaptureConfiguration.Builder(projection?:error("系统音频授权失效")).addMatchingUsage(AudioAttributes.USAGE_MEDIA).addMatchingUsage(AudioAttributes.USAGE_GAME).addMatchingUsage(AudioAttributes.USAGE_UNKNOWN).excludeUid(android.os.Process.myUid()).build();builder.setAudioPlaybackCaptureConfig(capture)}else builder.setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
        return builder.build().apply{check(state==AudioRecord.STATE_INITIALIZED){"音频采集初始化失败"};if(!playback&&device!="default"){getSystemService(AudioManager::class.java).getDevices(AudioManager.GET_DEVICES_INPUTS).firstOrNull{it.id.toString()==device}?.let{setPreferredDevice(it)}}}
    }
    private fun startAudio(){capturing=true;val run=generation.incrementAndGet();audioWorker.execute{
        var m:AudioRecord?=null;var s:AudioRecord?=null
        try{
            if(source!="system")m=buildAudio(false)
            if(source!="mic")s=buildAudio(true)
            if(generation.get()!=run)return@execute
            mic=m;system=s;m?.startRecording();s?.startRecording()
            val mb=if(m!=null)ShortArray(320)else ShortArray(0);val sb=if(s!=null)ShortArray(320)else ShortArray(0)
            var silent=0;var warned=false
            fun read(record:AudioRecord?,buffer:ShortArray){if(record==null)return;var offset=0;while(offset<buffer.size&&generation.get()==run){val n=record.read(buffer,offset,buffer.size-offset,AudioRecord.READ_BLOCKING);check(n>0){"音源已停止或被系统占用"};offset+=n}}
            while(generation.get()==run){read(m,mb);read(s,sb);if(generation.get()!=run)break;if(s!=null){silent=if(sb.all{it==0.toShort()})silent+1 else 0;if(silent>=250&&!warned){warned=true;handler.post{warn("系统音轨暂时无声。请播放媒体，并确认来源应用允许音频捕获；通话和受保护内容可能无法录制。")}}};check(NativeCore.push(mb,sb,320)==0){"音频写入失败，请检查存储空间"}}
        }catch(e:Exception){if(generation.get()==run)handler.post{warn(e.message?:"音源采集失败");control("pause")}}
        finally{runCatching{m?.stop()};runCatching{s?.stop()};m?.release();s?.release();if(generation.get()==run){mic=null;system=null;capturing=false}}
    }}
    private fun stopAudio(){if(capturing){capturing=false;generation.incrementAndGet();runCatching{mic?.stop()};runCatching{system?.stop()};mic=null;system=null}}
    private fun releaseProjection(){stoppingProjection=true;projection?.stop();projection=null;stoppingProjection=false}
    fun refreshOverlay(){
        val enabled=SettingsStore.read(this).optBoolean("overlay")&&Settings.canDrawOverlays(this)
        if(enabled&&!overlayDismissed&&!MainActivity.visible)showOverlay()else hideOverlay()
        if(!enabled&&!sessionActive)stopSelf()
    }
    fun dismissOverlay(){overlayDismissed=true;hideOverlay()}
    fun setOverlayControlsVisible(visible:Boolean){overlayRoot?.controlsVisible=visible}
    fun overlayInteraction(active:Boolean){overlayBridge?.overlayInteraction(active)}
    private fun prepareOverlay(){
            if(overlayView==null){
                val engine=FlutterEngine(this);overlayEngine=engine;overlayBridge=Bridge(this,engine)
                val loader=FlutterInjector.instance().flutterLoader();loader.startInitialization(this);loader.ensureInitializationComplete(this,null)
                val view=FlutterView(this,FlutterTextureView(this).apply{isOpaque=false});view.attachToFlutterEngine(engine)
                val root=OverlayFrame(this,this);root.addView(view,android.widget.FrameLayout.LayoutParams(-1,-1));overlayRoot=root;overlayView=view
                val d=resources.displayMetrics.density;val prefs=SettingsStore.read(this)
                params=WindowManager.LayoutParams((prefs.optDouble("overlayWidth",280.0)*d).toInt(),(prefs.optDouble("overlayHeight",180.0)*d).toInt(),WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,PixelFormat.TRANSLUCENT).apply{gravity=android.view.Gravity.TOP or android.view.Gravity.START;x=(prefs.optDouble("overlayX",12.0)*d).toInt();y=(prefs.optDouble("overlayY",90.0)*d).toInt()}
                engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(),"overlayMain"))
            }
    }
    private fun showOverlay(){
        if(overlayRoot?.isAttachedToWindow==true)return
        try{
            prepareOverlay()
            val p=params?:return;setOverlayGeometry(p.x,p.y,p.width,p.height)
            getSystemService(WindowManager::class.java).addView(overlayRoot,params);overlayEngine?.lifecycleChannel?.appIsResumed();overlayBridge?.overlayShown()
        }catch(e:Exception){destroyOverlay();warn("悬浮窗显示失败，请检查悬浮窗权限")}
    }
    private fun screenBounds():android.graphics.Rect {
        val wm=getSystemService(WindowManager::class.java)
        return if(Build.VERSION.SDK_INT>=30){
            val metrics=wm.currentWindowMetrics
            val insets=metrics.windowInsets.getInsetsIgnoringVisibility(android.view.WindowInsets.Type.systemBars() or android.view.WindowInsets.Type.displayCutout())
            android.graphics.Rect(0,0,metrics.bounds.width()-insets.left-insets.right,metrics.bounds.height()-insets.top-insets.bottom)
        }else android.graphics.Rect(0,0,resources.displayMetrics.widthPixels,resources.displayMetrics.heightPixels)
    }
    fun overlayGeometry():IntArray {val p=params?:return intArrayOf(0,0,0,0);return intArrayOf(p.x,p.y,p.width,p.height)}
    fun setOverlayGeometry(x:Int,y:Int,width:Int,height:Int){
        val p=params?:return;val bounds=screenBounds();val d=resources.displayMetrics.density
        val maxW=maxOf(1,bounds.width()-(16*d).toInt());val maxH=maxOf(1,bounds.height()-(24*d).toInt())
        p.width=width.coerceIn(min((200*d).toInt(),maxW),maxW);p.height=height.coerceIn(min((120*d).toInt(),maxH),maxH)
        p.x=x.coerceIn(0,maxOf(0,bounds.width()-p.width));p.y=y.coerceIn(0,maxOf(0,bounds.height()-p.height))
    }
    fun scaleOverlay(factor:Float){val p=params?:return;setOverlayGeometry(p.x,p.y,(p.width*factor).toInt(),(p.height*factor).toInt())}
    fun toggleOverlaySize(){val p=params?:return;val d=resources.displayMetrics.density;val expanded=min((560*d).toInt(),screenBounds().width()-(16*d).toInt());val large=p.width>=expanded*.8;setOverlayGeometry(p.x,p.y,if(large)(280*d).toInt()else expanded,((if(large)180 else 300)*d).toInt());rememberOverlayGeometry()}
    fun applyOverlayLayout(){if(overlayRoot?.isAttachedToWindow==true)getSystemService(WindowManager::class.java).updateViewLayout(overlayRoot,params)}
    fun rememberOverlayGeometry(){val p=params?:return;val d=resources.displayMetrics.density;SettingsStore.save(this,JSONObject().put("overlayX",p.x/d).put("overlayY",p.y/d).put("overlayWidth",p.width/d).put("overlayHeight",p.height/d))}
    private fun hideOverlay(){if(overlayRoot?.isAttachedToWindow==true){rememberOverlayGeometry();runCatching{getSystemService(WindowManager::class.java).removeView(overlayRoot)};overlayEngine?.lifecycleChannel?.appIsPaused()}}
    private fun destroyOverlay(){hideOverlay();overlayView?.detachFromFlutterEngine();overlayView=null;overlayRoot=null;params=null;overlayBridge?.close();overlayBridge=null;overlayEngine?.destroy();overlayEngine=null}
    override fun onConfigurationChanged(newConfig:Configuration){super.onConfigurationChanged(newConfig);val p=params;if(p!=null){setOverlayGeometry(p.x,p.y,p.width,p.height);applyOverlayLayout()}}
    override fun onTaskRemoved(rootIntent:Intent?){refreshOverlay();super.onTaskRemoved(rootIntent)}
    override fun onDestroy(){handler.removeCallbacksAndMessages(null);stopAudio();if(wake?.isHeld==true)wake?.release();NativeCore.command("{\"op\":\"stop\"}");releaseProjection();destroyOverlay();audioWorker.shutdown();instance=null;super.onDestroy()}
    companion object {@Volatile var instance:SessionService?=null}
}


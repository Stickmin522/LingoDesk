package com.lecsync.desk

import android.content.Context
import android.util.LruCache
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Like the new web source, translate structured notes locally, without another cloud API. */
object ChineseDigest {
    private data class Job(val key:String,val context:Context,val view:JSONObject)
    private data class Status(val key:String,var stage:String,var error:String="")
    private val worker=Executors.newSingleThreadExecutor()
    private val states=LinkedHashMap<String,Status>()
    private val pending=LinkedHashMap<String,Job>()
    private val textCache=LruCache<String,String>(500)
    private var running=false
    private fun key(view:JSONObject):String {
        val raw=(view.optJSONArray("sections")?:JSONArray()).toString()
        return view.optString("id")+":"+MessageDigest.getInstance("SHA-256").digest(raw.toByteArray()).joinToString(""){"%02x".format(it)}
    }
    @Synchronized fun decorate(context:Context,view:JSONObject,retry:Boolean=false):JSONObject {
        val id=view.optString("id");val raw=view.optJSONArray("sections")?:JSONArray()
        if(id.isEmpty()||raw.length()==0)return view
        if(!retry && view.optJSONArray("chineseDigestSource")?.toString()==raw.toString() && (view.optJSONArray("chineseSections")?.length()?:0)>0){view.put("digestStatus","ready");return view}
        val stamp=key(view);val current=states[id]
        if(retry || current?.key!=stamp){
            states[id]=Status(stamp,"preparing")
            pending[id]=Job(stamp,context.applicationContext,JSONObject(view.toString()))
            while(states.size>24){val first=states.keys.first();if(first==id)break;states.remove(first)}
            if(!running){running=true;worker.execute{process()}}
        }
        val state=states[id]
        if(state?.key==stamp)view.put("digestStatus",state.stage).put("digestError",state.error)
        return view
    }
    private fun status(id:String,stamp:String,stage:String,error:String="") {
        synchronized(this){states[id]?.takeIf{it.key==stamp}?.apply{this.stage=stage;this.error=error}}
    }
    private fun language(text:String,pair:String):String {
        if(text.any{it in '\u3040'..'\u30ff'})return "ja"
        if(text.any{it in '\uac00'..'\ud7af'})return "ko"
        val han=text.count{it in '\u4e00'..'\u9fff'};val latin=text.count{it in 'A'..'Z'||it in 'a'..'z'}
        if(han>0&&han>=latin/2)return "zh"
        if(latin>0)return "en"
        return if(pair=="en-zh")"en" else "ja"
    }
    private fun process(){
        while(true){
            val job=synchronized(this){val next=pending.entries.firstOrNull();if(next==null){running=false;null}else{pending.remove(next.key);next.value}}?:return
            val v=job.view;val id=v.optString("id");val raw=v.optJSONArray("sections")?:JSONArray();val result=JSONArray();var translated=false
            val clients=mutableMapOf<String,com.google.mlkit.nl.translate.Translator>()
            try {
                for(i in 0 until raw.length()){
                    val section=raw.getJSONObject(i);val points=section.optJSONArray("points")?:JSONArray()
                    val sample=section.optString("title")+"\n"+(0 until points.length()).joinToString("\n"){points.optString(it)}
                    val lang=language(sample,v.optString("pair","ja-zh"))
                    val out=JSONObject(section.toString());val outPoints=JSONArray()
                    fun translate(text:String):String {
                        if(text.isBlank()||lang=="zh")return text
                        translated=true;val cacheKey="$lang\u0000$text";textCache.get(cacheKey)?.let{return it}
                        val client=clients.getOrPut(lang){
                            val c=Translation.getClient(TranslatorOptions.Builder().setSourceLanguage(lang).setTargetLanguage("zh").build())
                            try{Tasks.await(c.downloadModelIfNeeded(DownloadConditions.Builder().requireWifi().build()),120,TimeUnit.SECONDS)}catch(e:Exception){c.close();throw e}
                            c
                        }
                        status(id,job.key,"translating")
                        val output=Tasks.await(client.translate(text),30,TimeUnit.SECONDS)
                        check(output.isNotBlank()){"中文纪要翻译返回空内容"};textCache.put(cacheKey,output);return output
                    }
                    out.put("title",translate(section.optString("title")))
                    for(p in 0 until points.length())outPoints.put(translate(points.optString(p)))
                    out.put("points",outPoints);result.put(out)
                }
                NativeCore.command(JSONObject().put("op","digestTranslation").put("directory",SettingsStore.directory(job.context)).put("id",id).put("raw",raw).put("sections",result).put("translated",translated).toString())
                status(id,job.key,"ready")
            } catch(e:Exception){status(id,job.key,"error","中文纪要语言包或本机翻译暂不可用。请连接 Wi-Fi 后重试；原始纪要和录音仍保留。")}
            finally{clients.values.forEach{it.close()}}
        }
    }
}

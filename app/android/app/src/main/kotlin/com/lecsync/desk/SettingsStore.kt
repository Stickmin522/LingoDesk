package com.lecsync.desk

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object SettingsStore {
    private const val ALIAS = "listening_desk_api_v1"
    private fun prefs(c: Context) = c.getSharedPreferences("desk", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    fun readKey(c: Context): String {
        val encrypted = prefs(c).getString("key", null) ?: return ""
        val bytes = Base64.decode(encrypted, Base64.NO_WRAP)
        require(bytes.size > 12) { "密钥存储已损坏，请重新填写" }
        return String(Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        }.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
    }
    fun save(c: Context, input: JSONObject) {
        val p = prefs(c).edit()
        if (input.has("apiKey")) {
            val text = input.optString("apiKey").trim()
            if (text.isEmpty()) p.remove("key") else {
                val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
                p.putString("key", Base64.encodeToString(cipher.iv + cipher.doFinal(text.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP))
            }
        }
        for (name in listOf("pair", "source", "captionMode", "theme", "device")) if (input.has(name)) p.putString(name, input.optString(name))
        for (name in listOf("speakers", "digest", "enhance", "overlay")) if (input.has(name)) p.putBoolean(name, input.optBoolean(name))
        for(name in listOf("overlayX","overlayY","overlayWidth","overlayHeight")) if(input.has(name)) p.putFloat(name,input.optDouble(name).toFloat())
        if (input.has("fontSize")) p.putInt("fontSize", input.optInt("fontSize", 20).coerceIn(14, 32))
        check(p.commit()) { "设置保存失败" }
    }
    fun read(c: Context): JSONObject {
        val p = prefs(c)
        if(p.getInt("overlaySchema",0)<2){
            val edit=p.edit().putInt("overlaySchema",2)
            if(android.provider.Settings.canDrawOverlays(c))edit.putBoolean("overlay",true)
            edit.commit()
        }
        val key = runCatching { readKey(c) }.getOrDefault("")
        return JSONObject().put("hasKey", key.isNotEmpty()).put("keyHint", if (key.isNotEmpty()) "•••• " + key.takeLast(4) else "")
            .put("pair", p.getString("pair", "ja-zh")).put("source", p.getString("source", "mic"))
            .put("captionMode", p.getString("captionMode", "both")).put("theme", p.getString("theme", "system"))
            .put("device", p.getString("device", "default")).put("fontSize", p.getInt("fontSize", 20))
            .put("speakers", p.getBoolean("speakers", true)).put("digest", p.getBoolean("digest", true))
            .put("enhance", p.getBoolean("enhance", true)).put("overlay", p.getBoolean("overlay", false))
            .put("overlayX",p.getFloat("overlayX",12f)).put("overlayY",p.getFloat("overlayY",90f)).put("overlayWidth",p.getFloat("overlayWidth",280f)).put("overlayHeight",p.getFloat("overlayHeight",180f))
    }
    fun config(c: Context, title: String = ""): JSONObject = read(c).put("apiKey", readKey(c)).put("title", title).put("directory", directory(c))
    fun directory(c: Context): String = java.io.File(c.filesDir, "sessions").apply { mkdirs() }.absolutePath
}

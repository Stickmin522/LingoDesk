package com.lecsync.desk

import android.content.Context
import android.content.res.Resources
import org.json.JSONArray
import org.json.JSONObject

object AppLanguages {
    private var codes: Set<String>? = null
    private val texts = mutableMapOf<String, JSONObject>()
    fun codes(c: Context): Set<String> = codes ?: JSONArray(c.assets.open("flutter_assets/assets/languages.json").bufferedReader().use { it.readText() })
        .let { list -> (0 until list.length()).map { list.getJSONObject(it).getString("code") }.toSet() }.also { codes = it }
    fun systemLanguages(): Set<String> = Resources.getSystem().assets.locales.map(LocalePolicy::normalize).toSet() + "en"
    fun resolve(c: Context, selection: String): String {
        val locales = Resources.getSystem().configuration.locales
        return LocalePolicy.resolve(selection, (0 until locales.size()).map { locales[it].toLanguageTag() }, systemLanguages(), codes(c))
    }
    fun validatePair(c: Context, pair: String) {
        val sides = pair.split('-')
        require(sides.size == 2 && sides.all { it in codes(c) }) { "不支持的语言" }
        require(sides[0] != sides[1]) { "两种语言不能相同" }
    }
    @Synchronized fun text(c: Context, key: String): String {
        val selected = c.getSharedPreferences("desk", Context.MODE_PRIVATE).getString("uiLanguage", "system") ?: "system"
        val language = resolve(c, selected)
        fun catalog(code: String): JSONObject = texts.getOrPut(code) {
            runCatching { JSONObject(c.assets.open("flutter_assets/assets/i18n/$code.json").bufferedReader().use { it.readText() }) }.getOrDefault(JSONObject())
        }
        return catalog(language).optString(key).ifEmpty { catalog("en").optString(key, key) }
    }
}

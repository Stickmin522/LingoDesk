package com.lecsync.desk

internal object LocalePolicy {
    fun normalize(tag: String): String = when (val code = tag.replace('_','-').substringBefore('-').lowercase()) {
        "iw" -> "he"; "in" -> "id"; "nb", "nn" -> "no"; "fil" -> "tl"; else -> code
    }
    fun resolve(selection: String, system: List<String>, installed: Set<String>, available: Set<String>): String {
        val supported = installed.map(::normalize).toSet() + "en"
        if(selection != "system") return selection.takeIf { it in available && it in supported } ?: "en"
        return system.map(::normalize).firstOrNull { it in available && it in supported } ?: "en"
    }
}

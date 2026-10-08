package com.lecsync.desk
import org.junit.Assert.*
import org.junit.Test
class LocalePolicyTest {
    private val available=setOf("en","zh","ja","ar","cy","no","tl","he")
    @Test fun followsSystemAndHandlesAliases() {
        assertEquals("ja",LocalePolicy.resolve("system",listOf("xx-ZZ","ja-JP"),setOf("ja-JP","en-US"),available))
        for((system,code) in listOf("nb-NO" to "no","fil-PH" to "tl","iw-IL" to "he","zh-TW" to "zh"))
            assertEquals(code,LocalePolicy.resolve("system",listOf(system),setOf(system),available))
    }
    @Test fun manualSelectionRequiresSystemSupportOtherwiseEnglish() {
        assertEquals("en",LocalePolicy.resolve("cy",listOf("ja-JP"),setOf("ja","en"),available))
        assertEquals("ar",LocalePolicy.resolve("ar",listOf("ja-JP"),setOf("ja","ar"),available))
        assertEquals("en",LocalePolicy.resolve("xx",listOf("ja-JP"),setOf("xx"),available))
        assertEquals("en",LocalePolicy.resolve("system",listOf("xx"),setOf("xx"),available))
    }
}

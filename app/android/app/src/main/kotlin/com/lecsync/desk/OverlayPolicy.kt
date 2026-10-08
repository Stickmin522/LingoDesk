package com.lecsync.desk

internal object OverlayPolicy {
    fun shouldShow(active: Boolean, phase: String, enabled: Boolean, dismissed: Boolean, visible: Boolean): Boolean =
        active && phase in setOf("recording", "paused", "pausing") && enabled && !dismissed && !visible
}

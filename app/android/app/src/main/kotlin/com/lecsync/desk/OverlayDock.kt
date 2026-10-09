package com.lecsync.desk

internal enum class OverlayDockSide { LEFT, RIGHT }

internal object OverlayDock {
    fun sideFor(geometry: IntArray, screenWidth: Int, threshold: Int): OverlayDockSide? = when {
        geometry[0] <= threshold -> OverlayDockSide.LEFT
        screenWidth - geometry[0] - geometry[2] <= threshold -> OverlayDockSide.RIGHT
        else -> null
    }

    fun tuckedGeometry(expanded: IntArray, side: OverlayDockSide, screenWidth: Int, stripWidth: Int): IntArray {
        val strip = stripWidth.coerceIn(1, expanded[2])
        return intArrayOf(
            if (side == OverlayDockSide.LEFT) strip - expanded[2] else screenWidth - strip,
            expanded[1], expanded[2], expanded[3]
        )
    }
}

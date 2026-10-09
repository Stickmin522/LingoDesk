package com.lecsync.desk

internal enum class OverlayCorner(val left: Boolean, val top: Boolean) {
    TOP_LEFT(true, true), TOP_RIGHT(false, true),
    BOTTOM_LEFT(true, false), BOTTOM_RIGHT(false, false)
}

internal object OverlayResize {
    fun cornerAt(x: Float, y: Float, width: Int, height: Int, hitSize: Float): OverlayCorner? {
        val left = x in 0f..hitSize
        val right = x >= width - hitSize && x <= width
        val top = y in 0f..hitSize
        val bottom = y >= height - hitSize && y <= height
        return when {
            left && top -> OverlayCorner.TOP_LEFT
            right && top -> OverlayCorner.TOP_RIGHT
            left && bottom -> OverlayCorner.BOTTOM_LEFT
            right && bottom -> OverlayCorner.BOTTOM_RIGHT
            else -> null
        }
    }

    /** Keep the opposite corner fixed, including at minimum size and screen edges. */
    fun resize(
        origin: IntArray, corner: OverlayCorner, dx: Int, dy: Int,
        screenWidth: Int, screenHeight: Int,
        minWidth: Int, minHeight: Int, maxWidth: Int, maxHeight: Int
    ): IntArray {
        val right = origin[0] + origin[2]
        val bottom = origin[1] + origin[3]
        val availableWidth = if (corner.left) right else screenWidth - origin[0]
        val availableHeight = if (corner.top) bottom else screenHeight - origin[1]
        val widthLimit = minOf(maxWidth, availableWidth).coerceAtLeast(1)
        val heightLimit = minOf(maxHeight, availableHeight).coerceAtLeast(1)
        val width = (origin[2] + if (corner.left) -dx else dx)
            .coerceIn(minOf(minWidth, widthLimit), widthLimit)
        val height = (origin[3] + if (corner.top) -dy else dy)
            .coerceIn(minOf(minHeight, heightLimit), heightLimit)
        return intArrayOf(
            if (corner.left) right - width else origin[0],
            if (corner.top) bottom - height else origin[1],
            width, height
        )
    }
}

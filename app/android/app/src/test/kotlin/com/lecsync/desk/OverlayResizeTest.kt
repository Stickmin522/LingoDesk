package com.lecsync.desk

import org.junit.Assert.*
import org.junit.Test

class OverlayResizeTest {
    private val origin = intArrayOf(100, 150, 280, 180)
    private fun resize(corner: OverlayCorner, dx: Int, dy: Int) =
        OverlayResize.resize(origin, corner, dx, dy, 800, 600, 200, 120, 784, 576)

    @Test fun allFourCornersGrowWhileKeepingTheOppositeCornerFixed() {
        assertArrayEquals(intArrayOf(70, 110, 310, 220), resize(OverlayCorner.TOP_LEFT, -30, -40))
        assertArrayEquals(intArrayOf(100, 110, 310, 220), resize(OverlayCorner.TOP_RIGHT, 30, -40))
        assertArrayEquals(intArrayOf(70, 150, 310, 220), resize(OverlayCorner.BOTTOM_LEFT, -30, 40))
        assertArrayEquals(intArrayOf(100, 150, 310, 220), resize(OverlayCorner.BOTTOM_RIGHT, 30, 40))
    }

    @Test fun minimumSizeDoesNotMoveTheOppositeCorner() {
        for (corner in OverlayCorner.entries) {
            val geometry = resize(corner, if(corner.left) 999 else -999, if(corner.top) 999 else -999)
            assertEquals(200, geometry[2])
            assertEquals(120, geometry[3])
            assertEquals(if(corner.left) 380 else 100, if(corner.left) geometry[0]+geometry[2] else geometry[0])
            assertEquals(if(corner.top) 330 else 150, if(corner.top) geometry[1]+geometry[3] else geometry[1])
        }
    }

    @Test fun allCornersStopAtScreenEdgesWithoutShiftingTheAnchor() {
        for (corner in OverlayCorner.entries) {
            val geometry = resize(corner, if(corner.left) -999 else 999, if(corner.top) -999 else 999)
            assertTrue(geometry[0]>=0 && geometry[1]>=0)
            assertTrue(geometry[0]+geometry[2]<=800 && geometry[1]+geometry[3]<=600)
            assertEquals(if(corner.left) 380 else 100, if(corner.left) geometry[0]+geometry[2] else geometry[0])
            assertEquals(if(corner.top) 330 else 150, if(corner.top) geometry[1]+geometry[3] else geometry[1])
        }
    }

    @Test fun fourCornerHitAreasLeaveButtonsAndCaptionScrollingAvailable() {
        assertEquals(OverlayCorner.TOP_LEFT, OverlayResize.cornerAt(10f,10f,280,180,20f))
        assertEquals(OverlayCorner.TOP_RIGHT, OverlayResize.cornerAt(270f,10f,280,180,20f))
        assertEquals(OverlayCorner.BOTTOM_LEFT, OverlayResize.cornerAt(10f,170f,280,180,20f))
        assertEquals(OverlayCorner.BOTTOM_RIGHT, OverlayResize.cornerAt(270f,170f,280,180,20f))
        assertNull(OverlayResize.cornerAt(258f,22f,280,180,20f))
        assertNull(OverlayResize.cornerAt(140f,90f,280,180,20f))
    }
}

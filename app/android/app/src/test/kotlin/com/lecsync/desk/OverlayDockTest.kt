package com.lecsync.desk

import org.junit.Assert.*
import org.junit.Test

class OverlayDockTest {
    @Test fun onlyWindowsDraggedNearEitherEdgeDock() {
        assertEquals(OverlayDockSide.LEFT,OverlayDock.sideFor(intArrayOf(0,90,280,180),800,12))
        assertEquals(OverlayDockSide.LEFT,OverlayDock.sideFor(intArrayOf(12,90,280,180),800,12))
        assertEquals(OverlayDockSide.RIGHT,OverlayDock.sideFor(intArrayOf(520,90,280,180),800,12))
        assertEquals(OverlayDockSide.RIGHT,OverlayDock.sideFor(intArrayOf(508,90,280,180),800,12))
        assertNull(OverlayDock.sideFor(intArrayOf(250,90,280,180),800,12))
    }

    @Test fun bothSidesLeaveOnlyTheTabOnScreenAndKeepTheExpandedGeometry() {
        for(side in OverlayDockSide.entries){
            val expanded=intArrayOf(if(side==OverlayDockSide.LEFT)0 else 520,90,280,180)
            val saved=expanded.copyOf()
            val tucked=OverlayDock.tuckedGeometry(expanded,side,800,16)
            val visible=minOf(800,tucked[0]+tucked[2])-maxOf(0,tucked[0])
            assertEquals(16,visible)
            assertArrayEquals(saved,expanded)
            assertEquals(90,tucked[1]);assertEquals(280,tucked[2]);assertEquals(180,tucked[3])
        }
    }

    @Test fun tabsStayReachableAfterChangingScreenWidth() {
        val expanded=intArrayOf(520,90,280,180)
        val right=OverlayDock.tuckedGeometry(expanded,OverlayDockSide.RIGHT,400,16)
        assertEquals(384,right[0])
        val left=OverlayDock.tuckedGeometry(expanded,OverlayDockSide.LEFT,400,16)
        assertEquals(-264,left[0])
    }
}

package com.lecsync.desk
import org.junit.Assert.*
import org.junit.Test
class OverlayPolicyTest {
    @Test fun onlyActiveBackgroundSessionsShowAnOverlay() {
        for(phase in listOf("idle","ended","connecting","stopping")) assertFalse(OverlayPolicy.shouldShow(true,phase,true,false,false))
        for(phase in listOf("recording","paused","pausing")) {
            assertTrue(OverlayPolicy.shouldShow(true,phase,true,false,false))
            assertFalse(OverlayPolicy.shouldShow(false,phase,true,false,false))
            assertFalse(OverlayPolicy.shouldShow(true,phase,false,false,false))
            assertFalse(OverlayPolicy.shouldShow(true,phase,true,true,false))
            assertFalse(OverlayPolicy.shouldShow(true,phase,true,false,true))
        }
    }
}

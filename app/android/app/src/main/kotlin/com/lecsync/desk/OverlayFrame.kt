package com.lecsync.desk

import android.content.Context
import android.view.Choreographer
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.ViewConfiguration
import android.widget.FrameLayout

/** Native window gestures avoid Flutter/JNI round trips during each move. */
class OverlayFrame(context: Context, private val service: SessionService) : FrameLayout(context) {
    var controlsVisible = true
    private var mode = 0
    private var startX = 0f
    private var startY = 0f
    private var origin = IntArray(4)
    private var scheduled = false
    private var lastTap = 0L
    private var lastTapX = 0f
    private var lastTapY = 0f
    private val density = resources.displayMetrics.density
    private val pinch = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            service.scaleOverlay(detector.scaleFactor); schedule(); return true
        }
    })
    private fun schedule() {
        if (scheduled) return
        scheduled = true
        Choreographer.getInstance().postFrameCallback { scheduled=false; service.applyOverlayLayout() }
    }
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            val corner = event.x >= width-28*density && event.y >= height-28*density
            val header = controlsVisible && event.y <= 46*density && event.x < width-94*density
            // A hidden toolbar's first touch only reveals it, avoiding accidental button activation.
            mode=when { corner->2;header->1;!controlsVisible->4;else->0 }
            startX=event.rawX;startY=event.rawY;origin=service.overlayGeometry()
            service.overlayInteraction(true)
        }
        if (event.actionMasked == MotionEvent.ACTION_POINTER_DOWN && event.pointerCount>=2) {
            if(mode==0){val cancel=MotionEvent.obtain(event);cancel.action=MotionEvent.ACTION_CANCEL;super.dispatchTouchEvent(cancel);cancel.recycle()}
            mode=3
        }
        if(mode==3){pinch.onTouchEvent(event)}
        if(event.actionMasked==MotionEvent.ACTION_MOVE){
            when(mode){
                1->service.setOverlayGeometry(origin[0]+(event.rawX-startX).toInt(),origin[1]+(event.rawY-startY).toInt(),origin[2],origin[3])
                2->service.setOverlayGeometry(origin[0],origin[1],origin[2]+(event.rawX-startX).toInt(),origin[3]+(event.rawY-startY).toInt())
            }
            if(mode!=0)schedule()
        }
        val consume=mode!=0
        if(event.actionMasked==MotionEvent.ACTION_UP || event.actionMasked==MotionEvent.ACTION_CANCEL){
            if(mode==1 && event.actionMasked==MotionEvent.ACTION_UP &&
                kotlin.math.abs(event.rawX-startX)<ViewConfiguration.get(context).scaledTouchSlop &&
                kotlin.math.abs(event.rawY-startY)<ViewConfiguration.get(context).scaledTouchSlop){
                if(lastTap>0 && event.eventTime-lastTap<=ViewConfiguration.getDoubleTapTimeout() &&
                    kotlin.math.abs(event.rawX-lastTapX)<40*density && kotlin.math.abs(event.rawY-lastTapY)<40*density){
                    service.toggleOverlaySize();lastTap=0L
                }else{lastTap=event.eventTime;lastTapX=event.rawX;lastTapY=event.rawY}
            } else {lastTap=0L}
            if(consume){service.applyOverlayLayout();service.rememberOverlayGeometry()};mode=0
            service.overlayInteraction(false)
        }
        return if(consume)true else super.dispatchTouchEvent(event)
    }
}

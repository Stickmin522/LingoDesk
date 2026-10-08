package com.lecsync.desk

object NativeCore {
    init { System.loadLibrary("lecsync_core") }
    external fun command(request: String): String
    external fun push(microphone: ShortArray, system: ShortArray, count: Int): Int
}

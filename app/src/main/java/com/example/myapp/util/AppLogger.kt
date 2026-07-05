package com.example.myapp.util

import android.util.Log

/**
 * 統一タグロガー（絶対規約11）。println / printStackTrace は使わず必ずここを経由する。
 * タグ: AppLog（全般・起動マーカー）/ ApiLog（通信）/ DbLog（Room）/ UiLog（画面遷移・操作）
 * logcat_error.sh がこれらのタグの E/W を抽出して原因調査に使う。
 */
object AppLogger {
    private const val TAG_APP = "AppLog"
    private const val TAG_API = "ApiLog"
    private const val TAG_DB = "DbLog"
    private const val TAG_UI = "UiLog"

    fun app(msg: String, tr: Throwable? = null) = log(TAG_APP, msg, tr)
    fun api(msg: String, tr: Throwable? = null) = log(TAG_API, msg, tr)
    fun db(msg: String, tr: Throwable? = null) = log(TAG_DB, msg, tr)
    fun ui(msg: String, tr: Throwable? = null) = log(TAG_UI, msg, tr)

    fun appError(msg: String, tr: Throwable? = null) = Log.e(TAG_APP, msg, tr)
    fun apiError(msg: String, tr: Throwable? = null) = Log.e(TAG_API, msg, tr)
    fun dbError(msg: String, tr: Throwable? = null) = Log.e(TAG_DB, msg, tr)
    fun uiError(msg: String, tr: Throwable? = null) = Log.e(TAG_UI, msg, tr)

    private fun log(tag: String, msg: String, tr: Throwable?) {
        if (tr != null) Log.w(tag, msg, tr) else Log.i(tag, msg)
    }
}

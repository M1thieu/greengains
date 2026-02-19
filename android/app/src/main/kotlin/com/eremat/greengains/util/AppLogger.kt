package com.eremat.greengains.util

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileWriter
import java.io.PrintWriter
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Centralized logging for the entire app.
 * Writes to both Logcat (real-time debugging) and a persistent file (crash recovery, later analysis).
 *
 * Usage:
 *   AppLogger.info("MyTag", "User tapped start button")
 *   AppLogger.debug("UploadManager", "Sending batch of 42 readings")
 *   AppLogger.error("LocationService", "GPS timeout", exception)
 */
class AppLogger private constructor(
    private val context: Context
) {
    private val logDir: File = File(context.cacheDir, "logs").apply {
        if (!exists()) mkdirs()
    }

    private val logFile: File = File(logDir, "app.log")
    private val maxFileSizeBytes = 5 * 1024 * 1024 // 5 MB, then rotate
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private val writeMutex = Mutex()
    private val coroutineScope = CoroutineScope(Dispatchers.IO)

    fun info(tag: String, message: String) {
        log("INFO", tag, message, null)
    }

    fun debug(tag: String, message: String) {
        log("DEBUG", tag, message, null)
    }

    fun warn(tag: String, message: String) {
        log("WARN", tag, message, null)
    }

    fun error(tag: String, message: String, throwable: Throwable? = null) {
        log("ERROR", tag, message, throwable)
    }

    private fun log(level: String, tag: String, message: String, throwable: Throwable?) {
        // Always log to Logcat for real-time debugging
        when (level) {
            "DEBUG" -> Log.d(tag, message, throwable)
            "INFO" -> Log.i(tag, message, throwable)
            "WARN" -> Log.w(tag, message, throwable)
            "ERROR" -> Log.e(tag, message, throwable)
        }

        // Write to file asynchronously
        coroutineScope.launch {
            writeMutex.withLock {
                try {
                    val timestamp = dateFormat.format(Date())
                    val threadName = Thread.currentThread().name
                    val logLine = buildString {
                        append("[$timestamp] ")
                        append("[$level] ")
                        append("[$tag] ")
                        append("[$threadName] ")
                        append(message)
                    }

                    PrintWriter(FileWriter(logFile, true)).use { writer ->
                        writer.println(logLine)
                        if (throwable != null) {
                            throwable.printStackTrace(writer)
                        }
                    }

                    // Rotate file if it exceeds max size
                    if (logFile.length() > maxFileSizeBytes) {
                        rotateLogFile()
                    }
                } catch (e: Exception) {
                    Log.e("AppLogger", "Failed to write log file", e)
                }
            }
        }
    }

    private fun rotateLogFile() {
        val archivedFile = File(logDir, "app.log.${System.currentTimeMillis()}.bak")
        logFile.renameTo(archivedFile)

        // Keep only last 3 rotated files
        logDir.listFiles { file ->
            file.name.startsWith("app.log") && file.name.endsWith(".bak")
        }?.sortedByDescending { it.lastModified() }
            ?.drop(3)  // Keep 3, delete older
            ?.forEach { it.delete() }
    }

    /**
     * Read all logs from file.
     * Returns as a single string for easy transmission to Flutter or backend.
     */
    fun readLogs(): String {
        return try {
            logFile.readText()
        } catch (e: Exception) {
            "Failed to read logs: ${e.message}"
        }
    }

    /**
     * Clear all logs.
     */
    fun clearLogs() {
        try {
            logFile.delete()
            logDir.listFiles { file ->
                file.name.startsWith("app.log")
            }?.forEach { it.delete() }
        } catch (e: Exception) {
            Log.e("AppLogger", "Failed to clear logs", e)
        }
    }

    /**
     * Get current log file size in bytes.
     */
    fun getLogFileSizeBytes(): Long {
        return logFile.length()
    }

    companion object {
        @Volatile
        private var instance: AppLogger? = null

        fun init(context: Context) {
            if (instance == null) {
                synchronized(this) {
                    if (instance == null) {
                        instance = AppLogger(context)
                    }
                }
            }
        }

        fun getInstance(): AppLogger {
            return instance ?: throw IllegalStateException(
                "AppLogger not initialized. Call AppLogger.init(context) in MainActivity.onCreate()"
            )
        }

        // Convenience methods
        fun i(tag: String, message: String) = getInstance().info(tag, message)
        fun d(tag: String, message: String) = getInstance().debug(tag, message)
        fun w(tag: String, message: String) = getInstance().warn(tag, message)
        fun e(tag: String, message: String, throwable: Throwable? = null) =
            getInstance().error(tag, message, throwable)
    }
}

package com.example.kerminal

import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import kotlin.concurrent.thread

class ShellManager(
    private val onOutput: (String) -> Unit
) {
    private var process: Process? = null
    private var outputStream: OutputStream? = null

    @Synchronized
    fun start() {
        if (process?.isAlive == true) {
            return
        }

        process = ProcessBuilder("/system/bin/sh")
            .redirectErrorStream(true)
            .start()

        outputStream = process?.outputStream

        val input = process?.inputStream ?: return

        thread(
            start = true,
            isDaemon = true,
            name = "kerminal-shell-reader"
        ) {
            try {
                BufferedReader(InputStreamReader(input)).use { reader ->
                    val buffer = CharArray(1024)

                    while (true) {
                        val count = reader.read(buffer)

                        if (count == -1) {
                            break
                        }

                        if (count > 0) {
                            onOutput(String(buffer, 0, count))
                        }
                    }
                }
            } catch (e: Exception) {
                onOutput("\nShell error: ${e.message}\n")
            }
        }
    }

    @Synchronized
    fun write(command: String) {
        if (process?.isAlive != true) {
            start()
        }

        outputStream?.let { output ->
            try {
                output.write(command.toByteArray(Charsets.UTF_8))
                output.flush()
            } catch (e: Exception) {
                onOutput("\nWrite error: ${e.message}\n")
            }
        }
    }

    @Synchronized
    fun stop() {
        try {
            outputStream?.close()
        } catch (_: Exception) {
        }

        try {
            process?.destroy()
        } catch (_: Exception) {
        }

        outputStream = null
        process = null
    }
}

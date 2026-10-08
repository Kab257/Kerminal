package com.example.kerminal

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val shellChannel = "kerminal/shell"
    private val outputChannel = "kerminal/shell/output"
    private val toolsChannel = "kerminal/tools"

    private var outputSink: EventChannel.EventSink? = null

    private lateinit var shellManager: ShellManager
    private lateinit var toolManager: ToolManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        shellManager = ShellManager { output ->
            runOnUiThread {
                outputSink?.success(output)
            }
        }

        toolManager = ToolManager(this)
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shellChannel
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "start" -> {
                    shellManager.start()
                    result.success(null)
                }

                "write" -> {
                    val command =
                        call.argument<String>("command")

                    if (command == null) {
                        result.error(
                            "INVALID_COMMAND",
                            "Command is missing",
                            null
                        )
                    } else {
                        shellManager.write(command)
                        result.success(null)
                    }
                }

                "stop" -> {
                    shellManager.stop()
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            outputChannel
        ).setStreamHandler(
            object : EventChannel.StreamHandler {

                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?
                ) {
                    outputSink = events
                }

                override fun onCancel(
                    arguments: Any?
                ) {
                    outputSink = null
                }
            }
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            toolsChannel
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "listDirectory" -> {

                    val path =
                        call.argument<String>("path")

                    if (path == null) {
                        result.error(
                            "INVALID_PATH",
                            "Path is missing",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        result.success(
                            toolManager.listDirectory(path)
                        )
                    } catch (e: Exception) {
                        result.error(
                            "LIST_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                "storageInfo" -> {

                    try {
                        result.success(
                            toolManager.storageInfo()
                        )
                    } catch (e: Exception) {
                        result.error(
                            "STORAGE_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        shellManager.stop()
        super.onDestroy()
    }
}
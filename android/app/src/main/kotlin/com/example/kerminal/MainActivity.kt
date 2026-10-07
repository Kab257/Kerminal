package com.example.kerminal

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val shellChannel = "kerminal/shell"
    private val outputChannel = "kerminal/shell/output"

    private var outputSink: EventChannel.EventSink? = null

    private lateinit var shellManager: ShellManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        shellManager = ShellManager { output ->
            runOnUiThread {
                outputSink?.success(output)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
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
                    val command = call.argument<String>("command")

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

                override fun onCancel(arguments: Any?) {
                    outputSink = null
                }
            }
        )
    }

    override fun onDestroy() {
        shellManager.stop()
        super.onDestroy()
    }
}

package com.example.kerminal

import android.content.Context
import android.os.StatFs
import java.io.File
import java.util.Locale

class ToolManager(
    private val context: Context
) {

    fun listDirectory(
        path: String
    ): List<Map<String, Any>> {

        val directory = File(path)

        if (!directory.exists()) {
            throw IllegalArgumentException(
                "Path does not exist: $path"
            )
        }

        if (!directory.isDirectory) {
            throw IllegalArgumentException(
                "Path is not a directory: $path"
            )
        }

        val files =
            directory.listFiles()
                ?.toList()
                ?: emptyList()

        return files
            .sortedWith(
                compareBy<File>(
                    { !it.isDirectory },
                    {
                        it.name.lowercase(
                            Locale.getDefault()
                        )
                    }
                )
            )
            .map { file ->

                val extension =
                    file.extension
                        .lowercase(
                            Locale.getDefault()
                        )

                mapOf<String, Any>(
                    "name" to file.name,
                    "path" to file.absolutePath,
                    "isDirectory" to file.isDirectory,
                    "size" to if (file.isFile) {
                        file.length()
                    } else {
                        0L
                    },
                    "modified" to file.lastModified(),
                    "extension" to extension,
                    "type" to detectMimeType(extension)
                )
            }
    }

    fun storageInfo(): Map<String, Any> {

        val storagePath =
            File(
                "/storage/emulated/0"
            )

        val stat =
            StatFs(
                storagePath.absolutePath
            )

        val blockSize =
            stat.blockSizeLong

        val total =
            stat.blockCountLong *
                    blockSize

        val free =
            stat.availableBlocksLong *
                    blockSize

        val used =
            total - free

        return mapOf(
            "total" to total,
            "used" to used,
            "free" to free
        )
    }

    private fun detectMimeType(
        extension: String
    ): String {

        return when (extension) {

            "jpg",
            "jpeg",
            "png",
            "gif",
            "webp",
            "bmp",
            "heic",
            "heif" ->
                "image/*"

            "mp4",
            "mkv",
            "avi",
            "mov",
            "webm",
            "3gp" ->
                "video/*"

            "mp3",
            "wav",
            "flac",
            "aac",
            "ogg",
            "m4a" ->
                "audio/*"

            "pdf" ->
                "application/pdf"

            "txt",
            "log",
            "md" ->
                "text/plain"

            "zip",
            "rar",
            "7z",
            "tar",
            "gz" ->
                "application/archive"

            else ->
                "application/octet-stream"
        }
    }
}
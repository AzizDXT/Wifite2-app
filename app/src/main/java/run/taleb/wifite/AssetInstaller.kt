package run.taleb.wifite

import android.content.Context
import java.io.File

/**
 * Extracts the bundled `assets/payload/` tree (wifite source + ARM binaries)
 * into the app's private files dir and marks the binaries executable.
 */
object AssetInstaller {
    const val PAYLOAD = "payload"

    /** Extracts the payload and returns its destination directory. */
    fun install(ctx: Context, onLog: (String) -> Unit): File {
        val dest = File(ctx.filesDir, PAYLOAD)
        onLog("[*] Installing payload -> ${dest.absolutePath}")
        if (dest.exists()) dest.deleteRecursively()
        copyAsset(ctx, PAYLOAD, dest)

        val bin = File(dest, "bin")
        var count = 0
        bin.listFiles()?.forEach { f ->
            if (f.setExecutable(true, false)) count++
        }
        onLog("[+] Extracted payload; marked $count binaries executable")
        return dest
    }

    /** Recursively copies an asset path (file or directory) to [dest]. */
    private fun copyAsset(ctx: Context, path: String, dest: File) {
        val children = ctx.assets.list(path) ?: emptyArray()
        if (children.isEmpty()) {
            // Leaf: treat as a file.
            dest.parentFile?.mkdirs()
            ctx.assets.open(path).use { input ->
                dest.outputStream().use { input.copyTo(it) }
            }
        } else {
            dest.mkdirs()
            for (child in children) copyAsset(ctx, "$path/$child", File(dest, child))
        }
    }
}

package run.taleb.oneshot

import java.io.OutputStreamWriter

/** Thin wrapper around an on-demand `su` shell. */
object RootShell {

    /** Returns true if `su` grants us uid 0. */
    fun isRootAvailable(): Boolean = try {
        val p = ProcessBuilder("su", "-c", "id -u")
            .redirectErrorStream(true)
            .start()
        val out = p.inputStream.bufferedReader().readText().trim()
        p.waitFor()
        out.startsWith("0")
    } catch (e: Exception) {
        false
    }

    /**
     * Runs [command] in a root shell, streaming combined stdout/stderr
     * line-by-line to [onLine]. Blocks until the shell exits, so call it
     * from a background thread. Returns the exit code.
     */
    fun stream(command: String, onLine: (String) -> Unit): Int {
        val p = ProcessBuilder("su").redirectErrorStream(true).start()
        OutputStreamWriter(p.outputStream).use { w ->
            w.write(command)
            w.write("\nexit\n")
            w.flush()
            p.inputStream.bufferedReader().forEachLine(onLine)
        }
        return p.waitFor()
    }
}

package run.taleb.wifite

import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import run.taleb.wifite.databinding.ActivityMainBinding
import java.io.File
import java.io.OutputStreamWriter
import kotlin.concurrent.thread

class MainActivity : AppCompatActivity() {

    private lateinit var b: ActivityMainBinding
    @Volatile private var running = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityMainBinding.inflate(layoutInflater)
        setContentView(b.root)

        b.ifaceInput.setText("wlan1")

        b.btnCheck.setOnClickListener { checkRoot() }
        b.btnInstall.setOnClickListener { installPayload() }
        b.btnStart.setOnClickListener { startWifite() }
        b.btnStop.setOnClickListener { stopWifite() }
    }

    private fun log(line: String) = runOnUiThread {
        b.logView.append(line + "\n")
        b.logScroll.post { b.logScroll.fullScroll(View.FOCUS_DOWN) }
    }

    private fun checkRoot() = thread {
        val ok = RootShell.isRootAvailable()
        runOnUiThread {
            b.statusView.text =
                getString(if (ok) R.string.root_ok else R.string.root_missing)
        }
        log(if (ok) "[+] Root access granted" else "[!] No root access (su failed)")
    }

    private fun installPayload() = thread {
        try {
            val dir = AssetInstaller.install(applicationContext) { log(it) }
            log("[+] Ready at ${dir.absolutePath}")
        } catch (e: Exception) {
            log("[!] Install failed: ${e.message}")
        }
    }

    private fun startWifite() {
        if (running) { log("[!] Already running"); return }

        val iface = b.ifaceInput.text.toString().trim().ifEmpty { "wlan1" }
        val extra = b.argsInput.text.toString().trim()
        val payload = File(filesDir, AssetInstaller.PAYLOAD)

        if (!File(payload, "Wifite.py").exists()) {
            log("[!] Payload not installed — tap \"Install Payload\" first."); return
        }

        running = true
        thread {
            try {
                val base = payload.absolutePath
                val cmd = buildString {
                    append("cd $base && ")
                    append("export PATH=$base/bin:\$PATH && ")
                    append("export PYTHONDONTWRITEBYTECODE=1 && ")
                    append("$base/bin/python3 $base/Wifite.py -i $iface --kill")
                    if (extra.isNotEmpty()) append(" $extra")
                }
                log("[*] $cmd")
                val p = ProcessBuilder("su").redirectErrorStream(true).start()
                OutputStreamWriter(p.outputStream).use { w ->
                    w.write(cmd); w.write("\nexit\n"); w.flush()
                    p.inputStream.bufferedReader().forEachLine { log(it) }
                }
                log("[*] wifite exited (${p.waitFor()})")
            } catch (e: Exception) {
                log("[!] Error: ${e.message}")
            } finally {
                running = false
            }
        }
    }

    private fun stopWifite() {
        log("[*] Stopping wifite (SIGINT for clean teardown)...")
        thread {
            // wifite traps SIGINT to restore the interface; fall back to TERM.
            RootShell.stream("pkill -INT -f Wifite.py 2>/dev/null; " +
                    "sleep 2; pkill -f Wifite.py 2>/dev/null; true") { log(it) }
            running = false
        }
    }
}

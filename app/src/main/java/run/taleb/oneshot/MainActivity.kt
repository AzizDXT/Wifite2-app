package run.taleb.oneshot

import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import run.taleb.oneshot.databinding.ActivityMainBinding
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

        // OneShot uses wpa_supplicant on a managed interface — the internal
        // wlan0 works on a rooted phone; no monitor mode / external adapter.
        b.ifaceInput.setText("wlan0")

        b.btnCheck.setOnClickListener { checkRoot() }
        b.btnInstall.setOnClickListener { installPayload() }
        b.btnStart.setOnClickListener { startOneShot() }
        b.btnStop.setOnClickListener { stopOneShot() }
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

    private fun startOneShot() {
        if (running) { log("[!] Already running"); return }

        val iface = b.ifaceInput.text.toString().trim().ifEmpty { "wlan0" }
        val extra = b.argsInput.text.toString().trim()
        val payload = File(filesDir, AssetInstaller.PAYLOAD)

        if (!File(payload, "oneshot.py").exists()) {
            log("[!] Payload not installed — tap \"Install Payload\" first."); return
        }

        running = true
        thread {
            try {
                val base = payload.absolutePath
                // Default to interactive Pixie Dust (-K). The user can override
                // or add flags (e.g. -b <bssid>, -B, --pbc) via the args field.
                val flags = extra.ifEmpty { "-K" }
                val cmd = buildString {
                    append("cd $base && ")
                    append("export PATH=$base/bin:\$PATH && ")
                    append("export PYTHONDONTWRITEBYTECODE=1 && ")
                    append("$base/bin/python3 $base/oneshot.py -i $iface $flags")
                }
                log("[*] $cmd")
                val p = ProcessBuilder("su").redirectErrorStream(true).start()
                OutputStreamWriter(p.outputStream).use { w ->
                    w.write(cmd); w.write("\nexit\n"); w.flush()
                    p.inputStream.bufferedReader().forEachLine { log(it) }
                }
                log("[*] oneshot exited (${p.waitFor()})")
            } catch (e: Exception) {
                log("[!] Error: ${e.message}")
            } finally {
                running = false
            }
        }
    }

    private fun stopOneShot() {
        log("[*] Stopping oneshot...")
        thread {
            // OneShot spawns its own wpa_supplicant; clean both up.
            RootShell.stream(
                "pkill -INT -f oneshot.py 2>/dev/null; sleep 1; " +
                "pkill -f oneshot.py 2>/dev/null; " +
                "pkill -f 'wpa_supplicant.*p2p-dev' 2>/dev/null; true"
            ) { log(it) }
            running = false
        }
    }
}

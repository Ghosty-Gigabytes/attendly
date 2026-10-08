package dev.attendly.attendly

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.googlecode.tesseract.android.TessBaseAPI
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

class ImsBridge(private val context: Context) {
    private val ocrExecutor = Executors.newSingleThreadExecutor()

    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.attendly/credentials")
            .setMethodCallHandler { call, result ->
                val prefs = context.getSharedPreferences("ims_credentials", Context.MODE_PRIVATE)
                try {
                    when (call.method) {
                        "clear" -> {
                            check(prefs.edit().clear().commit())
                            KeyStore.getInstance("AndroidKeyStore").apply { load(null); deleteEntry("attendly_ims") }
                            result.success(null)
                        }
                        "read" -> {
                            val saved = prefs.getString("encrypted", null)
                            if (saved == null) { result.success(null) }
                            else {
                                val parts = saved.split(":")
                                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                                cipher.init(Cipher.DECRYPT_MODE, credentialKey(), GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
                                val json = JSONObject(String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8))
                                result.success(mapOf("username" to json.getString("username"), "password" to json.getString("password")))
                            }
                        }
                        "write" -> {
                            val username = requireNotNull(call.argument<String>("username"))
                            val password = requireNotNull(call.argument<String>("password"))
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.ENCRYPT_MODE, credentialKey())
                            val json = JSONObject().put("username", username).put("password", password).toString()
                            val encrypted = cipher.doFinal(json.toByteArray(Charsets.UTF_8))
                            val saved = Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(encrypted, Base64.NO_WRAP)
                            check(prefs.edit().putString("encrypted", saved).commit())
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("SECURE_STORAGE", "Could not access saved IMS login", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.attendly/ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val imagePath = call.argument<String>("imagePath")
                val dataPath = call.argument<String>("dataPath")
                if (imagePath == null || dataPath == null) {
                    result.error("INVALID_INPUT", "Missing OCR input", null)
                    return@setMethodCallHandler
                }
                ocrExecutor.execute {
                    val outcome = runCatching {
                        val tess = TessBaseAPI()
                        try {
                            check(tess.init(dataPath, "mydigits")) { "Custom OCR model could not be initialized" }
                            tess.setPageSegMode(TessBaseAPI.PageSegMode.PSM_SPARSE_TEXT)
                            tess.setImage(File(imagePath))
                            tess.getUTF8Text()
                        } finally {
                            tess.recycle()
                        }
                    }
                    Handler(Looper.getMainLooper()).post {
                        outcome.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("OCR_FAILED", "Could not read CAPTCHA; use manual entry", null) }
                        )
                    }
                }
            }
    }

    private fun credentialKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("attendly_ims", null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder("attendly_ims", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        return generator.generateKey()
    }

    fun close() { ocrExecutor.shutdown() }
}

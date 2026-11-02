package com.adreemk.school.lamin_school

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.spec.X509EncodedKeySpec

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.adreemk.lamin/device_identity"
        private const val KEY_ALIAS = "com.adreemk.lamin.offline.device.v1"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getOrCreateIdentity" -> {
                        val pair = loadKeyPair(createIfMissing = true)
                            ?: throw IllegalStateException("Unable to create device key.")
                        result.success(identityMap(pair))
                    }

                    "getExistingIdentity" -> {
                        val pair = loadKeyPair(createIfMissing = false)
                        result.success(pair?.let { identityMap(it) })
                    }

                    "signChallenge" -> {
                        val encoded = call.argument<String>("challenge")
                            ?: throw IllegalArgumentException("Missing challenge.")
                        val challenge = Base64.decode(encoded, Base64.NO_WRAP)
                        require(challenge.isNotEmpty()) { "Empty challenge." }
                        val pair = loadKeyPair(createIfMissing = false)
                            ?: throw IllegalStateException("Device key is not enrolled.")
                        val signature = sign(pair.private, challenge)
                        result.success(
                            mapOf(
                                "device_id" to deviceId(pair.public.encoded),
                                "signature" to Base64.encodeToString(signature, Base64.NO_WRAP)
                            )
                        )
                    }

                    "verifyBinding" -> {
                        val encoded = call.argument<String>("challenge")
                            ?: throw IllegalArgumentException("Missing challenge.")
                        val challenge = Base64.decode(encoded, Base64.NO_WRAP)
                        val savedSignature = Base64.decode(
                            call.argument<String>("signature")
                                ?: throw IllegalArgumentException("Missing signature."),
                            Base64.NO_WRAP
                        )
                        val expectedDeviceId = call.argument<String>("device_id") ?: ""
                        val expectedPublicKey = Base64.decode(
                            call.argument<String>("public_key")
                                ?: throw IllegalArgumentException("Missing public key."),
                            Base64.NO_WRAP
                        )
                        val pair = loadKeyPair(createIfMissing = false)
                        val valid = pair != null &&
                            challenge.isNotEmpty() &&
                            savedSignature.isNotEmpty() &&
                            expectedDeviceId == deviceId(pair.public.encoded) &&
                            MessageDigest.isEqual(expectedPublicKey, pair.public.encoded) &&
                            verifySignature(pair.public.encoded, challenge, savedSignature) &&
                            provePrivateKey(pair.private, pair.public.encoded, challenge)
                        result.success(valid)
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "DEVICE_KEY_ERROR",
                    error.message ?: "Android Keystore operation failed.",
                    null
                )
            }
        }
    }

    private fun loadKeyPair(createIfMissing: Boolean): KeyPair? {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        if (!keyStore.containsAlias(KEY_ALIAS)) {
            if (!createIfMissing) return null
            val generator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                "AndroidKeyStore"
            )
            val parameters = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(false)
                .build()
            generator.initialize(parameters)
            generator.generateKeyPair()
        }

        val certificate = keyStore.getCertificate(KEY_ALIAS) ?: return null
        val privateKey = keyStore.getKey(KEY_ALIAS, null) as? PrivateKey ?: return null
        return KeyPair(certificate.publicKey, privateKey)
    }

    private fun identityMap(pair: KeyPair): Map<String, Any> {
        val encoded = pair.public.encoded
        val keyInfo = try {
            val factory = KeyFactory.getInstance(pair.private.algorithm, "AndroidKeyStore")
            factory.getKeySpec(pair.private, KeyInfo::class.java)
        } catch (_: Exception) {
            null
        }
        return mapOf(
            "device_id" to deviceId(encoded),
            "public_key" to Base64.encodeToString(encoded, Base64.NO_WRAP),
            "hardware_backed" to (keyInfo?.isInsideSecureHardware == true)
        )
    }

    private fun deviceId(publicKey: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(publicKey)
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun sign(privateKey: PrivateKey, challenge: ByteArray): ByteArray {
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(privateKey)
        signer.update(challenge)
        return signer.sign()
    }

    private fun verifySignature(
        publicKey: ByteArray,
        challenge: ByteArray,
        signature: ByteArray
    ): Boolean {
        val key = KeyFactory.getInstance("EC")
            .generatePublic(X509EncodedKeySpec(publicKey))
        val verifier = Signature.getInstance("SHA256withECDSA")
        verifier.initVerify(key)
        verifier.update(challenge)
        return verifier.verify(signature)
    }

    private fun provePrivateKey(
        privateKey: PrivateKey,
        publicKey: ByteArray,
        challenge: ByteArray
    ): Boolean {
        val freshSignature = sign(privateKey, challenge)
        return verifySignature(publicKey, challenge, freshSignature)
    }
}

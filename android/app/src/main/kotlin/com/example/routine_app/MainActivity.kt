package com.example.routine_app

import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private val stepChannelName = "routine_app/step_counter"
    private val stepEventsChannelName = "routine_app/step_counter_events"
    private val activityRecognitionRequestCode = 4201
    private lateinit var sensorManager: SensorManager
    private var stepCounterSensor: Sensor? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingSensorResult: MethodChannel.Result? = null
    private var stepEventSink: EventChannel.EventSink? = null
    private var sensorRegistered = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            stepChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasStepCounter" -> result.success(stepCounterSensor != null)
                "hasActivityRecognition" -> result.success(hasActivityRecognition())
                "requestActivityRecognition" -> requestActivityRecognition(result)
                "getStepCounter" -> getStepCounter(result)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            stepEventsChannelName,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                stepEventSink = events
                registerStepSensor()
            }

            override fun onCancel(arguments: Any?) {
                stepEventSink = null
                unregisterStepSensorIfIdle()
            }
        })
    }

    private fun hasActivityRecognition(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(android.Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestActivityRecognition(result: MethodChannel.Result) {
        if (hasActivityRecognition()) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(android.Manifest.permission.ACTIVITY_RECOGNITION),
            activityRecognitionRequestCode,
        )
    }

    private fun getStepCounter(result: MethodChannel.Result) {
        val sensor = stepCounterSensor
        if (sensor == null) {
            result.error("SENSOR_UNAVAILABLE", "TYPE_STEP_COUNTER no está disponible.", null)
            return
        }
        if (!hasActivityRecognition()) {
            result.error("PERMISSION_REQUIRED", "ACTIVITY_RECOGNITION no está concedido.", null)
            return
        }
        if (pendingSensorResult != null) {
            result.error("SENSOR_BUSY", "Ya se está leyendo el sensor.", null)
            return
        }
        pendingSensorResult = result
        if (!registerStepSensor()) {
            pendingSensorResult = null
            result.error("SENSOR_ERROR", "No se pudo registrar el sensor.", null)
        }
    }

    private fun registerStepSensor(): Boolean {
        if (sensorRegistered) return true
        val sensor = stepCounterSensor ?: return false
        sensorRegistered = sensorManager.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_NORMAL,
        )
        return sensorRegistered
    }

    private fun unregisterStepSensorIfIdle() {
        if (stepEventSink == null && pendingSensorResult == null && sensorRegistered) {
            sensorManager.unregisterListener(this)
            sensorRegistered = false
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        val value = event.values.firstOrNull()?.toDouble() ?: return
        stepEventSink?.success(value)
        pendingSensorResult?.let { result ->
            pendingSensorResult = null
            result.success(value)
        }
        unregisterStepSensorIfIdle()
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) = Unit

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != activityRecognitionRequestCode) return
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        result.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }

    override fun onDestroy() {
        if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
        sensorRegistered = false
        stepEventSink = null
        pendingSensorResult?.error("ACTIVITY_DESTROYED", "La actividad se cerró.", null)
        pendingSensorResult = null
        super.onDestroy()
    }
}

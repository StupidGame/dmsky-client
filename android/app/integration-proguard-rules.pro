-keep class dev.flutter.plugins.integration_test.** { *; }
# The instrumentation APK shares these libraries with the target APK. Keep
# their original names so its manifest and reflection can find the runner.
-keep class androidx.test.** { *; }
-keep class org.junit.** { *; }
-keep class org.hamcrest.** { *; }

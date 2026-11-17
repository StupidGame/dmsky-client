package app.dmsky.dmsky_client

import androidx.test.rule.ActivityTestRule
import dev.flutter.plugins.integration_test.FlutterTestRunner
import org.junit.Rule
import org.junit.runner.RunWith

@RunWith(FlutterTestRunner::class)
class NativePlayTest {
    @Rule
    @JvmField
    val activity = ActivityTestRule(MainActivity::class.java, true, false)
}

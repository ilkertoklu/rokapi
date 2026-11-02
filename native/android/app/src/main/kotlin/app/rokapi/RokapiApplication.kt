package app.rokapi

import android.app.Application
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.purchasekit.android.PaywallComponent

class RokapiApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
        Hotwire.config.jsonConverter = KotlinXJsonConverter()
        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("paywall", ::PaywallComponent)
        )
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                remoteFileUrl = "${BuildConfig.ROOT_URL}/hotwire_native/path_configuration.json"
            )
        )
    }
}

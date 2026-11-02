package app.rokapi

import android.app.Application
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration

class RokapiApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                remoteFileUrl = "${BuildConfig.ROOT_URL}/hotwire_native/path_configuration.json"
            )
        )
    }
}

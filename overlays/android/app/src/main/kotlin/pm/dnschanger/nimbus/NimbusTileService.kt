package pm.dnschanger.nimbus

import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(24)
class NimbusTileService : TileService() {
    override fun onClick() {
        val intent = Intent(this, NimbusVpnService::class.java)
            .setAction(NimbusVpnService.ACTION_START)
        if (Build.VERSION.SDK_INT >= 26) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        qsTile?.state = Tile.STATE_ACTIVE
        qsTile?.updateTile()
    }
}

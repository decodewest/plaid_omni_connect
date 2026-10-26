package com.decodewest.plaid_omni_connect

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class PlaidOmniConnectPluginTest {
    @Test
    fun terminalMessagesCloseLink() {
        assertTrue(isTerminalLinkMessage("""{"type":"success","publicToken":"public-sandbox"}"""))
        assertTrue(isTerminalLinkMessage("""{"error":null,"type":"exit","metadata":{"status":""}}"""))
        assertTrue(isTerminalLinkMessage("""{"type":"error","error":"WebView2 runtime is unavailable"}"""))
        assertFalse(isTerminalLinkMessage("""{"type":"event","eventName":"OPEN"}"""))
    }
}

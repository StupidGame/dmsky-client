package app.dmsky.dmsky_client.notifications

import org.json.JSONException
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class NotificationBatchTest {
    private val old = """{"id":"a","createdAt":"2026-11-13T00:00:00.000Z","type":"follow","user":{"username":"alice"}}"""
    private val new = """{"id":"b","createdAt":"2026-11-13T01:00:00.000Z","type":"mention","user":{"name":"Bob"}}"""

    @Test fun firstCheckEstablishesCursorWithoutShowingHistory() {
        val batch = NotificationBatch.parse("[$new,$old]", false, emptySet())
        assertEquals("b", batch.newestId)
        assertTrue(batch.unread.isEmpty())
    }

    @Test fun cursorSupportsAscendingAndDescendingApiPages() {
        for (body in listOf("[$old,$new]", "[$new,$old]")) {
            val batch = NotificationBatch.parse(body, true, setOf("a"))
            assertEquals("b", batch.newestId)
            assertEquals(listOf("b"), batch.unread.map { it.getString("id") })
        }
    }

    @Test fun repeatedIdsAndReadNotificationsDoNotAlert() {
        val read = JSONObject(new).put("isRead", true)
        val batch = NotificationBatch.parse("[$old,$old,$read]", true, setOf("a"))
        assertTrue(batch.unread.isEmpty())
        assertEquals(listOf("a", "b"), batch.ids)
    }

    @Test fun firstNotificationAfterEmptyBaselineIsDelivered() {
        assertNull(NotificationBatch.parse("[]", false, emptySet()).newestId)
        assertEquals(1, NotificationBatch.parse("[$new]", true, emptySet()).unread.size)
    }

    @Test fun formattingWorksWithoutOptionalActorData() {
        assertEquals("Bobさんからのメンション", NotificationBatch.describe(JSONObject(new)))
        assertEquals("新しい通知が届きました", NotificationBatch.describe(JSONObject("""{"type":"unknown"}""")))
        assertEquals("アプリからの通知", NotificationBatch.describe(JSONObject("""{"type":"app","header":null}""")))
    }

    @Test(expected = JSONException::class) fun malformedResponsesCannotAdvanceCursor() {
        NotificationBatch.parse("{\"error\":{}}", true, emptySet())
    }

    @Test fun accountIdentityIncludesUserServerAndPort() {
        val one = NotificationStore.accountKey("https://one.example", "alice")
        assertTrue(one.matches(Regex("[0-9a-f]{64}")))
        assertNotEquals(one, NotificationStore.accountKey("https://one.example", "bob"))
        assertNotEquals(one, NotificationStore.accountKey("https://two.example", "alice"))
        assertNotEquals(one, NotificationStore.accountKey("https://one.example:8443", "alice"))
    }

    @Test fun onlyHttpsOriginsCanReceiveStoredCredentials() {
        assertEquals("https://example.com:8443", NotificationStore.validateOrigin("https://EXAMPLE.com:8443/"))
        for (origin in listOf("http://example.com", "https://user:pass@example.com", "https://example.com/api", "https://example.com?x=1")) {
            assertThrows(IllegalArgumentException::class.java) { NotificationStore.validateOrigin(origin) }
        }
    }

    @Test fun encryptedRecordSerializationKeepsCursorAndInterval() {
        val account = NotificationAccount("https://one.example", "alice", "test-token", true,
            intervalMinutes = 30, initialized = true, sinceId = "b", seenIds = listOf("a", "b"), lastCheck = 123)
        assertEquals(account, NotificationAccount.fromJson(account.toJson()))
    }
}

package app.dmsky.dmsky_client.notifications

import org.json.JSONArray
import org.json.JSONObject

/** Misskey may return ascending pages when sinceId is supplied. */
data class NotificationBatch(val ids: List<String>, val newestId: String?, val unread: List<JSONObject>) {
    companion object {
        fun parse(body: String, initialized: Boolean, seenIds: Set<String>): NotificationBatch {
            val array = JSONArray(body)
            val items = (0 until array.length()).map { array.getJSONObject(it) }
                .filter { it.optString("id").isNotBlank() }.distinctBy { it.getString("id") }
            val newest = items.maxWithOrNull(
                compareBy<JSONObject> { it.optString("createdAt") }.thenBy { it.getString("id") }
            )
            return NotificationBatch(
                items.map { it.getString("id") },
                newest?.getString("id"),
                if (!initialized) emptyList() else items.filter {
                    it.getString("id") !in seenIds && !it.optBoolean("isRead", false)
                },
            )
        }

        fun describe(item: JSONObject): String {
            val user = item.optJSONObject("user")
            val name = user?.optString("name")?.takeIf { it.isNotBlank() && it != "null" }
                ?: user?.optString("username")?.takeIf { it.isNotBlank() }
                ?: "ユーザー"
            return when (item.optString("type")) {
                "mention" -> "${name}さんからのメンション"
                "reply" -> "${name}さんからの返信"
                "quote" -> "${name}さんからの引用"
                "renote", "renote:grouped" -> "Renoteされました"
                "reaction", "reaction:grouped" -> "リアクションが届きました"
                "follow" -> "${name}さんにフォローされました"
                "receiveFollowRequest" -> "フォローリクエストが届きました"
                "followRequestAccepted" -> "フォローリクエストが承認されました"
                "pollEnded" -> "投票が終了しました"
                "app" -> item.optString("header").takeIf { it.isNotBlank() && it != "null" }
                    ?: "アプリからの通知"
                else -> "新しい通知が届きました"
            }
        }
    }
}

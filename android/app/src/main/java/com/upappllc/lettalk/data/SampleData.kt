package com.upappllc.lettalk.data

/**
 * Sample data so every screen can be seen and tested before the app is connected to the
 * Let Talk server. Nothing here talks to the backend.
 */
data class Contact(
    val id: String,
    val name: String,
    val number: String,
    val email: String = "",
    val online: Boolean = false,
)

data class Message(
    val id: String,
    val fromMe: Boolean,
    /** What I see: my own text, or the incoming text already translated into my language. */
    val text: String,
    /** What the sender actually typed, when it was translated. */
    val original: String? = null,
    val sourceLanguage: String? = null,
    val time: String,
    val read: Boolean = true,
)

data class ChatPreview(
    val contact: Contact,
    val lastMessage: String,
    val time: String,
    val unread: Int = 0,
)

enum class CallDirection { Outgoing, Incoming, Missed }

data class CallRecord(
    val id: String,
    val contact: Contact,
    val video: Boolean,
    val direction: CallDirection,
    val time: String,
    val duration: String? = null,
)

data class Language(val code: String, val name: String, val native: String)

object Sample {
    val me = Contact("me", "Test Acct", "(404) 621-7398", "you@example.com")

    val maria = Contact("1", "Maria Lopez", "(470) 555-0142", "maria@example.com", online = true)
    val kenji = Contact("2", "Kenji Sato", "(678) 555-0199", "kenji@example.com")
    val amira = Contact("3", "Amira Haddad", "(404) 555-0173", "amira@example.com", online = true)
    val luc = Contact("4", "Luc Moreau", "(770) 555-0118", "luc@example.com")

    val contacts = listOf(amira, kenji, luc, maria).sortedBy { it.name }

    val chats = listOf(
        ChatPreview(maria, "Are you going to be at the store at 3pm?", "12:16 PM", unread = 2),
        ChatPreview(kenji, "Thanks, see you tomorrow!", "11:02 AM"),
        ChatPreview(amira, "Hello, how are you?", "Yesterday"),
    )

    fun messages(contactId: String): List<Message> = when (contactId) {
        "1" -> listOf(
            Message("m1", false, "Hi, how's it going?", "¡Hola, qué tal?", "Spanish", "12:33 AM"),
            Message("m2", false, "Are you OK?", "¿Estás bien?", "Spanish", "12:34 AM"),
            Message("m3", true, "Yeah bro, I'm just chilling", time = "12:35 AM"),
            Message("m4", true, "What are you doing?", time = "12:36 AM"),
            Message("m5", false, "Are you going to be at the store at 3pm?",
                "¿Vas a estar en la tienda a las 3 p.m.?", "Spanish", "12:16 PM"),
        )
        "2" -> listOf(
            Message("k1", false, "Thanks, see you tomorrow!", "ありがとう、また明日！", "Japanese", "11:02 AM"),
        )
        else -> listOf(
            Message("a1", false, "Hello, how are you?", "مرحبا، كيف حالك؟", "Arabic", "Yesterday"),
        )
    }

    val calls = listOf(
        CallRecord("c1", maria, video = false, CallDirection.Outgoing, "12:03 PM", "0:47"),
        CallRecord("c2", maria, video = true, CallDirection.Missed, "11:25 AM"),
        CallRecord("c3", kenji, video = false, CallDirection.Incoming, "10:26 AM", "0:31"),
        CallRecord("c4", amira, video = true, CallDirection.Outgoing, "Yesterday", "4:12"),
    )

    val languages = listOf(
        Language("en", "English", "English"),
        Language("es", "Spanish", "Español"),
        Language("fr", "French", "Français"),
        Language("de", "German", "Deutsch"),
        Language("it", "Italian", "Italiano"),
        Language("pt", "Portuguese", "Português"),
        Language("ru", "Russian", "Русский"),
        Language("ja", "Japanese", "日本語"),
        Language("ko", "Korean", "한국어"),
        Language("zh", "Chinese", "中文"),
        Language("ar", "Arabic", "العربية"),
        Language("hi", "Hindi", "हिन्दी"),
    )

    val states = listOf("Georgia", "Alabama", "California", "Florida", "New York", "Texas")

    fun areaCodes(state: String): List<String> = when (state) {
        "Georgia" -> listOf("404", "470", "678", "770", "706", "912")
        "Alabama" -> listOf("205", "251", "256", "334")
        "California" -> listOf("213", "310", "415", "510", "619", "818")
        "Florida" -> listOf("305", "407", "561", "727", "813", "904")
        "New York" -> listOf("212", "315", "347", "518", "646", "718")
        else -> listOf("214", "281", "512", "713", "817", "972")
    }

    fun numbers(areaCode: String): List<String> = listOf(
        "($areaCode) 621-7398", "($areaCode) 318-4402", "($areaCode) 555-2081",
        "($areaCode) 742-9015", "($areaCode) 230-6677"
    )
}

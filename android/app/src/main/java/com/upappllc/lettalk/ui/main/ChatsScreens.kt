package com.upappllc.lettalk.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.DoneAll
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.upappllc.lettalk.data.Message
import com.upappllc.lettalk.data.Sample
import com.upappllc.lettalk.ui.components.Avatar
import com.upappllc.lettalk.ui.components.CenteredEmpty
import com.upappllc.lettalk.ui.theme.LT

/** Big bold page title like the iPhone's large navigation titles, with icons on the right. */
@Composable
fun LargeTitle(title: String, actions: @Composable () -> Unit = {}) {
    Column(Modifier.padding(start = 16.dp, end = 8.dp, top = 8.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { actions() }
        Text(title, fontSize = 32.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun SearchField(value: String, onChange: (String) -> Unit, placeholder: String) {
    TextField(
        value = value,
        onValueChange = onChange,
        placeholder = { Text(placeholder) },
        leadingIcon = { Icon(Icons.Filled.Search, null) },
        singleLine = true,
        shape = RoundedCornerShape(12.dp),
        colors = TextFieldDefaults.colors(
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    )
}

/** Chats tab: conversations with the last message already translated into my language. */
@Composable
fun ChatsScreen(onOpenChat: (String) -> Unit, onNewChat: () -> Unit, onSettings: () -> Unit) {
    var query by remember { mutableStateOf("") }
    val chats = Sample.chats.filter {
        query.isBlank() || it.contact.name.contains(query, true) || it.lastMessage.contains(query, true)
    }
    Column(Modifier.fillMaxSize()) {
        LargeTitle("Chats") {
            IconButton(onClick = onNewChat) { Icon(Icons.Filled.Edit, "New chat", tint = MaterialTheme.colorScheme.primary) }
            IconButton(onClick = onSettings) { Icon(Icons.Filled.Settings, "Settings", tint = MaterialTheme.colorScheme.primary) }
        }
        SearchField(query, { query = it }, "Search conversations")
        if (chats.isEmpty()) {
            CenteredEmpty(Icons.Filled.ChatBubbleOutline, "No Conversations", "Start a conversation with someone.")
        }
        LazyColumn {
            items(chats, key = { it.contact.id }) { chat ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenChat(chat.contact.id) }
                        .padding(horizontal = 16.dp, vertical = 10.dp)
                ) {
                    Avatar(chat.contact.name, 50.dp, chat.contact.online)
                    Column(Modifier.weight(1f).padding(start = 12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(chat.contact.name, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, modifier = Modifier.weight(1f))
                            Text(chat.time, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                chat.lastMessage, maxLines = 2, overflow = TextOverflow.Ellipsis,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f), fontSize = 14.sp,
                                modifier = Modifier.weight(1f)
                            )
                            if (chat.unread > 0) {
                                Box(
                                    Modifier
                                        .padding(start = 8.dp)
                                        .size(20.dp)
                                        .clip(CircleShape)
                                        .background(LT.Blue),
                                    contentAlignment = Alignment.Center
                                ) { Text("${chat.unread}", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
                            }
                        }
                    }
                }
                HorizontalDivider(Modifier.padding(start = 78.dp), thickness = 0.5.dp)
            }
        }
    }
}

/** A conversation. Incoming messages show translated, with "Show Original" on each bubble. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatDetailScreen(contactId: String, onBack: () -> Unit, onCall: (Boolean) -> Unit) {
    val contact = Sample.contacts.first { it.id == contactId }
    val messages = remember(contactId) { mutableStateListOf<Message>().apply { addAll(Sample.messages(contactId)) } }
    val showingOriginal = remember { mutableStateMapOf<String, Boolean>() }
    var draft by remember { mutableStateOf("") }
    var menuOpen by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Avatar(contact.name, 36.dp)
                        Column(Modifier.padding(start = 10.dp)) {
                            Text(contact.name, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                            Text(
                                if (contact.online) "Online" else "Offline", fontSize = 12.sp,
                                color = if (contact.online) LT.Green else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                        }
                    }
                },
                actions = {
                    IconButton(onClick = { onCall(false) }) { Icon(Icons.Filled.Call, "Voice call", tint = LT.Green) }
                    IconButton(onClick = { onCall(true) }) { Icon(Icons.Filled.Videocam, "Video call", tint = LT.Green) }
                    Box {
                        IconButton(onClick = { menuOpen = true }) { Icon(Icons.Filled.MoreVert, "More") }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(
                                text = { Text("Block ${contact.name}", color = LT.Red) },
                                leadingIcon = { Icon(Icons.Filled.Block, null, tint = LT.Red) },
                                onClick = { menuOpen = false; dialog = "block" }
                            )
                            DropdownMenuItem(
                                text = { Text("Report ${contact.name}") },
                                leadingIcon = { Icon(Icons.Filled.Flag, null) },
                                onClick = { menuOpen = false; dialog = "report" }
                            )
                        }
                    }
                }
            )
        },
        bottomBar = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .navigationBarsPadding()
                    .imePadding()
                    .padding(horizontal = 8.dp, vertical = 6.dp)
            ) {
                IconButton(onClick = {}) { Icon(Icons.Filled.Add, "Attach", tint = MaterialTheme.colorScheme.primary) }
                OutlinedTextField(
                    value = draft, onValueChange = { draft = it },
                    placeholder = { Text("Message") },
                    shape = RoundedCornerShape(22.dp),
                    modifier = Modifier.weight(1f)
                )
                if (draft.isBlank()) {
                    IconButton(onClick = {}) { Icon(Icons.Filled.Mic, "Voice message", tint = MaterialTheme.colorScheme.primary) }
                } else {
                    IconButton(onClick = {
                        messages.add(Message("n${messages.size}", true, draft.trim(), time = "Now", read = false))
                        draft = ""
                    }) { Icon(Icons.AutoMirrored.Filled.Send, "Send", tint = MaterialTheme.colorScheme.primary) }
                }
            }
        }
    ) { padding ->
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 12.dp)
        ) {
            item { Spacer(Modifier.height(8.dp)) }
            items(messages, key = { it.id }) { m ->
                MessageBubble(m, showingOriginal[m.id] == true) { showingOriginal[m.id] = showingOriginal[m.id] != true }
            }
            item { Spacer(Modifier.height(8.dp)) }
        }
    }

    when (dialog) {
        "block" -> AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text("Block ${contact.name}?") },
            text = { Text("They won't be able to call or message you, and you won't see their messages.") },
            confirmButton = { TextButton(onClick = { dialog = null }) { Text("Block", color = LT.Red) } },
            dismissButton = { TextButton(onClick = { dialog = null }) { Text("Cancel") } }
        )
        "report" -> AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text("Report ${contact.name}") },
            text = { Text("Reason: Spam\n\nOur team reviews reports within 24 hours. You can also block this user.") },
            confirmButton = { TextButton(onClick = { dialog = null }) { Text("Submit Report") } },
            dismissButton = { TextButton(onClick = { dialog = null }) { Text("Close") } }
        )
    }
}

@Composable
private fun MessageBubble(m: Message, showOriginal: Boolean, onToggle: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (m.fromMe) Arrangement.End else Arrangement.Start) {
        Surface(
            shape = RoundedCornerShape(18.dp),
            color = if (m.fromMe) LT.Blue else MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.widthIn(max = 290.dp)
        ) {
            Column(Modifier.padding(horizontal = 14.dp, vertical = 9.dp)) {
                Text(
                    if (showOriginal && m.original != null) m.original else m.text,
                    color = if (m.fromMe) Color.White else MaterialTheme.colorScheme.onSurface,
                    fontSize = 16.sp
                )
                if (m.original != null) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .padding(top = 4.dp)
                            .clickable(onClick = onToggle)
                    ) {
                        Icon(Icons.Filled.Translate, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(14.dp))
                        Text(
                            if (showOriginal) " Show Translation" else " Translated from ${m.sourceLanguage} · Show Original",
                            color = MaterialTheme.colorScheme.primary, fontSize = 12.sp, fontWeight = FontWeight.Medium
                        )
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 2.dp)) {
                    Text(
                        m.time, fontSize = 11.sp, fontStyle = FontStyle.Normal,
                        color = if (m.fromMe) Color.White.copy(alpha = 0.8f) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                    )
                    if (m.fromMe) {
                        Icon(
                            Icons.Filled.DoneAll, null,
                            tint = Color.White.copy(alpha = if (m.read) 1f else 0.5f),
                            modifier = Modifier.padding(start = 4.dp).size(13.dp)
                        )
                    }
                }
            }
        }
    }
}

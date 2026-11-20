package com.upappllc.lettalk.ui.main

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CallMade
import androidx.compose.material.icons.automirrored.filled.CallMissed
import androidx.compose.material.icons.automirrored.filled.CallReceived
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.upappllc.lettalk.data.CallDirection
import com.upappllc.lettalk.data.Contact
import com.upappllc.lettalk.data.Sample
import com.upappllc.lettalk.ui.components.Avatar
import com.upappllc.lettalk.ui.components.CenteredEmpty
import com.upappllc.lettalk.ui.theme.LT

/** Calls tab (Recents). Long-press a call for Call / Video Call / Message / Delete. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun RecentsScreen(onCall: (String, Boolean) -> Unit, onMessage: (String) -> Unit) {
    val calls = remember { mutableStateListOf(*Sample.calls.toTypedArray()) }
    var query by remember { mutableStateOf("") }
    var menuFor by remember { mutableStateOf<String?>(null) }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            LargeTitle("Calls")
            SearchField(query, { query = it }, "Search calls")
            val shown = calls.filter { query.isBlank() || it.contact.name.contains(query, true) }
            if (shown.isEmpty()) CenteredEmpty(Icons.Filled.Call, "No Call History", "Your calls will appear here.")
            LazyColumn {
                items(shown, key = { it.id }) { call ->
                    Box {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .combinedClickable(
                                    onClick = { onCall(call.contact.id, call.video) },
                                    onLongClick = { menuFor = call.id }
                                )
                                .padding(horizontal = 16.dp, vertical = 10.dp)
                        ) {
                            Avatar(call.contact.name, 46.dp)
                            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                                Text(
                                    call.contact.name, fontWeight = FontWeight.SemiBold, fontSize = 16.sp,
                                    color = if (call.direction == CallDirection.Missed) LT.Red else MaterialTheme.colorScheme.onSurface
                                )
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        when (call.direction) {
                                            CallDirection.Outgoing -> Icons.AutoMirrored.Filled.CallMade
                                            CallDirection.Incoming -> Icons.AutoMirrored.Filled.CallReceived
                                            CallDirection.Missed -> Icons.AutoMirrored.Filled.CallMissed
                                        },
                                        null,
                                        tint = if (call.direction == CallDirection.Missed) LT.Red else LT.Blue,
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Text(
                                        (if (call.video) " Video" else " Audio") + if (call.direction == CallDirection.Missed) " · Missed" else "",
                                        fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )
                                }
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text(call.time, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                call.duration?.let { Text(it, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)) }
                            }
                        }
                        DropdownMenu(expanded = menuFor == call.id, onDismissRequest = { menuFor = null }) {
                            DropdownMenuItem(text = { Text("Call") }, leadingIcon = { Icon(Icons.Filled.Call, null) },
                                onClick = { menuFor = null; onCall(call.contact.id, false) })
                            DropdownMenuItem(text = { Text("Video Call") }, leadingIcon = { Icon(Icons.Filled.Videocam, null) },
                                onClick = { menuFor = null; onCall(call.contact.id, true) })
                            DropdownMenuItem(text = { Text("Message") }, leadingIcon = { Icon(Icons.AutoMirrored.Filled.Chat, null) },
                                onClick = { menuFor = null; onMessage(call.contact.id) })
                            DropdownMenuItem(text = { Text("Delete", color = LT.Red) }, leadingIcon = { Icon(Icons.Filled.Delete, null, tint = LT.Red) },
                                onClick = { menuFor = null; calls.remove(call) })
                        }
                    }
                    HorizontalDivider(Modifier.padding(start = 74.dp), thickness = 0.5.dp)
                }
            }
        }
        FloatingActionButton(
            onClick = {},
            shape = CircleShape,
            containerColor = LT.Blue,
            contentColor = Color.White,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(20.dp)
        ) { Icon(Icons.Filled.Call, "New call") }
    }
}

/** Contacts tab. Long-press for Message / View Contact / Call / Video Call / Copy Phone / Delete. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ContactsScreen(onAdd: () -> Unit, onMessage: (String) -> Unit, onCall: (String, Boolean) -> Unit) {
    var query by remember { mutableStateOf("") }
    var menuFor by remember { mutableStateOf<String?>(null) }
    val list = Sample.contacts.filter { query.isBlank() || it.name.contains(query, true) || it.number.contains(query) }

    Column(Modifier.fillMaxSize()) {
        LargeTitle("Contacts") {
            IconButton(onClick = onAdd) { Icon(Icons.Filled.PersonAdd, "Add contact", tint = LT.Green) }
        }
        SearchField(query, { query = it }, "Search contacts")
        LazyColumn {
            list.groupBy { it.name.first().uppercaseChar() }.toSortedMap().forEach { (letter, group) ->
                item(key = "h$letter") {
                    Text(
                        "$letter", fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                        modifier = Modifier.padding(start = 16.dp, top = 12.dp, bottom = 4.dp)
                    )
                }
                items(group, key = { it.id }) { c ->
                    Box {
                        ContactRow(c, Modifier.combinedClickable(onClick = { onMessage(c.id) }, onLongClick = { menuFor = c.id }))
                        DropdownMenu(expanded = menuFor == c.id, onDismissRequest = { menuFor = null }) {
                            DropdownMenuItem(text = { Text("Message") }, leadingIcon = { Icon(Icons.AutoMirrored.Filled.Chat, null) },
                                onClick = { menuFor = null; onMessage(c.id) })
                            DropdownMenuItem(text = { Text("View Contact") }, leadingIcon = { Icon(Icons.Filled.Person, null) },
                                onClick = { menuFor = null })
                            DropdownMenuItem(text = { Text("Call") }, leadingIcon = { Icon(Icons.Filled.Call, null) },
                                onClick = { menuFor = null; onCall(c.id, false) })
                            DropdownMenuItem(text = { Text("Video Call") }, leadingIcon = { Icon(Icons.Filled.Videocam, null) },
                                onClick = { menuFor = null; onCall(c.id, true) })
                            DropdownMenuItem(text = { Text("Copy Phone") }, leadingIcon = { Icon(Icons.Filled.ContentCopy, null) },
                                onClick = { menuFor = null })
                            DropdownMenuItem(text = { Text("Delete", color = LT.Red) }, leadingIcon = { Icon(Icons.Filled.Delete, null, tint = LT.Red) },
                                onClick = { menuFor = null })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ContactRow(c: Contact, modifier: Modifier) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Avatar(c.name, 42.dp, c.online)
        Column(Modifier.padding(start = 12.dp)) {
            Text(c.name, fontWeight = FontWeight.SemiBold)
            Text(c.number, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
        }
    }
}

/** Translator tab: two languages, one conversation. */
@Composable
fun TranslatorScreen() {
    var from by remember { mutableStateOf(Sample.languages[0]) }
    var to by remember { mutableStateOf(Sample.languages[1]) }
    var input by remember { mutableStateOf("") }
    var pickFor by remember { mutableStateOf<String?>(null) }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        LargeTitle("Translator")
        Text(
            "Two languages. One conversation.",
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.padding(horizontal = 16.dp)
        )
        Spacer(Modifier.height(16.dp))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 16.dp)
        ) {
            LanguageTile(from.name, Modifier.weight(1f)) { pickFor = "from" }
            Box(
                Modifier
                    .padding(horizontal = 10.dp)
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(LT.Blue)
                    .clickable { val t = from; from = to; to = t },
                contentAlignment = Alignment.Center
            ) { Icon(Icons.Filled.SwapHoriz, "Swap languages", tint = Color.White) }
            LanguageTile(to.name, Modifier.weight(1f)) { pickFor = "to" }
        }
        Box {
            DropdownMenu(expanded = pickFor != null, onDismissRequest = { pickFor = null }) {
                Sample.languages.forEach { lang ->
                    DropdownMenuItem(text = { Text("${lang.name}  ·  ${lang.native}") }, onClick = {
                        if (pickFor == "from") from = lang else to = lang
                        pickFor = null
                    })
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(
            value = input, onValueChange = { input = it },
            placeholder = { Text("Text in your language") },
            minLines = 4,
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
        )
        Spacer(Modifier.height(12.dp))
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
        ) {
            Column(Modifier.padding(16.dp)) {
                Text(to.name, fontWeight = FontWeight.SemiBold, color = LT.Blue)
                Spacer(Modifier.height(6.dp))
                Text(
                    if (input.isBlank()) "The translation appears here."
                    else "Translation into ${to.name} appears here once the app is connected to the Let Talk server.",
                    color = if (input.isBlank()) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f) else MaterialTheme.colorScheme.onSurface,
                    fontSize = 17.sp
                )
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    IconButton(onClick = {}) { Icon(Icons.AutoMirrored.Filled.VolumeUp, "Speak") }
                    IconButton(onClick = {}) { Icon(Icons.Filled.ContentCopy, "Copy") }
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun LanguageTile(name: String, modifier: Modifier, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        modifier = modifier.clickable(onClick = onClick)
    ) {
        Text(
            name, fontWeight = FontWeight.SemiBold, fontSize = 16.sp,
            modifier = Modifier.padding(vertical = 18.dp, horizontal = 12.dp)
        )
    }
}

@Composable
fun Dot() = Box(Modifier.size(4.dp).clip(CircleShape).background(Color.Gray))

@Composable
fun HSpace(w: Int) = Spacer(Modifier.width(w.dp))

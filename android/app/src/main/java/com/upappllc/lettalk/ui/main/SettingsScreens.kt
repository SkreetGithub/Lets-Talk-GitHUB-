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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Contacts
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.QrCode2
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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
import com.upappllc.lettalk.data.Sample
import com.upappllc.lettalk.ui.components.Avatar
import com.upappllc.lettalk.ui.components.SettingsGroup
import com.upappllc.lettalk.ui.components.SettingsRow
import com.upappllc.lettalk.ui.theme.LT

/** Settings: a menu with arrows into each page, same layout as the iPhone app. */
@Composable
fun SettingsScreen(onSignOut: () -> Unit) {
    var page by remember { mutableStateOf<String?>(null) }
    var language by remember { mutableStateOf(Sample.languages[0]) }
    var confirmDelete by remember { mutableStateOf(false) }

    when (page) {
        "language" -> {
            LanguagePage(language, onPick = { language = it }, onBack = { page = null })
            return
        }
        "number" -> {
            MyNumberPage(onBack = { page = null })
            return
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        LargeTitle("Settings")
        SettingsGroup {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {}
                    .padding(14.dp)
            ) {
                Avatar(Sample.me.name, 56.dp)
                Column(Modifier.padding(start = 14.dp).weight(1f)) {
                    Text(Sample.me.name, fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
                    Text(Sample.me.email, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
                    Text("Tap to edit profile", fontSize = 12.sp, color = MaterialTheme.colorScheme.primary)
                }
                Icon(Icons.Filled.Edit, null, tint = MaterialTheme.colorScheme.primary)
            }
        }
        SettingsGroup {
            SettingsRow(Icons.Filled.PhoneAndroid, LT.Green, "My Let Talk Number", Sample.me.number) { page = "number" }
            SettingsRow(Icons.Filled.QrCode2, Color.Black, "My QR Code", showDivider = false)
        }
        SettingsGroup {
            SettingsRow(Icons.Filled.Palette, LT.Purple, "Appearance", "System")
            SettingsRow(Icons.Filled.Language, LT.Blue, "Language & Translation", language.name) { page = "language" }
            SettingsRow(Icons.AutoMirrored.Filled.VolumeUp, LT.Red, "Audio & Video")
            SettingsRow(Icons.Filled.Notifications, LT.Red, "Notifications")
            SettingsRow(Icons.Filled.PrivacyTip, Color(0xFF5856D6), "Privacy & Safety", showDivider = false)
        }
        SettingsGroup {
            SettingsRow(Icons.Filled.Storage, Color.Gray, "Data & Storage")
            SettingsRow(Icons.AutoMirrored.Filled.Help, Color(0xFF00B4D8), "Help & Legal", showDivider = false)
        }
        SettingsGroup("Account") {
            SettingsRow(Icons.Filled.Key, LT.Blue, "Reset Password")
            SettingsRow(Icons.AutoMirrored.Filled.Logout, LT.Orange, "Sign Out", showArrow = false, onClick = onSignOut)
            SettingsRow(Icons.Filled.Delete, LT.Red, "Delete Account", titleColor = LT.Red, showArrow = false,
                showDivider = false) { confirmDelete = true }
        }
        Text(
            "Delete Account permanently deletes your account and all of your data. This cannot be undone.",
            fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            modifier = Modifier.padding(horizontal = 28.dp)
        )
        Spacer(Modifier.height(32.dp))
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete Account") },
            text = { Text("This action cannot be undone. Your account, messages, contacts and call history will be permanently deleted.") },
            confirmButton = { TextButton(onClick = { confirmDelete = false; onSignOut() }) { Text("Delete", color = LT.Red) } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SubPage(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } }
            )
        }
    ) { p ->
        Column(
            Modifier
                .padding(p)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) { content() }
    }
}

@Composable
private fun LanguagePage(
    current: com.upappllc.lettalk.data.Language,
    onPick: (com.upappllc.lettalk.data.Language) -> Unit,
    onBack: () -> Unit,
) {
    SubPage("Language & Translation", onBack) {
        Text(
            "My Language: the app, incoming messages and call subtitles are shown in this language.",
            fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.padding(horizontal = 28.dp, vertical = 8.dp)
        )
        SettingsGroup("My Language") {
            Sample.languages.forEach { lang ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(lang) }
                        .padding(horizontal = 16.dp, vertical = 13.dp)
                ) {
                    Text(lang.native, modifier = Modifier.weight(1f), fontSize = 16.sp)
                    Text(lang.name, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), fontSize = 14.sp)
                    if (lang.code == current.code) {
                        Icon(Icons.Filled.Check, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(start = 10.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun MyNumberPage(onBack: () -> Unit) {
    SubPage("My Let Talk Number", onBack) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth().padding(24.dp)) {
            Text("Your number", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
            Text(Sample.me.number, fontSize = 32.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(
                "People call and text you on this number in Let Talk. It's an in-app number, not a phone carrier number.",
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }
        SettingsGroup {
            SettingsRow(Icons.Filled.QrCode2, Color.Black, "Copy Number", showArrow = false)
            SettingsRow(Icons.Filled.Contacts, LT.Blue, "Share Number", showArrow = false)
            SettingsRow(Icons.Filled.PhoneAndroid, LT.Green, "Change Number", "Once a year", showDivider = false)
        }
    }
}

/** Add Contact: Scan QR Code, From My Phone Contacts, or Enter Manually. */
@Composable
fun AddContactScreen(onBack: () -> Unit) {
    var name by remember { mutableStateOf("") }
    var number by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    SubPage("Add Contact", onBack) {
        SettingsGroup {
            OptionRow(Icons.Filled.QrCodeScanner, LT.Blue, "Scan QR Code", "Adds their photo, Let Talk number and email in one step")
            OptionRow(Icons.Filled.Contacts, LT.Green, "From My Phone Contacts", "See which of your contacts use Let Talk, add them with one tap")
        }
        Text(
            "Your own QR code is in Settings › My QR Code.",
            fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            modifier = Modifier.padding(horizontal = 28.dp)
        )
        SettingsGroup("Or Enter Manually") {
            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Name") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(number, { number = it }, label = { Text("Let Talk Number") }, prefix = { Text("+1 ") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(email, { email = it }, label = { Text("Email (optional)") }, modifier = Modifier.fillMaxWidth())
                TextButton(onClick = onBack, enabled = name.isNotBlank() && number.isNotBlank(), modifier = Modifier.align(Alignment.End)) {
                    Text("Save")
                }
            }
        }
    }
}

@Composable
private fun OptionRow(icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color, title: String, subtitle: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable {}
            .padding(14.dp)
    ) {
        Box(
            Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(color),
            contentAlignment = Alignment.Center
        ) { Icon(icon, null, tint = Color.White) }
        Column(Modifier.padding(start = 14.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold, color = color)
            Text(subtitle, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
        }
    }
}

/** New Message: search your contacts, or type a Let Talk number or email. */
@Composable
fun NewMessageScreen(onBack: () -> Unit, onOpenChat: (String) -> Unit) {
    var query by remember { mutableStateOf("") }
    SubPage("New Message", onBack) {
        SearchField(query, { query = it }, "Name, Let Talk number or email")
        Sample.contacts
            .filter { query.isBlank() || it.name.contains(query, true) || it.number.filter(Char::isDigit).contains(query.filter(Char::isDigit).ifEmpty { "\u0000" }) || it.email.contains(query, true) }
            .forEach { c ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpenChat(c.id) }
                        .padding(horizontal = 16.dp, vertical = 10.dp)
                ) {
                    Avatar(c.name, 42.dp)
                    Column(Modifier.padding(start = 12.dp)) {
                        Text(c.name, fontWeight = FontWeight.SemiBold)
                        Text(c.number, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
                    }
                }
            }
        Surface(Modifier.height(1.dp)) {}
    }
}

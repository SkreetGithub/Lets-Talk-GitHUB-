package com.upappllc.lettalk.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.upappllc.lettalk.ui.theme.LT

fun initials(name: String): String =
    name.split(" ").filter { it.isNotBlank() }.take(2).joinToString("") { it.first().uppercase() }

/** Round initials avatar, with an optional green "online" dot. */
@Composable
fun Avatar(name: String, size: Dp = 48.dp, online: Boolean = false) {
    Box {
        Box(
            modifier = Modifier
                .size(size)
                .clip(CircleShape)
                .background(LT.avatarColor(name)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                initials(name),
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = (size.value * 0.36f).sp
            )
        }
        if (online) {
            Box(
                Modifier
                    .align(Alignment.BottomEnd)
                    .size(size / 4)
                    .clip(CircleShape)
                    .background(Color.White)
                    .padding(2.dp)
                    .clip(CircleShape)
                    .background(LT.Green)
            )
        }
    }
}

/** Rounded see-through text field used on the purple sign-in and sign-up screens. */
@Composable
fun PillField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    icon: ImageVector,
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    // Passwords start hidden (eye with a slash); tap the eye to show what was typed.
    var revealed by remember { mutableStateOf(false) }
    TextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder, color = Color.White.copy(alpha = 0.7f)) },
        leadingIcon = { Icon(icon, contentDescription = null, tint = Color.White.copy(alpha = 0.75f)) },
        trailingIcon = {
            if (isPassword) {
                IconButton(onClick = { revealed = !revealed }) {
                    Icon(
                        if (revealed) Icons.Filled.Visibility else Icons.Filled.VisibilityOff,
                        contentDescription = if (revealed) "Hide password" else "Show password",
                        tint = Color.White.copy(alpha = 0.85f)
                    )
                }
            }
        },
        visualTransformation = if (isPassword && !revealed) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = if (isPassword) KeyboardType.Password else keyboardType),
        singleLine = true,
        shape = RoundedCornerShape(28.dp),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.White.copy(alpha = 0.16f),
            unfocusedContainerColor = Color.White.copy(alpha = 0.10f),
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            cursorColor = Color.White,
        ),
        modifier = Modifier.fillMaxWidth()
    )
}

/** Big white rounded button on the purple screens. */
@Composable
fun WhiteButton(text: String, textColor: Color = Color(0xFFC2185B), onClick: () -> Unit) {
    Button(
        onClick = onClick,
        shape = RoundedCornerShape(28.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = textColor),
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp)
    ) {
        Text(text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

/** A white card that groups settings rows, like the iPhone's inset lists. */
@Composable
fun SettingsGroup(title: String? = null, content: @Composable () -> Unit) {
    Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
        if (title != null) {
            Text(
                title.uppercase(),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                modifier = Modifier.padding(start = 12.dp, bottom = 6.dp)
            )
        }
        Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surface) {
            Column { content() }
        }
    }
}

/** One settings row: colored icon, title, optional value on the right, and an arrow. */
@Composable
fun SettingsRow(
    icon: ImageVector,
    iconColor: Color,
    title: String,
    value: String? = null,
    titleColor: Color = MaterialTheme.colorScheme.onSurface,
    showDivider: Boolean = true,
    showArrow: Boolean = true,
    onClick: () -> Unit = {},
) {
    Column {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 14.dp, vertical = 11.dp)
        ) {
            Box(
                Modifier
                    .size(30.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(iconColor),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
            }
            Spacer(Modifier.width(14.dp))
            Text(title, color = titleColor, fontSize = 16.sp, modifier = Modifier.weight(1f))
            if (value != null) {
                Text(value, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), fontSize = 15.sp)
            }
            if (showArrow) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
                )
            }
        }
        if (showDivider) HorizontalDivider(Modifier.padding(start = 58.dp), thickness = 0.5.dp)
    }
}

@Composable
fun SectionSpacer() = Spacer(Modifier.height(8.dp))

@Composable
fun CenteredEmpty(icon: ImageVector, title: String, message: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 120.dp, start = 32.dp, end = 32.dp)
    ) {
        Icon(icon, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f), modifier = Modifier.size(56.dp))
        Spacer(Modifier.height(12.dp))
        Text(title, fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
        Spacer(Modifier.height(4.dp))
        Text(message, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
    }
}

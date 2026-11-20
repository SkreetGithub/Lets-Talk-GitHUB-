package com.upappllc.lettalk.ui.call

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.Cameraswitch
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.filled.VideocamOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.upappllc.lettalk.data.Sample
import com.upappllc.lettalk.ui.components.Avatar
import com.upappllc.lettalk.ui.theme.LT
import kotlinx.coroutines.delay

private enum class Phase { Ringing, Connected }

/**
 * The call screen, as a demo: it "rings", connects after a few seconds and shows sample
 * translated subtitles. Real calling (WebRTC) and live translation are wired up later.
 * My camera box only appears once the call is connected, not while it's ringing.
 */
@Composable
fun CallScreen(contactId: String, startVideo: Boolean, incoming: Boolean, onEnd: () -> Unit) {
    val contact = Sample.contacts.first { it.id == contactId }
    var phase by remember { mutableStateOf(Phase.Ringing) }
    var muted by remember { mutableStateOf(false) }
    var video by remember { mutableStateOf(startVideo) }
    var speaker by remember { mutableStateOf(startVideo) }
    var seconds by remember { mutableIntStateOf(0) }
    var subtitle by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(phase) {
        if (phase == Phase.Ringing && !incoming) {
            delay(3000)
            phase = Phase.Connected
        }
        if (phase == Phase.Connected) {
            val lines = listOf("Hi! Can you hear me?", "What are you doing today?", "See you at the store at 3pm.")
            var i = 0
            while (true) {
                delay(1000)
                seconds++
                if (seconds % 5 == 2) subtitle = lines[i++ % lines.size]
                if (seconds % 5 == 0) subtitle = null
            }
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(LT.CallGradient)
            .systemBarsPadding()
    ) {
        // Top: name, call type / timer, connection + translation chips
        Row(Modifier.fillMaxWidth().padding(20.dp)) {
            Column(Modifier.weight(1f)) {
                Text(contact.name, color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
                Text(if (video) "Video Call" else "Voice Call", color = Color.White.copy(alpha = 0.8f))
                if (phase == Phase.Connected) {
                    Text("%d:%02d".format(seconds / 60, seconds % 60), color = Color.White, fontWeight = FontWeight.SemiBold)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (phase == Phase.Connected) LT.Green else Color.Gray)
                    )
                    Text(
                        if (phase == Phase.Connected) " Connected" else " Connecting",
                        color = Color.White.copy(alpha = 0.9f), fontSize = 13.sp
                    )
                }
                Spacer(Modifier.height(6.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.White.copy(alpha = 0.18f))
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Icon(Icons.AutoMirrored.Filled.Chat, null, tint = Color.White, modifier = Modifier.size(16.dp))
                    Column(Modifier.padding(start = 6.dp)) {
                        Text("Translating", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Text("Listening: English", color = Color.White.copy(alpha = 0.8f), fontSize = 11.sp)
                    }
                }
            }
        }

        // My camera preview: only once connected on a video call
        if (video && phase == Phase.Connected) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 150.dp, end = 20.dp)
                    .size(width = 110.dp, height = 150.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.Black.copy(alpha = 0.5f))
                    .border(1.5.dp, Color.White.copy(alpha = 0.8f), RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center
            ) { Text("You", color = Color.White.copy(alpha = 0.7f)) }
        }

        // Middle: avatar with pulsing rings while ringing
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.align(Alignment.Center)
        ) {
            val pulse = rememberInfiniteTransition(label = "pulse")
            val s by pulse.animateFloat(1f, 1.25f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "s")
            Box(contentAlignment = Alignment.Center) {
                if (phase == Phase.Ringing) {
                    Box(
                        Modifier
                            .size(150.dp)
                            .scale(s)
                            .clip(CircleShape)
                            .border(2.dp, Color(0xFFE0B040).copy(alpha = 0.6f), CircleShape)
                    )
                }
                Avatar(contact.name, 120.dp)
            }
            Spacer(Modifier.height(20.dp))
            if (phase == Phase.Ringing) {
                Text(
                    if (incoming) "Incoming Call" else "Calling...",
                    color = Color.White,
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color.Black.copy(alpha = 0.35f))
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                )
            }
        }

        // Bottom: translated subtitle bubble + controls
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(bottom = 28.dp)
        ) {
            subtitle?.let {
                Text(
                    it, color = Color.White, fontSize = 18.sp,
                    modifier = Modifier
                        .padding(horizontal = 24.dp)
                        .clip(RoundedCornerShape(22.dp))
                        .background(Color.Black.copy(alpha = 0.45f))
                        .padding(horizontal = 18.dp, vertical = 10.dp)
                )
                Spacer(Modifier.height(18.dp))
            }
            Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
                RoundControl(if (muted) Icons.Filled.MicOff else Icons.Filled.Mic, muted, "Mute") { muted = !muted }
                RoundControl(if (video) Icons.Filled.Videocam else Icons.Filled.VideocamOff, video, "Video") { video = !video }
                RoundControl(Icons.AutoMirrored.Filled.VolumeUp, speaker, "Speaker") { speaker = !speaker }
                if (video) RoundControl(Icons.Filled.Cameraswitch, false, "Flip") {}
            }
            Spacer(Modifier.height(26.dp))
            Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                if (incoming && phase == Phase.Ringing) {
                    BigButton(Icons.Filled.Call, LT.Green, "Answer") { phase = Phase.Connected }
                    Spacer(Modifier.width(70.dp))
                }
                BigButton(Icons.Filled.CallEnd, LT.Red, "End call", onEnd)
            }
        }
    }
}

@Composable
private fun RoundControl(icon: ImageVector, active: Boolean, label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(60.dp)
            .clip(CircleShape)
            .background(if (active) Color.White else Color.White.copy(alpha = 0.2f))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) { Icon(icon, label, tint = if (active) Color.Black else Color.White) }
}

@Composable
private fun BigButton(icon: ImageVector, color: Color, label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(78.dp)
            .clip(CircleShape)
            .background(color)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) { Icon(icon, label, tint = Color.White, modifier = Modifier.size(34.dp)) }
}

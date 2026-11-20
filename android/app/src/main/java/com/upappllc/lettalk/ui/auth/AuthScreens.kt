package com.upappllc.lettalk.ui.auth

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Public
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.upappllc.lettalk.data.Sample
import com.upappllc.lettalk.ui.components.PillField
import com.upappllc.lettalk.ui.components.WhiteButton
import com.upappllc.lettalk.ui.theme.LT
import kotlinx.coroutines.launch

@Composable
private fun AuthBackground(content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(LT.AuthGradient)
    ) { content() }
}

@Composable
private fun GlobeLogo() {
    Box(
        Modifier
            .size(84.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.18f)),
        contentAlignment = Alignment.Center
    ) {
        Icon(Icons.Filled.Public, contentDescription = null, tint = Color.White, modifier = Modifier.size(56.dp))
    }
}

@Composable
private fun ErrorBanner(text: String) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFFE53950))
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Text(text, color = Color.White, fontWeight = FontWeight.SemiBold)
    }
}

/** Sign in: email + password, Sign in with Google, link to Sign Up. */
@Composable
fun SignInScreen(onSignedIn: () -> Unit, onSignUp: () -> Unit) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    AuthBackground {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 32.dp)
        ) {
            Spacer(Modifier.height(24.dp))
            GlobeLogo()
            Text("Let Talk", color = Color.White, fontSize = 34.sp, fontWeight = FontWeight.Bold)
            Text("Welcome back!", color = Color.White.copy(alpha = 0.9f), fontSize = 17.sp)
            Spacer(Modifier.height(12.dp))
            PillField(email, { email = it }, "Email Address", Icons.Filled.Email, keyboardType = KeyboardType.Email)
            PillField(password, { password = it }, "Password", Icons.Filled.Lock, isPassword = true)
            error?.let { ErrorBanner(it) }
            WhiteButton("Sign In") {
                error = if (email.isBlank() || password.isBlank()) "Please fill in all required fields." else null
                if (error == null) onSignedIn()
            }
            WhiteButton("Sign in with Google", textColor = Color.Black) { onSignedIn() }
            TextButton(onClick = {}) { Text("Forgot password?", color = Color.White) }
            TextButton(onClick = onSignUp) { Text("Don't have an account? Sign Up", color = Color.White, fontSize = 16.sp) }
            Spacer(Modifier.height(8.dp))
            Text(
                "By continuing you agree to our Privacy Policy and Terms of Service",
                color = Color.White.copy(alpha = 0.75f),
                fontSize = 12.sp,
                textAlign = TextAlign.Center
            )
        }
    }
}

/** Sign up, step 1: name, translated voice, email, password. Step 2 is the number picker. */
@Composable
fun SignUpScreen(onContinue: () -> Unit, onSignIn: () -> Unit) {
    var name by remember { mutableStateOf("") }
    var voice by remember { mutableStateOf<String?>(null) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    AuthBackground {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            StepHeader(step = 1, title = "Your details")
            Column(
                verticalArrangement = Arrangement.spacedBy(14.dp),
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 16.dp)
            ) {
                Text(
                    "Create your account", color = Color.White, fontSize = 22.sp,
                    fontWeight = FontWeight.SemiBold, modifier = Modifier.align(Alignment.CenterHorizontally)
                )
                PillField(name, { name = it }, "Full Name", Icons.Filled.Person)
                Text("Your translated voice", color = Color.White, fontWeight = FontWeight.SemiBold)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    VoiceChoice("Male", voice == "male", Modifier.weight(1f)) { voice = "male" }
                    VoiceChoice("Female", voice == "female", Modifier.weight(1f)) { voice = "female" }
                }
                Text(
                    "People you call hear your translated speech in this voice. You can change it anytime in Settings.",
                    color = Color.White.copy(alpha = 0.8f), fontSize = 13.sp
                )
                PillField(email, { email = it }, "Email Address", Icons.Filled.Email, keyboardType = KeyboardType.Email)
                PillField(password, { password = it }, "Password", Icons.Filled.Lock, isPassword = true)
                PillField(confirm, { confirm = it }, "Confirm Password", Icons.Filled.Lock, isPassword = true)
                error?.let { ErrorBanner(it) }
                WhiteButton("Create Account") {
                    error = when {
                        name.isBlank() || email.isBlank() || password.isBlank() -> "Please fill in all required fields."
                        voice == null -> "Choose a voice for your translated speech."
                        password != confirm -> "Passwords don't match."
                        else -> null
                    }
                    if (error == null) onContinue()
                }
                WhiteButton("Sign up with Google", textColor = Color.Black) { onContinue() }
                TextButton(onClick = onSignIn, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                    Text("Already have an account? Sign In", color = Color.White, fontSize = 16.sp)
                }
            }
        }
    }
}

@Composable
private fun StepHeader(step: Int, title: String) {
    Column(Modifier.padding(horizontal = 24.dp, vertical = 10.dp)) {
        LinearProgressIndicator(
            progress = { step / 2f },
            color = Color.White,
            trackColor = Color.White.copy(alpha = 0.3f),
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
        )
        Spacer(Modifier.height(8.dp))
        Text("Step $step of 2 · $title", color = Color.White.copy(alpha = 0.9f), fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun VoiceChoice(label: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .clip(RoundedCornerShape(24.dp))
            .background(if (selected) Color.White else Color.White.copy(alpha = 0.12f))
            .clickable(onClick = onClick)
            .padding(vertical = 13.dp)
    ) {
        Box(
            Modifier
                .size(20.dp)
                .clip(CircleShape)
                .background(if (selected) Color(0xFFC2185B) else Color.Transparent)
                .border(2.dp, if (selected) Color(0xFFC2185B) else Color.White, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            if (selected) Icon(Icons.Filled.Check, null, tint = Color.White, modifier = Modifier.size(14.dp))
        }
        Spacer(Modifier.width(8.dp))
        Text(label, color = if (selected) Color(0xFFC2185B) else Color.White, fontWeight = FontWeight.SemiBold)
    }
}

/** Sign up, step 2: pick a state, an area code, then one of 5 free numbers, and hold to lock it in. */
@Composable
fun NumberPickerScreen(onDone: () -> Unit) {
    var state by remember { mutableStateOf<String?>(null) }
    var areaCode by remember { mutableStateOf<String?>(null) }
    var number by remember { mutableStateOf<String?>(null) }

    AuthBackground {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            StepHeader(step = 2, title = "Your number")
            Column(
                verticalArrangement = Arrangement.spacedBy(14.dp),
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 12.dp)
            ) {
                Icon(
                    Icons.Filled.Phone, null, tint = Color.White,
                    modifier = Modifier.size(56.dp).align(Alignment.CenterHorizontally)
                )
                Text(
                    "Get Your Let Talk Number", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()
                )
                Text(
                    "This is the number people call and text you on in Let Talk. Choose your state and area code, then pick one of 5 free numbers.",
                    color = Color.White.copy(alpha = 0.85f), textAlign = TextAlign.Center
                )

                Text("Select State", color = Color.White, fontWeight = FontWeight.SemiBold)
                ChipGrid(Sample.states, state) { state = it; areaCode = null; number = null }

                state?.let { s ->
                    Text("Select Area Code", color = Color.White, fontWeight = FontWeight.SemiBold)
                    ChipGrid(Sample.areaCodes(s), areaCode) { areaCode = it; number = null }
                }

                areaCode?.let { code ->
                    Text("Select 1 Number from 5 Options", color = Color.White, fontWeight = FontWeight.SemiBold)
                    Sample.numbers(code).forEach { n ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (n == number) Color.White else Color.White.copy(alpha = 0.12f))
                                .clickable { number = n }
                                .padding(16.dp)
                        ) {
                            Text(
                                n, fontSize = 18.sp, fontWeight = FontWeight.SemiBold,
                                color = if (n == number) Color(0xFFC2185B) else Color.White,
                                modifier = Modifier.weight(1f)
                            )
                            if (n == number) Icon(Icons.Filled.Check, null, tint = Color(0xFFC2185B))
                        }
                    }
                }
            }
            if (number != null) {
                Box(Modifier.padding(24.dp)) { HoldToLock(onLocked = onDone) }
            }
        }
    }
}

@Composable
private fun ChipGrid(items: List<String>, selected: String?, onSelect: (String) -> Unit) {
    items.chunked(3).forEach { row ->
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            row.forEach { item ->
                val on = item == selected
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (on) LT.Blue else Color.White.copy(alpha = 0.12f))
                        .clickable { onSelect(item) }
                        .padding(vertical = 12.dp)
                ) {
                    Text(item, color = Color.White, fontWeight = if (on) FontWeight.Bold else FontWeight.Normal)
                }
            }
            repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}

/** Press and hold for 1.5 seconds to lock in the number (same as the iPhone app). */
@Composable
private fun HoldToLock(onLocked: () -> Unit) {
    val progress = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    var locked by remember { mutableStateOf(false) }

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .fillMaxWidth()
            .height(60.dp)
            .clip(RoundedCornerShape(30.dp))
            .background(Color.White.copy(alpha = 0.2f))
            .pointerInput(Unit) {
                detectTapGestures(onPress = {
                    if (locked) return@detectTapGestures
                    val job = scope.launch {
                        progress.animateTo(1f, tween(1500, easing = LinearEasing))
                        locked = true
                        onLocked()
                    }
                    tryAwaitRelease()
                    if (!locked) {
                        job.cancel()
                        scope.launch { progress.animateTo(0f, tween(250)) }
                    }
                })
            }
    ) {
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .fillMaxHeight()
                .fillMaxWidth(progress.value)
                .background(LT.Green)
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (locked) "Locked In" else "Hold to Lock In", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
            Spacer(Modifier.width(8.dp))
            Icon(if (locked) Icons.Filled.Lock else Icons.Filled.LockOpen, null, tint = Color.White)
        }
    }
}

/** Unused helper kept for parity with the iPhone's secondary button style. */
@Composable
fun OutlineWhiteButton(text: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent, contentColor = Color.White),
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, Color.White, RoundedCornerShape(28.dp))
    ) { Text(text) }
}

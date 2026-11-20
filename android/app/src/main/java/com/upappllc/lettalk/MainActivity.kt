package com.upappllc.lettalk

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.upappllc.lettalk.ui.auth.NumberPickerScreen
import com.upappllc.lettalk.ui.auth.SignInScreen
import com.upappllc.lettalk.ui.auth.SignUpScreen
import com.upappllc.lettalk.ui.call.CallScreen
import com.upappllc.lettalk.ui.main.AddContactScreen
import com.upappllc.lettalk.ui.main.ChatDetailScreen
import com.upappllc.lettalk.ui.main.ChatsScreen
import com.upappllc.lettalk.ui.main.ContactsScreen
import com.upappllc.lettalk.ui.main.NewMessageScreen
import com.upappllc.lettalk.ui.main.RecentsScreen
import com.upappllc.lettalk.ui.main.SettingsScreen
import com.upappllc.lettalk.ui.main.TranslatorScreen
import com.upappllc.lettalk.ui.theme.LetTalkTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LetTalkTheme { LetTalkApp() }
        }
    }
}

private object Routes {
    const val SIGN_IN = "signin"
    const val SIGN_UP = "signup"
    const val NUMBER = "number"
    const val MAIN = "main"
    const val CHAT = "chat/{id}"
    const val CALL = "call/{id}?video={video}&incoming={incoming}"
    const val ADD_CONTACT = "addContact"
    const val NEW_MESSAGE = "newMessage"

    fun chat(id: String) = "chat/$id"
    fun call(id: String, video: Boolean, incoming: Boolean = false) = "call/$id?video=$video&incoming=$incoming"
}

@Composable
fun LetTalkApp() {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = Routes.SIGN_IN) {
        composable(Routes.SIGN_IN) {
            SignInScreen(
                onSignedIn = { nav.goToMain() },
                onSignUp = { nav.navigate(Routes.SIGN_UP) }
            )
        }
        composable(Routes.SIGN_UP) {
            SignUpScreen(
                onContinue = { nav.navigate(Routes.NUMBER) },
                onSignIn = { nav.popBackStack() }
            )
        }
        composable(Routes.NUMBER) {
            NumberPickerScreen(onDone = { nav.goToMain() })
        }
        composable(Routes.MAIN) {
            MainTabs(nav)
        }
        composable(Routes.CHAT, arguments = listOf(navArgument("id") { type = NavType.StringType })) { entry ->
            val id = entry.arguments?.getString("id") ?: "1"
            ChatDetailScreen(
                contactId = id,
                onBack = { nav.popBackStack() },
                onCall = { video -> nav.navigate(Routes.call(id, video)) }
            )
        }
        composable(
            Routes.CALL,
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("video") { type = NavType.BoolType; defaultValue = false },
                navArgument("incoming") { type = NavType.BoolType; defaultValue = false },
            )
        ) { entry ->
            CallScreen(
                contactId = entry.arguments?.getString("id") ?: "1",
                startVideo = entry.arguments?.getBoolean("video") ?: false,
                incoming = entry.arguments?.getBoolean("incoming") ?: false,
                onEnd = { nav.popBackStack() }
            )
        }
        composable(Routes.ADD_CONTACT) {
            AddContactScreen(onBack = { nav.popBackStack() })
        }
        composable(Routes.NEW_MESSAGE) {
            NewMessageScreen(
                onBack = { nav.popBackStack() },
                onOpenChat = { id -> nav.popBackStack(); nav.navigate(Routes.chat(id)) }
            )
        }
    }
}

private fun NavHostController.goToMain() {
    navigate(Routes.MAIN) {
        popUpTo(Routes.SIGN_IN) { inclusive = true }
    }
}

private data class Tab(val label: String, val icon: ImageVector)

private val tabs = listOf(
    Tab("Chats", Icons.AutoMirrored.Filled.Chat),
    Tab("Calls", Icons.Filled.Call),
    Tab("Contacts", Icons.Filled.People),
    Tab("Translator", Icons.Filled.Translate),
    Tab("More", Icons.Filled.MoreHoriz),
)

@Composable
private fun MainTabs(nav: NavHostController) {
    var selected by rememberSaveable { mutableIntStateOf(0) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { i, tab ->
                    NavigationBarItem(
                        selected = selected == i,
                        onClick = { selected = i },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { padding ->
        Box(
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(padding)
        ) {
            when (selected) {
                0 -> ChatsScreen(
                    onOpenChat = { nav.navigate(Routes.chat(it)) },
                    onNewChat = { nav.navigate(Routes.NEW_MESSAGE) },
                    onSettings = { selected = 4 }
                )
                1 -> RecentsScreen(
                    onCall = { id, video -> nav.navigate(Routes.call(id, video)) },
                    onMessage = { nav.navigate(Routes.chat(it)) }
                )
                2 -> ContactsScreen(
                    onAdd = { nav.navigate(Routes.ADD_CONTACT) },
                    onMessage = { nav.navigate(Routes.chat(it)) },
                    onCall = { id, video -> nav.navigate(Routes.call(id, video)) }
                )
                3 -> TranslatorScreen()
                else -> SettingsScreen(onSignOut = {
                    nav.navigate(Routes.SIGN_IN) { popUpTo(Routes.MAIN) { inclusive = true } }
                })
            }
        }
    }
}

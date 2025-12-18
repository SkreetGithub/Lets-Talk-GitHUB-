import Foundation
import Supabase

/// Centralized Supabase client used across the app.
///
/// Configure `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `Info.plist`.
enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabaseAnonKey
    )
}


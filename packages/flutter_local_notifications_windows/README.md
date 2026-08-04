# flutter_local_notifications_windows (Nexus stub)

Path override used by Transworld Nexus so Windows builds do **not** compile the
upstream native FFI plugin (requires Visual Studio ATL and hits MSVC
experimental-coroutine errors).

Nexus does not show system toasts on Windows; the in-app inbox (Supabase) is
unchanged. Android/iOS still use the real `flutter_local_notifications`
implementations.

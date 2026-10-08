# yubikit-android 3.1.0 still references SpotBugs annotations it does not ship
# (3.2.1 drops them but needs compileSdk 37). R8 only needs to be told the
# missing class is expected; nothing uses it at runtime.
-dontwarn edu.umd.cs.findbugs.annotations.SuppressFBWarnings

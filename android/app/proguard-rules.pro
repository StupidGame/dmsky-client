# WorkManager 2.9 creates its Room database by reflection during Android startup.
# Keep both database types and their constructors when R8 optimizes release APKs.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

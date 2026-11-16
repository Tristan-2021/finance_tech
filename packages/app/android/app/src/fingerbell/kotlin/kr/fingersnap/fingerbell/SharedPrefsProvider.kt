package kr.fingersnap.fingerbell

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.UriMatcher
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

class SharedPrefsProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        if (uriMatcher.match(uri) != CODE_PREFS) {
            throw IllegalArgumentException("Unknown URI: $uri")
        }
        val ctx = context ?: throw IllegalStateException("Context is null")
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cursor = MatrixCursor(arrayOf(COL_KEY, COL_TYPE, COL_VALUE))
        val all = prefs.all
        val persona = all[KEY_PERSONA] as? String
        if (persona != null) {
            cursor.addRow(arrayOf(KEY_PERSONA, TYPE_STRING, persona))
        }
        for (key in SHARED_BOOL_KEYS) {
            val value = all[key] as? Boolean
            if (value != null) {
                cursor.addRow(arrayOf(key, TYPE_BOOL, value.toString()))
            }
        }
        return cursor
    }

    override fun getType(uri: Uri): String? = when (uriMatcher.match(uri)) {
        CODE_PREFS -> "vnd.android.cursor.dir/vnd.kr.fingersnap.fingerbell.prefs"
        else -> null
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? {
        throw UnsupportedOperationException("Read-only provider")
    }

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int {
        throw UnsupportedOperationException("Read-only provider")
    }

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
        throw UnsupportedOperationException("Read-only provider")
    }

    companion object {
        const val AUTHORITY = "kr.fingersnap.fingerbell.prefs"
        const val PREFS_NAME = "fingerbell_prefs"
        const val COL_KEY = "key"
        const val COL_TYPE = "type"
        const val COL_VALUE = "value"
        const val TYPE_STRING = "string"
        const val TYPE_BOOL = "bool"
        const val KEY_PERSONA = "persona"
        val SHARED_BOOL_KEYS = listOf("largeText", "highContrast", "voice", "sound", "haptics")

        private const val CODE_PREFS = 1
        private val uriMatcher = UriMatcher(UriMatcher.NO_MATCH).apply {
            addURI(AUTHORITY, "prefs", CODE_PREFS)
        }
    }
}

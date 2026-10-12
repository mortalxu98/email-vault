/* Linux system libsqlite3 often lacks SQLITE_ENABLE_SNAPSHOT.
   Provide weak stubs so GRDB can link; unused by Email Vault. */
#pragma once

#include <stddef.h>
#include <stdint.h>

/* Opaque types matching SQLite; only needed for linker. */
struct sqlite3;
struct sqlite3_snapshot;

int sqlite3_snapshot_get(struct sqlite3 *db, const char *zSchema, struct sqlite3_snapshot **ppSnapshot) {
    (void)db; (void)zSchema; (void)ppSnapshot;
    return 1; /* SQLITE_ERROR */
}

int sqlite3_snapshot_open(struct sqlite3 *db, const char *zSchema, struct sqlite3_snapshot *pSnapshot) {
    (void)db; (void)zSchema; (void)pSnapshot;
    return 1;
}

void sqlite3_snapshot_free(struct sqlite3_snapshot *pSnapshot) {
    (void)pSnapshot;
}

int sqlite3_snapshot_cmp(struct sqlite3_snapshot *p1, struct sqlite3_snapshot *p2) {
    (void)p1; (void)p2;
    return 0;
}

int sqlite3_snapshot_recover(struct sqlite3 *db, const char *zDb) {
    (void)db; (void)zDb;
    return 1;
}

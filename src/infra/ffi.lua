local ffi = require("ffi")

ffi.cdef[[
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;

int sqlite3_open(const char *filename, sqlite3 **ppDb);
int sqlite3_close(sqlite3 *db);
int sqlite3_exec(sqlite3 *db, const char *sql, void *callback, void *arg, char **errmsg);
void sqlite3_free(void *pointer);
const char *sqlite3_errmsg(sqlite3 *db);
int sqlite3_extended_errcode(sqlite3 *db);
int sqlite3_busy_timeout(sqlite3 *db, int milliseconds);
int sqlite3_prepare_v2(sqlite3 *db, const char *sql, int bytes, sqlite3_stmt **statement, const char **tail);
int sqlite3_step(sqlite3_stmt *statement);
int sqlite3_finalize(sqlite3_stmt *statement);
int sqlite3_bind_text(sqlite3_stmt *statement, int index, const char *value, int length, void (*destructor)(void *));
int sqlite3_bind_int64(sqlite3_stmt *statement, int index, long long value);
int sqlite3_bind_null(sqlite3_stmt *statement, int index);
int sqlite3_column_count(sqlite3_stmt *statement);
const char *sqlite3_column_name(sqlite3_stmt *statement, int column);
int sqlite3_column_type(sqlite3_stmt *statement, int column);
long long sqlite3_column_int64(sqlite3_stmt *statement, int column);
double sqlite3_column_double(sqlite3_stmt *statement, int column);
const unsigned char *sqlite3_column_text(sqlite3_stmt *statement, int column);
int sqlite3_column_bytes(sqlite3_stmt *statement, int column);
long sqlite3_last_insert_rowid(sqlite3 *db);
int sqlite3_changes(sqlite3 *db);

typedef unsigned int socklen_t;

struct timeval {
  long tv_sec;
  long tv_usec;
};

struct sockaddr {
  unsigned short sa_family;
  char sa_data[14];
};

struct in_addr {
  unsigned int s_addr;
};

struct sockaddr_in {
  unsigned short sin_family;
  unsigned short sin_port;
  struct in_addr sin_addr;
  char sin_zero[8];
};

int socket(int domain, int type, int protocol);
int setsockopt(int socket_fd, int level, int option, const void *value, socklen_t length);
int bind(int socket_fd, const struct sockaddr *address, socklen_t length);
int listen(int socket_fd, int backlog);
int accept(int socket_fd, struct sockaddr *address, socklen_t *length);
long read(int file_descriptor, void *buffer, unsigned long count);
long write(int file_descriptor, const void *buffer, unsigned long count);
int close(int file_descriptor);
unsigned int inet_addr(const char *address);
unsigned short htons(unsigned short hostshort);
int gettimeofday(struct timeval *time, void *timezone);
void (*signal(int signum, void (*handler)(int)))(int);
]]

return {
  ffi = ffi,
  C = ffi.C,
  sqlite = ffi.load("sqlite3"),
}

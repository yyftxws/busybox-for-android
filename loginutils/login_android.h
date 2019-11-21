#ifndef _LOGIN_ANDROID_H_
#define _LOGIN_ANDROID_H_

#ifdef __cplusplus 
extern "C" { 
#endif
#include <termios.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <ctype.h>
#include <sys/stat.h>
#include <utmp.h>

#include "pwd_android.h"
#include "android/selinux/android_selinux.h"

#define FAST_FUNC
#define ALWAYS_INLINE inline
#define UNUSED_PARAM __attribute__ ((__unused__))
#define EXTERNALLY_VISIBLE __attribute__(( visibility("default") ))
#define MAIN_EXTERNALLY_VISIBLE EXTERNALLY_VISIBLE
#define RETURNS_MALLOC __attribute__ ((malloc))
#define NORETURN __attribute__ ((__noreturn__))

#define bb_path_motd_file "/etc/motd"
#define LOGIN_FAIL_DELAY 3

#ifndef SECCLASS_CHR_FILE
#define SECCLASS_CHR_FILE 10
#endif

# define update_utmp(pid, new_type, tty_name, username, hostname) ((void)0)


enum {
	DAEMON_CHDIR_ROOT = 1,
	DAEMON_DEVNULL_STDIO = 2,
	DAEMON_CLOSE_EXTRA_FDS = 4,
	DAEMON_ONLY_SANITIZE = 8, /* internal use */
	DAEMON_DOUBLE_FORK = 16, /* double fork to avoid controlling tty */
};

extern const char *applet_name;
int ndelay_on(int fd) FAST_FUNC;
int ndelay_off(int fd) FAST_FUNC;
int fflush_all(void) FAST_FUNC;
int sanitize_env_if_suid(void) FAST_FUNC;
int ask_and_check_password(const struct passwd *pw) FAST_FUNC;
int tcsetattr_stdin_TCSANOW(const struct termios *tp) FAST_FUNC;
char *safe_strncpy(char *dst, const char *src, size_t size) FAST_FUNC;
char *xmalloc_ttyname(int fd) FAST_FUNC RETURNS_MALLOC;
char *xstrdup(const char *s) FAST_FUNC RETURNS_MALLOC;
char *xasprintf(const char *format, ...) __attribute__ ((format(printf, 1, 2))) FAST_FUNC RETURNS_MALLOC;
void bb_daemonize_or_rexec(int flags, char **argv) FAST_FUNC;
struct passwd* safegetpwnam(const char *name) FAST_FUNC;
extern void bb_perror_msg(const char *s, ...) __attribute__ ((format (printf, 1, 2))) FAST_FUNC;
extern void bb_perror_msg_and_die(const char *s, ...) __attribute__ ((noreturn, format (printf, 1, 2))) FAST_FUNC;
extern void bb_error_msg_and_die(const char *s, ...) __attribute__ ((noreturn, format (printf, 1, 2))) FAST_FUNC;
extern void print_login_prompt(void) FAST_FUNC;
extern off_t bb_copyfd_eof(int fd1, int fd2) FAST_FUNC;
extern uint32_t getopt32(char **argv, const char *applet_opts, ...) FAST_FUNC;
extern char *skip_dev_pfx(const char *tty_name) FAST_FUNC;
extern void bb_do_delay(int seconds) FAST_FUNC;
extern void set_current_security_context(security_context_t sid) FAST_FUNC;
extern void run_shell(const char *shell, int loginshell, const char **args) NORETURN FAST_FUNC;

#ifdef __cplusplus 
}
#endif

extern int set_bootloader_env(const char* name, const char* value);
extern char *get_bootloader_env(const char * name);

#endif
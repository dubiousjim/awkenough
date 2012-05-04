/*
 * Runawk lite version 0.30.0 by Jim Pryor
 *   https://github.com/dubiousjim/awkenough
 * Adapted from Runawk 1.4.0 by Aleksey Cheusov
 *   http://runawk.sourceforge.net/
 * Released under the MIT license; see LICENSE
 * Date: Fri May  4 01:04:30 EDT 2012
 */ 

#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <limits.h>
#include <signal.h>
#include <sys/wait.h>


#ifndef AWK
/* can set AWK to "/bin/busybox" and AWK2 to "awk" */
// #define AWK "/usr/bin/awk"
#define AWK "/usr/local/bin/gawk"
#define AWK2 NULL
#else
#ifndef AWK2
#define AWK2 NULL
#endif
#endif

#ifndef VERSION
#define VERSION "0.30.0"
#endif


static char temp_fn [PATH_MAX] = "/tmp/runawk.XXXXXX";
static int temp_fn_created = 0;


typedef struct {
    size_t size;
    size_t allocated;
    const char **contents;
} array_t;


static struct {
    int argc;
    char ** argv;
    array_t array;
} shebang;


void array_init (array_t * array) {
    array->size      = 0;
    array->allocated = 0;
    array->contents  = NULL;
}

void array_push (array_t * array, const char *item) {
    if (array->allocated == array->size) {
        array->allocated = array->allocated * 4 / 3 + 100;
        array->contents = realloc (array->contents,
                array->allocated * sizeof (*array->contents));
    }
    array->contents [array->size++] = item;
}

void array_pushdup (array_t * array, const char *item) {
    char *dup = (item ? strdup (item) : NULL);
    array_push (array, dup);
}

void array_free (array_t * array) {
    size_t i;
    for (i=0; i < array->size; ++i) {
        if (array->contents [i]) {
            free ((void *) array->contents [i]);
            array->contents [i] = NULL;
        }
    }
    if (array->contents)
        free (array->contents);
    array->contents     = NULL;
    array->size      = 0;
    array->allocated = 0;
}



static void die (int status);

static char *xstrdup (const char *s) {
    char *ret = strdup (s);
    if (!ret) {
        perror ("runawk: strdup(3) failed");
        die (33);
    }
    return ret;
}

/*
static void *xmalloc (size_t size) {
    char *ret = malloc (size);
    if (!ret) {
        perror ("runawk: malloc(3) failed");
        die (33);
    }
    return ret;
}
*/




/* also passes gawk's `--exec file`, and any unrecognized long options without arguments that precede -- */

static void usage (void) {
    puts ("\
Usage:   runawk [OPTIONS] file        [arguments ...]\n\
         runawk [OPTIONS] -e 'script' [arguments...]\n\
         wrapper for " AWK " interpreter\n\
Author:  Jim Pryor <dubiousjim@gmail.com>\n\
Version: " VERSION "\n\
\n\
Options:\n\
               -F sep  assign FS=sep\n\
         -v var=value  assign var=value\n\
   -f|--file file.awk  load awk library files\n\
 -e|--source 'script'  program\n\
              --stdin  process stdin after arguments...\n\
            --version  show version number and exit\n\
               --help  show this message and exit\n\
    ");
}


static void version (void) {
    printf ("runawk %s written by Aleksey Cheusov and Jim Pryor\n", VERSION);
}

static pid_t awk_pid = -1;

static int killing_sig = 0;

static char cwd [PATH_MAX];

static const char *interpreter = AWK;

static int add_stdin = 0;

static array_t new_argv;

static int files = 0;

static int execing = 0;


static void die (int status) {
    if (temp_fn_created)
            unlink (temp_fn);
    if (killing_sig)
        exit (128 + killing_sig);
    else
        exit (status);
}


static void handler (int sig) {
    killing_sig = sig;
    if (awk_pid != -1) {
        kill (awk_pid, sig);
    }
}


static void set_sig_handler (void) {
    static const int sigs [] = {
        SIGINT, SIGQUIT, SIGTERM,
        SIGHUP, SIGPIPE
    };

    struct sigaction sa;
    size_t i;

    sa.sa_handler = handler;
    sigemptyset (&sa.sa_mask);
    sa.sa_flags = 0;
    for (i=0; i < sizeof (sigs)/sizeof (sigs [0]); ++i) {
        int sig = sigs [i];
        sigaction (sig, &sa, NULL);
    }
}

static void add_file (const char *dir, const char *name, int execing) {
    /* add to queue */
    array_pushdup (&new_argv, execing ? "--exec" : "-f");
    array_pushdup (&new_argv, name);
    files = 1;
}


static void add_buffer (const char *buffer, size_t len) {
    int fd = -1;

    if (files == 0) {
        array_pushdup (&new_argv, "--");
        array_pushdup (&new_argv, buffer);
    } else {
        fd = mkstemp (temp_fn);
        temp_fn_created = 1;
        if (fd == -1) {
            perror ("runawk: mkstemp(3) failed");
            die (40);
        }
        if (write (fd, buffer, len) != (ssize_t) len) {
            perror ("runawk: write(2) failed");
            die (40);
        }
        if (close (fd)) {
            perror ("runawk: close(2) failed");
            die (40);
        }
        /* add to queue */
        array_pushdup (&new_argv, "-f");
        array_pushdup (&new_argv, temp_fn);
        files = 1;
    }
}


int main (int argc, char **argv) {
    const char *progname   = NULL;
    const char *script     = NULL;
    int child_status       = 0;
    size_t i;

    array_init (&new_argv);

    set_sig_handler ();

    /* discard runawk's own ARGV[0] */
    --argc, ++argv;

    if (argc == 0) {
        usage ();
        return 30;
    }

    /* cwd */
    if (!getcwd (cwd, sizeof (cwd))) {
        perror ("runawk: getcwd (3) failed");
        die (32);
    }

    array_pushdup (&new_argv, NULL); /* will fill in progname later */

    if (AWK2) {
        array_pushdup (&new_argv, AWK2);
    }

    /* need to parse a run-together shebang line? */
    if (argc >= 2 && argv [0][0] == '-' && argv[1][0] != '-' && strchr(argv[0], ' ')) {
        shebang.argc = --argc;
        shebang.argv = ++argv;
        array_init (&shebang.array);
        char *p;
        char *token = argv[-1];
        for (p = token; *p; ) {
            if (*p == ' ') {
                *p++ = 0;
                array_pushdup(&shebang.array, token);
                token = p;
            } else {
                p++;
            }
        }
        if (p > token) {
            array_pushdup(&shebang.array, token);
        }
        argc = shebang.array.size;
        argv = (char **) shebang.array.contents;
    } else {
        shebang.argc = 0;
    }

    /* parse options manually */
    for (; argc && argv [0][0] == '-'; --argc, ++argv) {

        /* --help */
        if (!strcmp (argv [0], "--help")) {
            usage ();
            die (0);
        }

        /* --version */
        if (!strcmp (argv [0], "--version")) {
            version ();
            die (0);
        }

        /* --stdin */
        if (!strcmp (argv [0], "--stdin")) {
            add_stdin = 1;
            continue;
        }

        /* -F <FS>*/
        if (!strcmp (argv [0], "-F")) {
            if (argc == 1) {
                fprintf (stderr, "runawk: missing argument for -F option\n");
                die (39);
            }
            array_pushdup (&new_argv, "-F");
            array_pushdup (&new_argv, argv [1]);
            --argc;
            ++argv;
            continue;
        }

        /* -F<FS>*/
        if (!strncmp (argv [0], "-F", 2)) {
            array_pushdup (&new_argv, "-F");
            array_pushdup (&new_argv, argv [0]+2);
            continue;
        }

        /* -v|--assign <VAR=VALUE> */
        if (!strcmp (argv [0], "-v") || !strcmp (argv [0], "--assign")) {
            if (argc == 1) {
                fprintf (stderr, "runawk: missing argument for -v option\n");
                die (39);
            }
            array_pushdup (&new_argv, "-v");
            array_pushdup (&new_argv, argv [1]);
            --argc;
            ++argv;
            continue;
        }

        /* -v<VAR=VALUE> */
        if (!strncmp (argv [0], "-v", 2)) {
            array_pushdup (&new_argv, "-v");
            array_pushdup (&new_argv, argv [0]+2);
            continue;
        }

        /* -f|--file <FILE> */
        if (!strcmp (argv [0], "-f") || !strcmp (argv [0], "--file")) {
            if (argc == 1) {
                fprintf (stderr, "runawk: missing argument for -f option\n");
                die (39);
            }
            add_file (cwd, argv [1], 0);
            --argc;
            ++argv;
            continue;
        }

        /* -f<FILE> */
        if (!strncmp (argv [0], "-f", 2)) {
            add_file (cwd, argv [0]+2, 0);
            continue;
        }

        /* -e|--source <PROGRAM TEXT> */
        if (!strcmp (argv [0], "-e") || !strcmp (argv [0], "--source")) {
            if (argc == 1) {
                fprintf (stderr, "runawk: missing argument for -e option\n");
                die (39);
            }
            script = argv [1];
            --argc;
            ++argv;
            continue;
        }

        /* -e<PROGRAM TEXT> */
        if (!strncmp (argv [0], "-e", 2)) {
            script = argv [0]+2;
            continue;
        }

        if (!strcmp (argv [0], "--exec")) {
            if (shebang.argc) {
                if (script) {
                    fprintf (stderr, "runawk: --exec conflicts with --source\n");
                    die (39);
                }
                execing = 1;
                // add_file(cwd, shebang.argv [0], 1);
                // ++shebang.argv;
                // --shebang.argc;
                --argc;
                ++argv;
                break;
            }
            if (argc == 1) {
                fprintf (stderr, "runawk: missing argument for --exec option\n");
                die (39);
            }
            execing = 1;
            // add_file (cwd, argv [1], 1);
            --argc;
            ++argv;
            break;
        }

        /* -- */
        if (!strcmp (argv [0], "--")) {
            --argc;
            ++argv;
            break;
        }

        /* --unknown */
        if (!strncmp (argv [0], "--", 2)) {
            array_pushdup (&new_argv, argv [0]);
            continue;
        }
        
        /* -x etc */
        if (argv[0][1]) {
            fprintf (stderr, "runawk: unknown option -%c\n", *(argv [0]+1));
            die (1);
        }

        /* - */
        break;
    }

    if (shebang.argc) {
        if (argc) {
            fprintf (stderr, "runawk: can't parse shebang line: %s\n", argv[0]);
            die (1);
        }
        array_free (&shebang.array);
        argv = shebang.argv;
        argc = shebang.argc;
    }

    progname = interpreter;

    if (script) {
        add_buffer (script, strlen (script));
    } else {
        /* program_file */
        if (argc < 1) {
            usage ();
            die (30);
        }

        --argc;
        add_file (cwd, *argv, execing);
        progname = *argv;
#if 0
        setprogname (*argv);
        setproctitle (*argv);
#endif
        ++argv;
    }

    /* exec */
    new_argv.contents [0] = xstrdup (progname);

    if (files && !execing)
        array_pushdup (&new_argv, "--");

    for (i=0; i < (size_t) argc; ++i) {
        array_pushdup (&new_argv, argv [i]);
    }

    if (add_stdin) {
        array_pushdup (&new_argv, "/dev/stdin");
    }

    array_pushdup (&new_argv, NULL);

    awk_pid = fork ();
    switch (awk_pid) {
        case -1:
            perror ("runawk: fork(2) failed");
            die (42);
            break;

        case 0:
            /* child */
            execvp (interpreter, (char *const *) new_argv.contents);
            fprintf (stderr, "runawk: running '%s' failed: %s\n", interpreter, strerror (errno));
            exit (1);
            break;

        default:
            /* parent */
            waitpid (-1, &child_status, 0);

            array_free (&new_argv);

            if (killing_sig) {
                die (0);
            } else if (WIFSIGNALED (child_status)) {
                die (128 + WTERMSIG (child_status));
            } else if (WIFEXITED (child_status)) {
                die (WEXITSTATUS (child_status));
            } else {
                die (200);
            }
    }

    die (0);
    return 0; /* this should not happen but fixes gcc warning */
}

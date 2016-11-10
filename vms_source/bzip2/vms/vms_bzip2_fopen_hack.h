#include <stdio.h>
#include <fcntl.h>

FILE *vms_bzip2_fopen(const char *file_spec,
                      const char *a_mode);

int vms_bzip2_open(const char *file_spec, int flags, mode_t mode);


static FILE vms_bzip2_fdopen(int fd, const char * mode) {
    if ((mode[0] == 'w') && (mode[1] == 0)) {
       return fdopen(fd, "wb");
    } else {
       return fdopen(fd, mode);
    }
}

#define fopen vms_bzip2_fopen
#define open vms_bzip2_open
#define fdopen vms_bzip2_fdopen

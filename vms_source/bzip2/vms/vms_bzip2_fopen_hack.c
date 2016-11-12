/* File: vms_bzip2_fopen_hack.c
 *
 * Wrappers for fopen() and open().
 *
 * Much of this code is based on the Steven Schweda port of bzip2 to VMS.
 *
 * It would be nice if there were some benchmark programs to show how
 * much that these changes help performance.
 *
 */

#include <stdio.h>
#include <fcntl.h>

#include <descrip.h>
#include <rms.h>
#include <stsdef.h>
#include <jpidef.h>
#include <efndef.h>

#if __INITIAL_POINTER_SIZE
#pragma pointer_size save
#pragma pointer_size short
#define dsc_descriptor_s dsc64$descriptor_s
#define dsc_length dsc64$q_length
#else
#define dsc_descriptor_s dsc$descriptor_s
#define dsc_length dsc$w_length
#endif

#pragma member_alignment save
#pragma nomember_alignment longword
struct item_list_3 {
        unsigned short len;
        unsigned short code;
        void * bufadr;
        unsigned short * retlen;
};
#pragma member_alignment restore
#if __INITIAL_POINTER_SIZE
#pragma pointer_size restore
#endif

#pragma message save
#pragma message disable noparmlist

int SYS$GETJPIW
       (unsigned long efn,
        pid_t * pid,
        const struct dsc_descriptor_s * procname,
        const struct item_list_3 * itmlst,
        void * iosb,
        void (* astadr)(__unknown_params),
        void * astprm);

#pragma message restore


/* BZIP2 flag for verbosity. */
extern int verbosity;

#define DIAG_FLAG (verbosity >= 2)

#define RMS_DEQ_DEFAULT 16384   /* About 1/4 the max (65535 blocks). */
#define RMS_MBC_DEFAULT 127     /* The max, */
#define RMS_MBF_DEFAULT 2       /* Enough to enable rah and wbh. */



/* VMS info that should not change for this session */
struct rms_info_st {
   int valid;
   unsigned short rms_ext_active;
   char rms_mbc_active;
   unsigned char rms_mbf_active;
   char mbc_str[12];
   char mbf_str[12];
   char deq_str[12];
};

static struct rms_info_st rms_info = {
   -1, RMS_DEQ_DEFAULT, RMS_MBC_DEFAULT, RMS_MBF_DEFAULT
};

static void rms_defaults_init(void) {

    int status;
    unsigned short rms_ext;
    char rms_mbc;
    unsigned char rms_mbf;
    unsigned short rms_ext_len;
    unsigned short rms_mbc_len;
    unsigned short rms_mbf_len;
    unsigned short jpi_iosb[4];
    struct item_list_3 jpi_items[4];

    if (rms_info.valid > 0) {
        return;
    }

    jpi_items[0].len = sizeof rms_ext;
    jpi_items[0].code = JPI$_RMS_EXTEND_SIZE;
    jpi_items[0].bufadr = &rms_ext;
    jpi_items[0].retlen = &rms_ext_len;

    jpi_items[1].len = sizeof rms_mbc;
    jpi_items[1].code = JPI$_RMS_DFMBC;
    jpi_items[1].bufadr = &rms_mbc;
    jpi_items[1].retlen = &rms_mbc_len;

    jpi_items[2].len = sizeof rms_mbf;
    jpi_items[2].code = JPI$_RMS_DFMBFSDK;
    jpi_items[2].bufadr = &rms_mbf;
    jpi_items[2].retlen = &rms_mbf_len;

    jpi_items[3].len = 0;
    jpi_items[3].code = 0;

    status = SYS$GETJPIW(EFN$C_ENF, NULL, NULL, jpi_items, jpi_iosb, NULL, 0);
    if ($VMS_STATUS_SUCCESS(status) && $VMS_STATUS_SUCCESS(jpi_iosb[0])) {

        rms_info.valid = 1;

        /* Default extend quantity.  Use the user value, if set. */
        if (rms_ext > 0) {
            rms_info.rms_ext_active = rms_ext;
        }

        /* Default multi-block count.  Use the user value, if set. */
        if (rms_mbc > 0) {
            rms_info.rms_mbc_active = rms_mbc;
        }

        /* Default multi-buffer count.  Use the user value, if set. */
        if (rms_mbf > 0) {
            rms_info.rms_mbf_active = rms_mbf;
        }
        sprintf(rms_info.deq_str, "deq=%d", rms_info.rms_ext_active);
        sprintf(rms_info.mbc_str, "mbc=%d", rms_info.rms_mbc_active);
        sprintf(rms_info.mbf_str, "mbf=%d", rms_info.rms_mbf_active);
    } else {
        rms_info.valid = -1;
    }

    if (DIAG_FLAG) {
        int sts;
        if ($VMS_STATUS_SUCCESS(status)) {
            sts = jpi_iosb[0];
        } else {
            sts = status;
        }

        fprintf(stderr,
                "Get RMS defaults.  SYS$GETJPIW status = %%x%08x.\n",
                sts);

        if (rms_info.valid > 0) {
            fprintf(stderr, "               " \
                    "Default: deq = %6d, mbc = %3d, mbf = %3d.\n",
                    rms_ext, rms_mbc, rms_mbf);
        }
    }
}


FILE *vms_bzip2_fopen(const char *file_spec,
                              const char *a_mode) {
    rms_defaults_init();
    if (a_mode[0] == 'r') {
        if (rms_info.valid > 1) {
            char mbc_str[10];
            char mbf_str[10];
            sprintf(mbc_str, "mbc=%d", rms_info.rms_mbc_active);
            sprintf(mbf_str, "mbf=%d", rms_info.rms_mbf_active);
            if (rms_info.rms_mbf_active) {
                return fopen(file_spec, a_mode, "ctx=stm",
                             "fab=sqo", "rop=rah",
                             rms_info.mbc_str,
                             rms_info.mbf_str);

            } else {
                return fopen(file_spec, a_mode, "ctx=stm",
                             "fab=sqo",
                             rms_info.mbc_str,
                             rms_info.mbf_str);
            }
       } else {
           return fopen(file_spec, a_mode, "ctx=stm");
       }
    } else {
        return fopen(file_spec, a_mode);
    }
}

int vms_bzip2_open(const char *file_spec, int flags, mode_t mode) {
    int fd;

    rms_defaults_init();
    if (flags & O_CREAT != 0) {
        if (rms_info.valid > 0) {
            if (rms_info.rms_mbf_active) {
                fd =  open(file_spec, flags, mode, "ctx=stm",
                           "fop=sqo,tef", "rop=wbh", rms_info.deq_str);
            } else {
                fd =  open(file_spec, flags, mode, "ctx=stm",
                           "fop=sqo,tef", rms_info.deq_str);
            }
        } else {
            fd =  open(file_spec, flags, mode, "ctx=stm");
        }
    } else {
        fd =  open(file_spec, flags, mode);
    }
    return fd;
}

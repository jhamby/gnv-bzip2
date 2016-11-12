/* File: VMS_BZIP2_WILD.C
 */

#include <stdlib.h>
#include <string.h>

#include <fabdef.h>
#include <namdef.h>
#include <rabdef.h>
#include <xabdef.h>
#include <xabitmdef.h>
#include <rmsdef.h>

#ifdef NAML$C_MAXRSS
#  define FAB_OR_NAML( fab, nam) nam
#  define FAB_OR_NAML_FNA naml$l_long_filename
#  define FAB_OR_NAML_DNA naml$l_long_defname
#  define FAB_OR_NAML_DNS naml$l_long_defname_size
#  define FAB_OR_NAML_FNS naml$l_long_filename_size
#  define CC_RMS_NAM cc$rms_naml
#  define FAB_NAM fab$l_naml
#  define NAM_STRUCT NAML
#  define NAM_ESA naml$l_long_expand
#  define NAM_ESL naml$l_long_expand_size
#  define NAM_ESS naml$l_long_expand_alloc
#  define NAM_FNB naml$l_fnb
#  define NAM_RSA naml$l_long_result
#  define NAM_RSS naml$l_long_result_alloc
#  define NAM_RSL naml$l_long_result_size
#  define NAM_MAXRSS NAML$C_MAXRSS
#else
#  define FAB_OR_NAML( fab, nam) fab
#  define CC_RMS_NAM cc$rms_nam
#  define FAB_NAM fab$l_nam
#  define NAM_STRUCT NAM
#  define NAM_ESA nam$l_esa
#  define NAM_ESL nam$b_esl
#  define NAM_ESS nam$b_ess
#  define NAM_FNB nam$l_fnb
#  define NAM_RSA nam$l_rsa
#  define NAM_RSL nam$b_rsl
#  define NAM_RSS nam$b_rss
#  define NAM_MAXRSS NAM$C_MAXRSS
#endif

int SYS$CLOSE(struct FAB * fab);
int SYS$OPEN(struct FAB * fab);
int SYS$PARSE(struct FAB * fab);
int SYS$PARSE(struct FAB * fab);
int SYS$SEARCH(struct FAB * fab);

/* GETxxI item descriptor structure. */
typedef struct
    {
    short buf_len;
    short itm_cod;
    void *buf;
    int *ret_len;
    } xxi_item_t;


/* 2005-09-26 SMS.
 *
 * vms_wild()
 *
 *    Expand a wild-card file spec.  Exclude directory files.
 *       First, call with real name.
 *       Thereafter, call with NULL arg (until NULL is returned).
 */

char *vms_wild( char *file_spec, int *wild)
{
    /* Static storage for FAB, NAM[L], XAB, and so on. */

    static struct NAM_STRUCT nam;
    static char exp_name[ NAM_MAXRSS+ 1];
    static char res_name[ NAM_MAXRSS+ 1];
    static struct FAB fab;

    /* XAB item descriptor set. */
    static int is_directory;
    static int xab_dir_len;

    static struct
    {
        xxi_item_t xab_dir_itm;
        int term;
    } xab_itm_lst =
     { { 4, XAB$_UCHAR_DIRECTORY, &is_directory, &xab_dir_len },
       0
     };

    static struct XABITM xab_items =
     { XAB$C_ITM, XAB$C_ITMLEN,
#ifndef VAX     /* VAX has a peculiar XABITM structure declaration. */
                                0,
#endif /* ndef VAX */
                                   NULL, &xab_itm_lst, XAB$K_SENSEMODE };

    static int vms_wild_detected;

    int status;
    int unsuitable;

    if (file_spec != NULL)
    {

        /* J. Malmberg - We only want to use explicit wildcards, not implied */
        char * wild_char_ptr;

        /* J. Malmberg - Allow 64 bit pointers */
#if __INITIAL_POINTER_SIZE
#   pragma pointer_size save
#   pragma pointer_size 32

        /* Need to force the file_spec string to be in 32 bit pointer range */
        char *file_spec_int;
#   pragma pointer_size restore
#endif

        vms_wild_detected = 0;          /* Clear wild-card flag. */
        if (wild != NULL)
            *wild = 0;

        /* J. Malmberg - Only explicit wild cards */
        wild_char_ptr = strpbrk(file_spec, "*?");
        if (wild_char_ptr == NULL)
        {
            return NULL;
        }

#if __INITIAL_POINTER_SIZE
        file_spec_int = _strdup32(file_spec);
#else
        file_spec_int = file_spec;
#endif

        /* Set up the FAB and NAM[L] blocks. */

        fab = cc$rms_fab;               /* Initialize FAB. */
        nam = CC_RMS_NAM;               /* Initialize NAM[L]. */

        fab.FAB_NAM = &nam;             /* FAB -> NAM[L] */

        /* FAB items for XAB attribute sensing. */
#if __INITIAL_POINTER_SIZE
#   pragma pointer_size save
#   pragma pointer_size 32
#endif
        fab.fab$l_xab = (void *) &xab_items;
        fab.fab$b_shr = FAB$M_SHRUPD;   /* Play well with others. */
        fab.fab$b_fac = FAB$M_GET;
        fab.fab$v_nam = 1;              /* Use sys$search() results. */

#ifdef NAML$C_MAXRSS

        fab.fab$l_dna = (char *) -1;    /* Using NAML for default name. */
        fab.fab$l_fna = (char *) -1;    /* Using NAML for file name. */

#endif /* def NAML$C_MAXRSS */

        /* Arg wild name and length. */
        FAB_OR_NAML( fab, nam).FAB_OR_NAML_FNA = file_spec_int;
        FAB_OR_NAML( fab, nam).FAB_OR_NAML_FNS = strlen( file_spec);

#define DEF_DEVDIR "SYS$DISK:[]*.*;0"

        /* Default file spec and length. */
        FAB_OR_NAML( fab, nam).FAB_OR_NAML_DNA = DEF_DEVDIR;
        FAB_OR_NAML( fab, nam).FAB_OR_NAML_DNS = sizeof( DEF_DEVDIR)- 1;

        nam.NAM_ESA = exp_name;         /* Expanded name. */
        nam.NAM_ESS = NAM_MAXRSS;       /* Max length. */
        nam.NAM_RSA = res_name;         /* Resulting name. */
        nam.NAM_RSS = NAM_MAXRSS;       /* Max length. */
#if __INITIAL_POINTER_SIZE
#   pragma pointer_size restore
#endif

        /* Parse the file name. */
        status = SYS$PARSE( &fab);

        if (status != RMS$_NORMAL)
        {
            /* Parse failed.
               Return original file spec and let someone else complain.
            */
#if __INITIAL_POINTER_SIZE
            free(file_spec_int);
#endif
            return file_spec;
        }
        /* Set the local wild-card flag. */
        vms_wild_detected = ((nam.NAM_FNB& NAM$M_WILDCARD) != 0);
        if (wild != NULL)
            *wild = vms_wild_detected;
#if __INITIAL_POINTER_SIZE
        free(file_spec_int);
#endif
    }
    else if (vms_wild_detected == 0)
    {
        /* Non-first call with no wild-card in file spec.  Done. */
        return NULL;
    }

    /* Search for the next matching file spec. */
    unsuitable = 1;
    while (unsuitable != 0)
    {
        status = SYS$SEARCH( &fab);

        if (status == RMS$_NORMAL)
        {
            /* Found one.  If suitable, return resultant file spec. */
            status = SYS$OPEN( &fab);

            /* Clear internal file index.
               (Required after sys$open(), for next sys$search().)
            */
            fab.fab$w_ifi = 0;

            if (status == RMS$_NORMAL)
            {
                unsuitable = is_directory;
                status = SYS$CLOSE( &fab);
            }
            else
            {
                /* Open failed.  Let someone else complain. */
                unsuitable = 0;
            }

            if (!unsuitable)
            {
                /* Suitable.  Return the resultant file spec. */
                res_name[ nam.NAM_RSL] = '\0';
                return res_name;
            }
        }
        else if (status == RMS$_NMF)
        {
            /* No more (wild-card) files.  Done. */
            return NULL;
        }
        else
        {
            /* Unexpected search failure.
               Return expanded file spec and let someone else complain.
               Could probably return the original spec instead.
            */
            exp_name[ nam.NAM_ESL] = '\0';
            return exp_name;
        }
    }
}

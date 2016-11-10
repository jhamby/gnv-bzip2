/* File: VMS_BZIP2_REDOT.C
 */

#include <string.h>
#include <unixlib.h>

/* 2010-11-29 SMS.
 *
 * vms_redot()
 *
 *    De-caret-escape a caret-escaped last dot in a file spec.
 */
static void vms_redot_internal( char *file_spec)
{
    char chr;
    char chr_l1;
    int i;

    i = strlen( file_spec)- 1;

    /* Minimum length = 2 for "^.". */
    if (i > 0)
    {
        int j = 0;              /* j < 0 -> done.  j > 0 -> "^." found. */

        /* Loop through characters, right to left, until a directory
         * delimiter or a dot is reached.
         */
        chr_l1 = file_spec[ i];
        while ((i > 0) && (j == 0))
        {
            /* Shift our attention one character to the left. */
            chr = chr_l1;
            chr_l1 = file_spec[ --i];
            switch (chr)
            {
                /* Quit when a directory delimiter is reached. */
                case '/':
                case ']':
                case '>':
                    if (chr_l1 != '^')
                        j = -1;         /* Dir. delim.  (Nothing to do.) */
                    break;
                /* Quit when the right-most dot is reached. */
                case '.':
                    if (chr_l1 != '^')
                        j = -1;         /* Plain dot.  (Nothing to do.) */
                    else
                        j = i;          /* Caret-escaped dot. */
                    break;
            }
        }

        /* If a caret-escaped dot was found, then shift the dot, and
         * everything to its right, one position to the left.
         */
        if (j > 0)
        {
            char *cp = file_spec+ j;
            do
            {
                *cp = *(cp+ 1);
                cp++;
            } while (*cp != '\0');
        }
    }
}

#ifndef __VAX
void vms_redot(char *file_spec) {
    int decc_fn_unix_only;

    /* Do not redot for Filename Unix Only */
    decc_fn_unix_only = decc$feature_get("DECC$FILENAME_UNIX_ONLY",
                                        __FEATURE_MODE_CURVAL);
    if (decc_fn_unix_only) {
        return;
    }
    vms_redot_internal(file_spec);
}
#else
void vms_redot(char *file_spec) {
    vms_redot_internal(file_spec);
}
#endif

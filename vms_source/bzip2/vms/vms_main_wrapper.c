/* File: vms_main_wrapper.c
 *
 * This module provides a wrapper around the main() function of a ported
 * program for two functions:
 *
 * 1. Make sure that the argv[0] string is set as close as possible to
 *    what the original command was given.
 *
 * 2. Make sure that the posix exit is called.
 *
 * Copyright 2012, John Malmberg
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
 * OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

#if __INITIAL_POINTER_SIZE
/* All pointer results should fit in 32 bits */
#pragma message disable maylosedata3
#endif

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

#include <descrip.h>
#include <dvidef.h>
#include <efndef.h>
#include <fscndef.h>
#include <stsdef.h>

#if __INITIAL_POINTER_SIZE
#pragma pointer_size save
#pragma pointer_size short
#endif
#pragma member_alignment save
#pragma nomember_alignment longword
struct item_list_3 {
	unsigned short len;
	unsigned short code;
	void * bufadr;
	unsigned short * retlen;
};

struct filescan_itmlst_2 {
    unsigned short length;
    unsigned short itmcode;
    char * component;
};

#pragma member_alignment restore
#if __INITIAL_POINTER_SIZE
#pragma pointer_size restore
#endif
#pragma member_alignment


#if __INITIAL_POINTER_SIZE
#define dsc_descriptor_s dsc64$descriptor_s
#define dsc_length dsc64$q_length
#else
#define dsc_descriptor_s dsc$descriptor_s
#define dsc_length dsc$w_length
#endif

int SYS$GETDVIW
       (unsigned long efn,
	unsigned short chan,
	const struct dsc_descriptor_s * devnam,
	const struct item_list_3 * itmlst,
	void * iosb,
	void (* astadr)(unsigned long),
	unsigned long astprm,
	void * nullarg);

int SYS$FILESCAN
   (const struct dsc_descriptor_s * srcstr,
    struct filescan_itmlst_2 * valuelist,
    unsigned long * fldflags,
    struct dsc_descriptor_s *auxout,
    unsigned short * retlen);

#ifdef HAVE_VMS_MAIN_ENVP
#define VMS_ENVP ,char **env
#define VMS_ENV , env
#else
#define VMS_ENVP
#define VMS_ENV
#endif
int original_main(int argc, char ** argv VMS_ENVP);

int main(int argc, char ** argv VMS_ENVP) {
int status;
int result;
char arg_nam[256];
char **new_argv;

#ifdef TEST_MAIN
    printf("original argv[0] = %s\n", argv[0]);
#endif

    new_argv = argv;
    result = 0;

    /* If the path name starts with a /, then it is an absolute path	     */
    /* that may have been generated by the CRTL instead of the command name  */
    /* If it is the device name between the slashes, then this was likely    */
    /* from the run command and needs to be fixed up.			     */
    /* If the DECC$POSIX_COMPLIANT_PATHNAMES is set to 2, then it is the     */
    /* DISK$VOLUME that will be present, and it will still need to be fixed. */
    if (argv[0][0] == '/') {
	char * nextslash;
	int length;
	struct item_list_3 itemlist[3];
	unsigned short dvi_iosb[4];
	unsigned short alldevnam_len;
	unsigned short diskvolnam_len;
	struct dsc_descriptor_s devname_dsc;
#if __INITIAL_POINTER_SIZE
#pragma pointer_size save
#pragma pointer_size short
#endif
	char alldevnam[64];
	char diskvolnam[256];
#if __INITIAL_POINTER_SIZE
#pragma pointer_size restore
#endif

	  /* Get some information about the disk */
	/*--------------------------------------*/
	itemlist[0].len = (sizeof alldevnam) - 1;
	itemlist[0].code = DVI$_ALLDEVNAM;
	itemlist[0].bufadr = alldevnam;
	itemlist[0].retlen = &alldevnam_len;
	itemlist[1].len = (sizeof diskvolnam) - 1 - 5;
	itemlist[1].code = DVI$_VOLNAM;
	itemlist[1].bufadr = &diskvolnam[5];
	itemlist[1].retlen = &diskvolnam_len;
	itemlist[2].len = 0;
	itemlist[2].code = 0;

	/* Add the prefix for the volume name. */
	/* SYS$GETDVI will append the volume name to this */
	strcpy(diskvolnam,"DISK$");

	nextslash = strchr(&argv[0][1], '/');
	if (nextslash != NULL) {
	    length = nextslash - argv[0] - 1;

	    /* Cast needed for HP C compiler diagnostic */
#if __INITIAL_POINTER_SIZE
	    devname_dsc.dsc64$w_mbo = 1;
	    devname_dsc.dsc64$l_mbmo = -1;
	    devname_dsc.dsc64$pq_pointer = (char *)&argv[0][1];
	    devname_dsc.dsc64$q_length = length;
	    devname_dsc.dsc64$b_dtype = DSC$K_DTYPE_T;
	    devname_dsc.dsc64$b_class = DSC$K_CLASS_S;
#else
	    devname_dsc.dsc$a_pointer = (char *)&argv[0][1];
	    devname_dsc.dsc$w_length = length;
	    devname_dsc.dsc$b_dtype = DSC$K_DTYPE_T;
	    devname_dsc.dsc$b_class = DSC$K_CLASS_S;
#endif
	    status = SYS$GETDVIW
	       (EFN$C_ENF,
		0,
		&devname_dsc,
		itemlist,
		dvi_iosb,
		NULL, 0, 0);
	    if (!$VMS_STATUS_SUCCESS(status)) {
		/* If the sys$getdviw fails, then this path was passed by */
		/* An exec() program and not from DCL, so do nothing */
		/* An example is "/tmp/program" where tmp: does not exist */
#ifdef TEST_MAIN
		printf("sys$getdviw failed with status %d\n", status);
#endif
		result = 0;
	    } else if (!$VMS_STATUS_SUCCESS(dvi_iosb[0])) {
#ifdef TEST_MAIN
		printf("sys$getdviw failed with iosb %d\n", dvi_iosb[0]);
#endif
		result = 0;
	    } else {
		char * devnam;
		int devnam_len;
		char argv_dev[64];

		/* Null terminate the returned alldevnam */
		alldevnam[alldevnam_len] = 0;
		devnam = alldevnam;
		devnam_len = alldevnam_len;

		/* Need to skip past any leading underscore */
		if (devnam[0] == '_') {
		    devnam++;
		    devnam_len--;
		}

		/* And remove the trailing colon */
		if (devnam[devnam_len - 1] == ':') {
		    devnam_len--;
		    devnam[devnam_len] = 0;
		}

		/* Null terminate the returned volnam */
		diskvolnam_len += 5;
		diskvolnam[diskvolnam_len] = 0;

		/* Check first for normal CRTL behavior */
		if (devnam_len == length) {
		    strncpy(arg_nam, &argv[0][1], length);
		    arg_nam[length] = 0;
		    result = (strcasecmp(devnam, arg_nam) == 0);
		}

		/* If we have not got a match check for POSIX Compliant */
		/* behavior.  To be more accurate, we could also check */
		/* to see if that feature is active. */
		if ((result == 0) && (diskvolnam_len == length)) {
		    strncpy(arg_nam, &argv[0][1], length);
		    arg_nam[length] = 0;
		    result = (strcasecmp(diskvolnam, arg_nam) == 0);
		}
	    }
	}
    } else {
	/* The path did not start with a slash, so it could be VMS format */
	/* If it is vms format, it has a volume/device in it as it must   */
	/* be an absolute path */
	struct dsc_descriptor_s path_desc;
	int status;
	unsigned long field_flags;
	struct filescan_itmlst_2 item_list[5];
	char * volume;
	char * name;
	int name_len;
	char * ext;

#if __INITIAL_POINTER_SIZE
	path_desc.dsc64$w_mbo = 1;
	path_desc.dsc64$l_mbmo = -1;
	path_desc.dsc64$pq_pointer = (char *)argv[0]; /* cast ok */
	path_desc.dsc64$q_length = strlen(argv[0]);
	path_desc.dsc64$b_dtype = DSC$K_DTYPE_T;
	path_desc.dsc64$b_class = DSC$K_CLASS_S;
#else
	path_desc.dsc$a_pointer = (char *)argv[0]; /* cast ok */
	path_desc.dsc$w_length = strlen(argv[0]);
	path_desc.dsc$b_dtype = DSC$K_DTYPE_T;
	path_desc.dsc$b_class = DSC$K_CLASS_S;
#endif

	/* Don't actually need to initialize anything buf itmcode */
	/* I just do not like uninitialized input values */

	/* Sanity check, this must be the same length as input */
	item_list[0].itmcode = FSCN$_FILESPEC;
	item_list[0].length = 0;
	item_list[0].component = NULL;

	/* If the device is present, then it if a VMS spec */
	item_list[1].itmcode = FSCN$_DEVICE;
	item_list[1].length = 0;
	item_list[1].component = NULL;

	/* we need the program name and type */
	item_list[2].itmcode = FSCN$_NAME;
	item_list[2].length = 0;
	item_list[2].component = NULL;

	item_list[3].itmcode = FSCN$_TYPE;
	item_list[3].length = 0;
	item_list[3].component = NULL;

	/* End the list */
	item_list[4].itmcode = 0;
	item_list[4].length = 0;
	item_list[4].component = NULL;

	status = SYS$FILESCAN(
		(const struct dsc_descriptor_s *)&path_desc,
		item_list, &field_flags, NULL, NULL);

	if ($VMS_STATUS_SUCCESS(status) &&
	   (item_list[0].length == path_desc.dsc_length) &&
	   (item_list[1].length != 0)) {

	    char * dollar;
	    int keep_ext;
	    int i;

	    /* We need the filescan to be successful, */
	    /* same length as input, and a volume to be present */

	    /* Need a new argv array */
	    new_argv = malloc((argc + 1) * (sizeof(char *)));
	    new_argv[0] = arg_nam;
	    i = 1;
	    while (i < argc) {
		new_argv[i] = argv[i];
		i++;
	    }

	    /* We will assume that we only get to this path on a version */
	    /* of VMS that does not support the EFS character set */

	    /* There may be a xxx$ prefix on the image name.  Linux */
	    /* programs do not handle that well, so strip the prefix */
	    name = item_list[2].component;
	    name_len = item_list[2].length;
	    dollar = strrchr(name, '$');
	    if (dollar != NULL) {
		dollar++;
		name_len = name_len - (dollar - name);
		name = dollar;
	    }

	    strncpy(arg_nam, name, name_len);
	    arg_nam[name_len] = 0;

	    /* We only keep the extension if it is not ".exe" */
	    keep_ext = 0;
	    ext = item_list[3].component;

	    if (item_list[3].length != 1) {
		if (item_list[3].length != 4) {
		    keep_ext = 1;
		} else {
		    int x;
		    x = strncmp(ext, ".exe", 4);
		    if (x != 0) {
			keep_ext = 1;
		    }
		}
	    }

	    if (keep_ext == 1) {
		strncpy(&arg_nam[name_len], ext, item_list[3].length);
	    }
	}
    }

    if (result) {
	char * lastslash;
	char * dollar;
	char * dotexe;
	char * lastdot;
	char * extension;

	/* This means it is probably the name from a DCL command */
	/* Find the last slash which separates the file from the */
	/* path. */
	lastslash = strrchr(argv[0], '/');

	if (lastslash != NULL) {
	    int i;

	    lastslash++;

	    /* There may be a xxx$ prefix on the image name.  Linux */
	    /* programs do not handle that well, so strip the prefix */
	    dollar = strrchr(lastslash, '$');

	    if (dollar != NULL) {
		dollar++;
		lastslash = dollar;
	    }

	    strcpy(arg_nam, lastslash);

	    /* In UNIX mode + EFS character set, there should not be a */
	    /* version present, as it is not possible when parsing to  */
	    /* tell if it is a version or part of the UNIX filename as */
	    /* UNIX programs use numeric extensions for many reasons.  */

	    lastdot = strrchr(arg_nam, '.');
	    if (lastdot != NULL) {
		int i;

		i = 1;
		while (isdigit(lastdot[i])) {
		    i++;
		}
		if (lastdot[i] == 0) {
		    *lastdot = 0;
		}
	    }

	    /* Find the .exe on the name (case insenstive) and toss it */
	    dotexe = strrchr(arg_nam, '.');
	    if (dotexe != NULL) {
		if ((dotexe[1] == 'e' || dotexe[1] == 'E') &&
		    (dotexe[2] == 'x' || dotexe[2] == 'X') &&
		    (dotexe[3] == 'e' || dotexe[3] == 'E') &&
		    (dotexe[4] == 0)) {

		    *dotexe = 0;
		} else {
		    /* Also need to handle a null extension because of a */
		    /* CRTL bug. */
		    if (dotexe[1] == 0) {
			*dotexe = 0;
		    }
		}
	    }

	    /* Need a new argv array */
	    new_argv = malloc((argc + 1) * (sizeof(char *)));
	    new_argv[0] = arg_nam;
	    i = 1;
	    while (i < argc) {
		new_argv[i] = argv[i];
		i++;
	    }
	    new_argv[i] = 0;

	} else {
	    /* There is no way that the code should ever get here */
	    /* As we already verified that the '/' was present */
	    fprintf(stderr, "Sanity failure somewhere we lost a '/'\n");
	}

    }

    exit(original_main(argc, new_argv VMS_ENV));
    return 1; /* Needed to silence compiler diagnostic */
}

#define main original_main

#ifdef TEST_MAIN

int main(int argc, char ** argv VMS_ENVP) {

    printf("modified argv[0] = %s\n", argv[0]);

    return 0;
}

#endif

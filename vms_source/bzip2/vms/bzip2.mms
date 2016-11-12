# This started as the original Makefile
# with a manual edit to be compatible with MMK and VMS.
# This file has not been tested with MMS.
# It is strongly recommended that you get MMK from the github repository.
# ------------------------------------------------------------------
# This file is part of bzip2/libbzip2, a program and library for
# lossless, block-sorting data compression.
#
# bzip2/libbzip2 version 1.0.6 of 6 September 2010
# Copyright (C) 1996-2010 Julian Seward <jseward@bzip.org>
#
# Please read the WARNING, DISCLAIMER and PATENTS sections in the
# README file.
#
# This program is released under the terms of the license contained
# in the file LICENSE.
# ------------------------------------------------------------------

SHELL=/bin/sh

# To assist in cross-compiling
CC=cc
#AR=ar
RANLIB=ranlib
LDFLAGS=

BIGFILES=-D_FILE_OFFSET_BITS=64
#CFLAGS=-Wall -Winline -O2 -g $(BIGFILES)

crepository = /repo=sys$disk:[.cxx_repository]
cnames = /name=(as_i,shor)$(crepository)
cshow = /show=(EXPA,INC)
clist = /list/mach$(cshow)
cinc2 = /nested=none
cinc = $(cinc2)/include=(sys$disk:[],sys$disk:[.vms])

.ifdef __VAX__
cprefix = /pref=all
cdefs = /def=(_POSIX_EXIT=1)
cdefs_bzr = /def=(_POSIX_EXIT=1)
cfloat =
cptr =
.else
cprefix = /prefix=(all,exce=(strtoimax,strtoumax))
cdefs = /define=(_USE_STD_STAT=1,_POSIX_EXIT=1,_LARGEFILE)
cdefs_bzr = /define=(_USE_STD_STAT=1,_POSIX_EXIT=1,_LARGEFILE,__GNUC__)
cfloat = /float=ieee/ieee_mode=denorm_results
cptr = /pointer_size=long=argv
.endif
cflags32 = $(cnames)/debu$(clist)$(cprefix)$(cwarn)$(cinc)$(cdefs)$(cfloat)
cflags = $(cflags32)$(cptr)
cflags_bzr = \
  $(cnames)/debu$(clist)$(cprefix)$(cwarn)$(cinc)$(cdefs_bzr)$(cfloat)

#
# TPU symbols
#===================

UNIX_2_VMS = /COMM=sys$disk:[.vms]unix_c_to_vms_c.tpu

EVE = EDIT/TPU/SECT=EVE$SECTION/NODISP



# Set up the rules for use.
#===========================================
.SUFFIXES
.SUFFIXES .exe .olb .obj .o32 .c .c_patch .c_vax

.obj.exe
   $(LINK)$(LFLAGS)/NODEBUG/EXE=$(MMS$TARGET)/DSF=$(MMS$TARGET_NAME)\
     /MAP=$(MMS$TARGET_NAME) $(MMS$SOURCE_LIST)

.c.obj
   $(CC)$(CFLAGS)/OBJ=$(MMS$TARGET) $(MMS$SOURCE)

.c_vax.obj
   $(CC)$(CFLAGS)/OBJ=$(MMS$TARGET) $(MMS$SOURCE)

.c.o32
   $(CC)$(CFLAGS)/OBJ=$(MMS$TARGET) $(MMS$SOURCE)


.obj.olb
   @ if f$search("$(MMS$TARGET)") .eqs. "" then \
	librarian/create/object $(MMS$TARGET)
   $ librarian/replace $(MMS$TARGET) $(MMS$SOURCE_LIST)

.o32.olb
   @ if f$search("$(MMS$TARGET)") .eqs. "" then \
	librarian/create/object $(MMS$TARGET)
   $ librarian/replace $(MMS$TARGET) $(MMS$SOURCE_LIST)


# Where you want it installed when you do 'make install'
PREFIX=/usr/local


# Default to 32 bit on VAX and 64 bit on Alpha
OBJS = "blocksort"=sys$disk:[]blocksort.obj  \
       "huffman"=sys$disk:[]huffman.obj    \
       "crctable"=sys$disk:[]crctable.obj  \
       "randtable"=sys$disk:[]randtable.obj  \
       "compress"=sys$disk:[]compress.obj   \
       "decompress"=sys$disk:[]decompress.obj \
       "bzlib"=sys$disk:[]bzlib.obj

.ifndef __VAX__

# Also need 32 bit pointer objects on Alpha
OBJS32 = "bocksort"=sys$disk:[]blocksort.o32  \
         "huffman"=sys$disk:[]huffman.o32    \
         "crctable"=sys$disk:[]crctable.o32   \
         "randtable"=sys$disk:[]randtable.o32  \
         "compress"=sys$disk:[]compress.o32   \
         "decompress"=sys$disk:[]decompress.o32 \
         "bzlib"=sys$disk:[]bzlib.o32

LIBBZ2_SOS = sys$disk:[]gnv$libbz2_32.exe sys$disk:[]gnv$libbz2_64.exe
LIBBZ2_SO = gnv$libbz2_64.exe
LIBBZ2_A = sys$disk:[]libbz2_32.olb sys$disk:[]libbz2_64.olb
LIBBZ2 = libbz2_64
.else
LIBBZ2_SOS = sys$disk:[]gnv$libbz2_32.exe
LIBBZ2_SO = gnv$libbz2_32.exe
LIBBZ2_A = sys$disk:[]libbz2_32.olb
LIBBZ2 = libbz2_32
MACRO32_PATCH = sys$disk:[]macro32_exactcase.exe
.endif


all : $(LIBBZ2_SOS) $(LIBBZ2_A) extra_man \
    sys$disk:[]gnv$bzip2.exe sys$disk:[]gnv$bzip2recover.exe test

sys$disk:[]gnv$bzip2.exe : sys$disk:[]$(LIBBZ2).olb sys$disk:[]bzip2.obj \
          sys$disk:[]vms_bzip2_fopen_hack.obj \
          sys$disk:[]vms_bzip2_redot.obj \
          sys$disk:[]vms_bzip2_wild.obj \
          sys$disk:[]vms_crtl_init.obj
	$(LINK)$(LFLAGS)/EXEC=sys$disk:[]gnv$bzip2.exe sys$disk:[]bzip2.obj, \
          sys$disk:[]vms_bzip2_fopen_hack.obj, \
          sys$disk:[]vms_bzip2_redot.obj, \
          sys$disk:[]vms_bzip2_wild.obj, \
          sys$disk:[]vms_crtl_init.obj, $(LIBBZ2).olb/lib

sys$disk:[]gnv$bzip2recover.exe : sys$disk:[]bzip2recover.obj \
          sys$disk:[]vms_crtl_init.obj
	$(LINK)$(LFLAGS)/EXEC=sys$disk:[]gnv$bzip2recover.exe \
          sys$disk:[]bzip2recover.obj, vms_crtl_init.obj

sys$disk:[]$(LIBBZ2).olb : $(LIBBZ2)($(OBJS))
	@ write sys$output "$(LIBBZ2) is up to date"

.ifndef __VAX__

sys$disk:[]libbz2_32.olb : libbz2_32($(OBJS32))
	@ write sys$output "libbzip2_32 is up to date"

sys$disk:[]$(LIBBZ2_SO) : sys$disk:[]$(LIBBZ2).olb \
	   sys$disk:[.vms]libbz2shr_symbols.opt
	$(LINK)$(LSFLAGS)/share=$(MMS$TARGET)/map=gnv$$(LIBBZ2).map \
	   sys$disk:[]$(LIBBZ2).olb/lib, \
	   sys$disk:[.vms]libbz2shr_symbols.opt/opt
	@ $ write sys$output "$(LIBBZ2_SO) is up to date"

sys$disk:[]gnv$libbz2_32.exe : sys$disk:[]libbz2_32.olb \
	   sys$disk:[.vms]libbz2shr_symbols.opt
	$(LINK)$(LSFLAGS)/share=$(MMS$TARGET)/map=gnv$$(LIBBZ2).map \
	   sys$disk:[]libbz2_32.olb/lib, \
	   sys$disk:[.vms]libbz2shr_symbols.opt/opt
	@ $ write sys$output "gnv$libbz2_32.exe is up to date"

.else

sys$disk:[]$(LIBBZ2_SO) : sys$disk:[]$(LIBBZ2).olb \
	  sys$disk:[]libbz2_xfer.obj sys$disk:[.vms]libbz2_32_xfer.opt
	@ $ write sys$output "Linking $(LIBBZ2) exact+upper shared image"
	$(LINK)$(LSFLAGS)/share=$(MMS$TARGET)/map=gnv$$(LIBBZ2).map -
	  sys$disk:[]$(LIBBZ2).olb/include=bzlib,\
          sys$disk:[]$(LIBBZ2).olb/lib, sys$disk:[.vms]libbz2_32_xfer.opt/opt
	@ $ write sys$output "$(LIBBZ2_SO) is up to date"


$(MACRO32_PATCH) : sys$disk:[.vms]macro32_exactcase.patch
        $ copy sys$system:macro32.exe $(MACRO32_PATCH)
	$ patch @sys$disk:[.vms]macro32_exactcase.patch

sys$disk:[]libbz2_xfer.obj : sys$disk:[.vms]libbz2_xfer.mar_exact \
          $(MACRO32_PATCH)
	define/user macro32 $(MACRO32_PATCH)
	macro/object=$(mms$target) sys$disk:[.vms]libbz2_xfer.mar_exact

.endif

check : test

test : sys$disk:[]gnv$bzip2.exe
        @ $ @sys$disk:[.vms]bzip2_tests.com

extra_man : sys$disk:[]bzcmp.1 sys$disk:[]bzegrep.1 sys$disk:[]bzfgrep.1 \
            sys$disk:[]bzless.1

sys$disk:[]bzcmp.1 :
        create $(MMS$TARGET)/fdl=sys$disk:[.vms]stream_lf.fdl
        open/append mpf $(MMS$TARGET)
        write mpf ".so man1/bzdiff.1"
        close mpf

sys$disk:[]bzegrep.1 :
        create $(MMS$TARGET)/fdl=sys$disk:[.vms]stream_lf.fdl
        open/append mpf $(MMS$TARGET)
        write mpf ".so man1/bzgrep.1"
        close mpf

sys$disk:[]bzfgrep.1 :
        create $(MMS$TARGET)/fdl=sys$disk:[.vms]stream_lf.fdl
        open/append mpf $(MMS$TARGET)
        write mpf ".so man1/bzgrep.1"
        close mpf

sys$disk:[]bzless.1 :
        create $(MMS$TARGET)/fdl=sys$disk:[.vms]stream_lf.fdl
        open/append mpf $(MMS$TARGET)
        write mpf ".so man1/bzmore.1"
        close mpf


install : sys$disk:[]gnv$bzip2.exe sys$disk:[]gnv$bzip2recover.exe
        $ @[.vms]stage_bzip2_install
	# if ( test ! -d $(PREFIX)/bin ) ; then mkdir -p $(PREFIX)/bin ; fi
	# if ( test ! -d $(PREFIX)/lib ) ; then mkdir -p $(PREFIX)/lib ; fi
	# if ( test ! -d $(PREFIX)/man ) ; then mkdir -p $(PREFIX)/man ; fi
	# if ( test ! -d $(PREFIX)/man/man1 ) ; then
        #   mkdir -p $(PREFIX)/man/man1 ; fi
	# if ( test ! -d $(PREFIX)/include ) ; then
        #   mkdir -p $(PREFIX)/include ; fi
	# cp -f bzip2 $(PREFIX)/bin/bzip2
	# cp -f bzip2 $(PREFIX)/bin/bunzip2
	# cp -f bzip2 $(PREFIX)/bin/bzcat
	# cp -f bzip2recover $(PREFIX)/bin/bzip2recover
	# chmod a+x $(PREFIX)/bin/bzip2
	# chmod a+x $(PREFIX)/bin/bunzip2
	# chmod a+x $(PREFIX)/bin/bzcat
	# chmod a+x $(PREFIX)/bin/bzip2recover
	# cp -f bzip2.1 $(PREFIX)/man/man1
	# chmod a+r $(PREFIX)/man/man1/bzip2.1
	# cp -f bzlib.h $(PREFIX)/include
	# chmod a+r $(PREFIX)/include/bzlib.h
	# cp -f libbz2.a $(PREFIX)/lib
	# chmod a+r $(PREFIX)/lib/libbz2.a
	# cp -f bzgrep $(PREFIX)/bin/bzgrep
	# ln -s -f $(PREFIX)/bin/bzgrep $(PREFIX)/bin/bzegrep
	# ln -s -f $(PREFIX)/bin/bzgrep $(PREFIX)/bin/bzfgrep
	# chmod a+x $(PREFIX)/bin/bzgrep
	# cp -f bzmore $(PREFIX)/bin/bzmore
	# ln -s -f $(PREFIX)/bin/bzmore $(PREFIX)/bin/bzless
	# chmod a+x $(PREFIX)/bin/bzmore
	# cp -f bzdiff $(PREFIX)/bin/bzdiff
	# ln -s -f $(PREFIX)/bin/bzdiff $(PREFIX)/bin/bzcmp
	# chmod a+x $(PREFIX)/bin/bzdiff
	# cp -f bzgrep.1 bzmore.1 bzdiff.1 $(PREFIX)/man/man1
	# chmod a+r $(PREFIX)/man/man1/bzgrep.1
	# chmod a+r $(PREFIX)/man/man1/bzmore.1
	# chmod a+r $(PREFIX)/man/man1/bzdiff.1
	# echo ".so man1/bzgrep.1" > $(PREFIX)/man/man1/bzegrep.1
	# echo ".so man1/bzgrep.1" > $(PREFIX)/man/man1/bzfgrep.1
	# echo ".so man1/bzmore.1" > $(PREFIX)/man/man1/bzless.1
	# echo ".so man1/bzdiff.1" > $(PREFIX)/man/man1/bzcmp.1

clean :
        if f$search("*.obj") .nes. "" then delete *.obj;*
        if f$search("*.o32") .nes. "" then delete *.o32;*
        if f$search("libbz2*.olb") .nes. "" then delete libbz2*.olb;*
        if f$search("gnv$bzip2*.exe") .nes. "" then delete gnv$bzip2*.exe;*
        if f$search("gnv$libbz2*.exe") .nes. "" then delete gnv$libbz2*.exe;*
        if f$search("sample%.rb2") .nes. "" then delete sample%.rb2;*
        if f$search("sample%.tst") .nes. "" then delete sample%.tst;*
        if f$search("bzip2%.tmp") .nes. "" then delete bzip2%.tmp;*
        if f$search("bzip2_help.tmp") .nes. "" then delete bzip2_help.tmp;*
        if f$search("bzcmp.1") .nes. "" then delete bzcmp.1;*
        if f$search("bzegrep.1") .nes. "" then delete bzegrep.1;*
        if f$search("bzfgrep.1") .nes. "" then delete bzfgrep.1;*
        if f$search("bzless.1") .nes. "" then delete bzless.1;*
        if f$search("bzip2.c_vax") .nes. "" then delete bzip2.c_vax;*
        if f$search("bzip2.c_patch") .nes. "" then delete bzip2.c_patch;*
        if f$search("*.lis") .nes. "" then delete *.lis;*
        if f$search("*.map") .nes. "" then delete *.map;*
        if f$search("*.bck") .nes. "" then delete *.bck;*
        if f$search("*.jnl") .nes. "" then delete *.jnl;*
        if f$search("*.pcsi$desc") .nes. "" then delete *.pcsi$desc;*
        if f$search("*.pcsi$text") .nes. "" then delete *.pcsi$text;*
        if f$search("*.release_notes") .nes. "" then delete *.release_notes;*
        if f$search("macro32_exactcase.exe") .nes. "" \
            then delete macro32_exactcase.exe;*
        if f$search("[.cxx_repository]*.*") .nes. "" \
            then delete [.cxx_repository]*.*;*
        if f$search("cxx_repository.dir") .nes. "" \
            then set prot=o:rwed cxx_repository.dir;*
        if f$search("cxx_repository.dir") .nes. "" \
            then delete cxx_repository.dir;*
        if f$search("test_bzip2.xml") .nes. "" then delete test_bzip2.xml;*
        if f$search("bzlib_vms_version.h") .nes. "" \
            then delete bzlib_vms_version.h;*
	# rm -f *.o libbz2.a bzip2 bzip2recover \
	# sample1.rb2 sample2.rb2 sample3.rb2 \
	# sample1.tst sample2.tst sample3.tst

sys$disk:[]vms_crtl_init.obj : [.vms]vms_crtl_init.c
	$(CC)$(CFLAGS32)/OBJ=$(MMS$TARGET) $(MMS$SOURCE)

sys$disk:[]blocksort.obj : blocksort.c
	@ $ type words0.
	$(CC)$(CFLAGS)/OBJ=$(MMS$TARGET) $(MMS$SOURCE)

sys$disk:[]blocksort.o32 : blocksort.c
	@ $ type words0.
	$(CC)$(CFLAGS32)/OBJ=$(MMS$TARGET) $(MMS$SOURCE)

sys$disk:[]huffman.obj : huffman.c

sys$disk:[]huffman.o32 : huffman.c

sys$disk:[]crctable.obj : crctable.c

sys$disk:[]crctable.o32 : crctable.c

sys$disk:[]randtable.obj : randtable.c

sys$disk:[]randtable.o32 : randtable.c

sys$disk:[]compress.obj : compress.c

sys$disk:[]compress.o32 : compress.c

sys$disk:[]decompress.obj : decompress.c

sys$disk:[]decompress.o32 : decompress.c

sys$disk:[]bzlib_vms_version.h : sys$disk:[.vms]make_pcsi_bzip2_kit_name.com
        @ $ @sys$disk:[.vms]make_pcsi_bzip2_kit_name.com NOCHECK

.ifndef __VAX__

sys$disk:[]bzlib.obj : bzlib.c sys$disk:[.vms]gnv_bzlib.c_first \
          sys$disk:[]bzlib_vms_version.h
        $(CC)$(CFLAGS)/OBJ=$(MMS$TARGET) $(MMS$SOURCE) \
            /first_include=sys$disk:[.vms]gnv_bzlib.c_first


sys$disk:[]bzlib.o32 : bzlib.c sys$disk:[.vms]gnv_bzlib.c_first \
          sys$disk:[]bzlib_vms_version.h
        $(CC)$(CFLAGS)/OBJ=$(MMS$TARGET) $(MMS$SOURCE) \
            /first_include=sys$disk:[.vms]gnv_bzlib.c_first

.else

sys$disk:[]bzlib.c_vax : bzlib.c sys$disk:[.vms]gnv_bzlib.c_first \
         sys$disk:[]bzlib_vms_version.h
     @ $ type/noheader sys$disk:[.vms]gnv_bzlib.c_first, \
         sys$disk:[]bzlib.c /output=$(MMS$TARGET)

sys$disk:[]bzlib.obj : sys$disk:[]bzlib.c_vax

.endif

sys$disk:[]vms_bzip2_fopen_hack.obj : sys$disk:[.vms]vms_bzip2_fopen_hack.c

sys$disk:[]vms_bzip2_wild.obj : sys$disk:[.vms]vms_bzip2_wild.c

sys$disk:[]vms_bzip2_redot.obj : sys$disk:[.vms]vms_bzip2_redot.c

sys$disk:[]bzip2.c_patch : bzip2.c sys$disk:[.vms]bzip2.tpu
                    $(EVE) $(UNIX_2_VMS) $(MMS$SOURCE)/OUT=$(MMS$TARGET)\
                    /init='f$element(1, ",", "$(MMS$SOURCE_LIST)")'


.ifndef __VAX__
sys$disk:[]bzip2.obj : sys$disk:[]bzip2.c_patch \
          sys$disk:[.vms]gnv_bzip2.c_first \
	  sys$disk:[.vms]vms_bzip2_fopen_hack.h \
          sys$disk:[.vms]vms_main_wrapper.c
        $(CC)$(CFLAGS)/OBJ=$(MMS$TARGET) sys$disk:[]bzip2.c_patch \
            /first_include=sys$disk:[.vms]gnv_bzip2.c_first

.else
sys$disk:[]bzip2.c_vax : sys$disk:[]bzip2.c_patch \
          sys$disk:[.vms]gnv_bzip2.c_first \
	  sys$disk:[.vms]vms_bzip2_fopen_hack.h \
          sys$disk:[.vms]vms_main_wrapper.c
     @ $ type/noheader sys$disk:[.vms]gnv_bzip2.c_first, \
         sys$disk:[]bzip2.c /output=$(MMS$TARGET)

sys$disk:[]bzip2.obj : sys$disk:[]bzip2.c_vax

.endif

.ifndef __VAX__
sys$disk:[]bzip2recover.obj : bzip2recover.c \
          sys$disk:[.vms]vms_main_wrapper.c \
          sys$disk:[.vms]gnv_bzip2recover.c_first
        $(CC)$(CFLAGS_BZR)/OBJ=$(MMS$TARGET) $(MMS$SOURCE) \
           /first_include=sys$disk:[.vms]gnv_bzip2recover.c_first

.else

sys$disk:[]bzip2recover.c_vax : bzip2recover.c \
          sys$disk:[.vms]vms_main_wrapper.c \
          sys$disk:[.vms]gnv_bzip2recover.c_first
        @ $ type/noheader sys$disk:[.vms]gnv_bzip2recover.c_first, \
           sys$disk:[]bzip2recover.c /output=$(MMS$TARGET)


sys$disk:[]bzip2recover.obj : sys$disk:[]bzip2recover.c_vax
        $(CC)$(CFLAGS_BZR)/OBJ=$(MMS$TARGET) $(MMS$SOURCE)
.endif

distclean : clean
	# delete manual.ps;, manual.html;, manual.pdf;

DISTNAME=bzip2-1.0.6

# For rebuilding the manual from sources on my SuSE 9.1 box

MANUAL_SRCS= 	bz-common.xsl bz-fo.xsl bz-html.xsl bzip.css \
		entities.xml manual.xml

manual : manual.html manual.ps manual.pdf

manual.ps : $(MANUAL_SRCS)
	# ./xmlproc.sh -ps manual.xml

manual.pdf : $(MANUAL_SRCS)
	# ./xmlproc.sh -pdf manual.xml

manual.html : $(MANUAL_SRCS)
	# ./xmlproc.sh -html manual.xml

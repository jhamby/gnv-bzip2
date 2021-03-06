$! File: MAKE_PCSI_BZIP2_KIT_NAME.COM
$!
$! Calculates the PCSI kit name for use in building an installation kit.
$! PCSI is HP's PolyCenter Software Installation Utility.
$!
$! The results are stored in as logical names so that other procedures
$! can use them.
$!
$! This procedure also creates a bzlib_vms_version.h file needed to give
$! the VMS build a unique version tag.
$!
$! Copyright 2016, John Malmberg
$!
$! Permission to use, copy, modify, and/or distribute this software for any
$! purpose with or without fee is hereby granted, provided that the above
$! copyright notice and this permission notice appear in all copies.
$!
$! THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
$! WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
$! MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
$! ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
$! WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
$! ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
$! OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
$!
$! 04-Oct-2016  J. Malmberg
$!========================================================================
$!
$! Save default
$ default_dir = f$environment("DEFAULT")
$!
$! Put things back on error.
$ on warning then goto all_exit
$!
$!
$! The producer is the name or common abbreviation for the entity that is
$! making the kit.  It must be set as a logical name before running this
$! procedure.
$!
$! HP documents the producer as the legal owner of the software, but for
$! open source work, it should document who is creating the package for
$! distribution.
$!
$ producer = f$trnlnm("GNV_PCSI_PRODUCER")
$ if producer .eqs. "" .and. p1 .nes. "NOCHECK"
$ then
$   write sys$output "The logical name GNV_PCSI_PRODUCER needs to be defined."
$   write sys$output "This should be set to the common abbreviation or name of"
$   write sys$output "the entity creating this kit.  If you are an individual"
$   write sys$output "then use your initials as long as they do not match"
$   write sys$output "a different well known producer prefix."
$   goto all_exit
$ endif
$ producer_full_name = f$trnlnm("GNV_PCSI_PRODUCER_FULL_NAME")
$ if producer_full_name .eqs. "" .and. p1 .nes. "NOCHECK"
$ then
$   write sys$output "The logical name GNV_PCSI_PRODUCER_FULL_NAME needs to"
$   write sys$output "be defined.  This should be set to the full name of"
$   write sys$output "the entity creating this kit.  If you are an individual"
$   write sys$output "then use your name."
$   write sys$output "EX: DEFINE GNV_PCSI_PRODUCER_FULL_NAME ""First M. Last"""
$   goto all_exit
$ endif
$!
$ if producer .nes. ""
$ then
$   write sys$output "*****"
$   write sys$output "***** Producer = ''producer'"
$   write sys$output "*****"
$ endif
$!
$! Base is one of 'VMS', 'AXPVMS', 'I64VMS', 'VAXVMS' and indicates what
$! binaries are in the kit.  A kit with just 'VMS' can be installed on all
$! architectures.
$!
$ base = "VMS"
$ arch_type = f$getsyi("ARCH_NAME")
$ code = f$extract(0, 1, arch_type)
$ if (code .eqs. "I") then base = "I64VMS"
$ if (code .eqs. "V") then base = "VAXVMS"
$ if (code .eqs. "A") then base = "AXPVMS"
$!
$!
$! We need to get the version from bzlib_private.h.  It will have a lines like
$! #define BZ_VERSION  "1.0.6, 6-Sept-2010"
$!
$
$ update = ""
$ distversion = ""
$ product = "bzip2"
$!
$ open/read/error=version_loop_end verf sys$disk:[]bzlib_private.h
$version_loop:
$   if distversion .nes. "" .and. product .nes. "" then goto version_loop_end
$   read/end=version_loop_end verf line_in
$   if line_in .eqs. "" then goto version_loop
$   line_in_len = f$length(line_in)
$   if f$locate("BZ_VERSION", line_in) .ge. line_in_len then goto version_loop
$   value_line = f$element(1, """", line_in)
$   value = f$element(0, ",", value_line)
$   value_date = f$element(1, ",", value_line)
$   value_date = f$edit(value_date, "trim")
$   distversion = value
$version_loop_end:
$ close verf
$!
$!
$ open/read ef [.vms]vms_eco_level.h
$ecolevel_loop:
$   read/end=ecolevel_loop_end ef line_in
$   prefix = f$element(0, " ", line_in)
$   if prefix .nes. "#define" then goto ecolevel_loop
$   key = f$element(1, " ", line_in)
$   value = f$element(2, " ", line_in) - """" - """"
$   if key .eqs. "VMS_ECO_LEVEL"
$   then
$       ECO_LEVEL = value
$       if ECO_LEVEL .eq. 0
$       then
$           ECO_LEVEL = ""
$       else
$           ECO_LEVEL = "E" + ECO_LEVEL
$       endif
$       goto ecolevel_loop_end
$   endif
$   goto ecolevel_loop
$ecolevel_loop_end:
$ close ef
$!
$!
$ raw_update = f$element(2, ".", distversion)
$ if (raw_update .nes. ".") .and. (raw_update .nes. "")
$ then
$   update = raw_update
$ endif
$ raw_version = distversion
$!
$!
$ ver_tag = producer
$ if ver_tag .eqs. "" then ver_tag = "vms"
$ bzvms_ver_file = "sys$disk:[]bzlib_vms_version.h"
$ if f$search(bzvms_ver_file) .eqs. ""
$ then
$   create 'bzvms_ver_file'
$   open/append bzvver 'bzvms_ver_file'
$   write bzvver "#ifdef BZ_VERSION"
$   write bzvver "#undef BZ_VERSION"
$   write bzvver "#endif"
$   write bzvver -
  "#define BZ_VERSION ""''distversion'''ECO_LEVEL'-''ver_tag', ''value_date'"""
$   close bzvver
$ endif
$!
$!
$! This translates to V0114-08 or D0115-01
$! We can not encode the snapshot date into the version due to the way that
$! the Polycenter Software Installation Utility evaluates the name.
$!
$! version_type = 'V' for a production release, and 'D' for a build from a
$! daiy CVS snapshot.
$ majorver = f$element(0, ".", raw_version)
$ minorver = f$element(1, ".", raw_version)
$ vtype = "V"
$ daily_tag = ""
$!
$!
$ version_fao = "!2ZB!2ZB"
$ mmversion = f$fao(version_fao, 'majorver', 'minorver')
$ version = vtype + "''mmversion'"
$ if update .nes. "" .or. ECO_LEVEL .nes. ""
$ then
$!  The presence of an ECO implies an update
$   if update .eqs. "" .and. ECO_LEVEL .nes. "" then update = "0"
$   version = version + "-" + update + ECO_LEVEL
$   fversion = version
$ else
$   fversion = version
$   version = version + "-"
$ endif
$!
$!
$! Kit type 1 is complete kit, the only type that this procedure will make.
$ kittype = 1
$!
$! Write out a logical name for the resulting base kit name.
$ name = "''producer'-''base'-''product'-''version'-''kittype'"
$ name = f$edit(name, "lowercase")
$ define GNV_PCSI_KITNAME "''name'"
$ fname = "''product'-''fversion'"
$!
$! No ECO or Patch level
$ fname_len = f$length(fname)
$ if f$extract(fname_len - 1, 1, fname) .eqs. "-"
$ then
$    fname = f$extract(0, fname_len - 1, fname)
$    fname_len = fname_len - 1
$ endif
$ if f$extract(fname_len - 1, 1, fname) .eqs. "-"
$ then
$    fname = f$extract(0, fname_len - 1, fname)
$    fname_len = fname_len - 1
$ endif
$ fname = f$edit(fname, "lowercase")
$ define GNV_PCSI_FILENAME_BASE 'fname'
$ write sys$output "*****"
$ write sys$output "***** GNV_PCSI_KITNAME = ''name'."
$ write sys$output "***** GNV_PCSI_FILENAME_BASE = ''fname'."
$ write sys$output "*****"
$!
$all_exit:
$ set def 'default_dir'
$ exit '$status'

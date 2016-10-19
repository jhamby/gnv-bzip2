$! File: build_vms.com
$!
$! Procedure to build bzip2 on VMS.
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
$!
$!
$!=========================================================================
$!
$! Set your project name here
$!
$ product_name = "bzip2"
$!
$ if f$type(bzip2) .eqs. "STRING" then delete/symbol/glo bzip2
$!
$! A cleanup procedure or make/mmk target should always be
$! provided.
$! Edit this to match the project.
$if p1 .eqs. "CLEAN" .or. P1 .eqs. "REALCLEAN"
$then
$  file = "sys$disk:[.vms]clean_''product_name'.com"
$  if f$search(file) .nes. ""
$  then
$      @'file' 'p1'
$  else
$      write sys$output "### ''file' not found for cleanup"
$  endif
$  exit
$endif
$!
$!
$! This should be setup to allow incremental builds so steps
$! should check to see if they are needed to be run.
$!
$!
$ start_time = f$cvtime()
$!
$!
$! Run the prebuild procedure if any
$!----------------------------------
$ file = "sys$disk:[.vms]vms_prebuild.com"
$ if f$search(file) .nes. "" then @'file'
$!
$!
$!
$! Run a build procedure if needed and exists
$! Template looks for MMK first and then to see if a vms_configure.sh
$! has been created.  This will likely need to be customized.
$!---------------------------------------------------------------------
$ if f$search("sys$disk:[...]*.exe") .eqs. ""
$ then
$   mmk_file_template = "sys$disk:[...]''product_name'.mms"
$   mmk_file_full = f$search(mmk_file_template)
$   if mmk_file_full .nes. ""
$   then
$       ! VAX on ODS-2 NFS volume can not find
$       ! the file if the version is present.
$       mmk_file = f$element(0, ";", mmk_file_full)
$       mmk/descript='mmk_file'
$   else
$       configure_vms_template = "sys$disk:[]vms_configure.sh"
$       if f$search(configure_vms_template) .nes. ""
$       then
$!
$           bash ./vms_configure.sh
$!
$!          Configure tends to leave a mess behind.
$!          ---------------------------------------
$           file = "sys$disk:[]conftest.err"
$           if f$search(file) .nes. "" then delete 'file';*
$           file = "sys$disk:[]conftest.lis"
$           if f$search(file) .nes. "" then delete 'file';*
$           file = "sys$disk:[]conftest.dsf"
$           if f$search(file) .nes. "" then delete 'file';*
$           file = "sys$disk:[.conf*]*.*"
$           if f$search(file) .nes. "" then delete 'file';*
$           file = "sys$disk:[]conf*.dir"
$           if f$search(file) .nes. "" then delete 'file';*
$!
$!          Now run the make script
$!          -----------------------
$           bash ./vms_make.sh
$!
$!          You may need to add a cleanup after make
$!          -----------------------------------------
$!
$       else
$           write sys$output "### No build procedure found"
$       endif
$   endif
$ else
$   write sys$output "Binaries already built."
$ endif
$!
$! Add any additional steps here, like procedures to
$! generate documentation files not handled by the build procedure.
$!
$!
$ if f$trnlnm("new_gnu") .eqs. ""
$ then
$   write sys$output "new_gnu: not defined, can not stage"
$   exit
$ endif
$!
$! Need to stage the files in a rooted new_gnu directory
$! This is both for doing additional testing and for setting
$! up for an install.
$! ----------------------------------------------------------
$ write sys$output "Removing previously staged files"
$ @[.vms]stage_'product_name'_install.com remove
$ write sys$output "Staging files to new_gnu:[...]"
$ @[.vms]stage_'product_name'_install.com
$!
$!
$! Now need to sanity check if we can build a PCSI kit.
$! The GNV_PCSI_PRODUCER* logical names are used so that
$! you must set them to make your kit name different
$! from other kits that have been produced.
$ gnv_pcsi_prod = f$trnlnm("GNV_PCSI_PRODUCER")
$ gnv_pcsi_prod_fn = f$trnlnm("GNV_PCSI_PRODUCER_FULL_NAME")
$ stage_root = f$trnlnm("STAGE_ROOT")
$ if (gnv_pcsi_prod .eqs. "") .or. -
     (gnv_pcsi_prod_fn .eqs. "") .or. -
     (stage_root .eqs. "")
$ then
$   if gnv_pcsi_prod .eqs. ""
$   then
$       msg = "GNV_PCSI_PRODUCER not defined, can not build a PCSI kit."
$       write sys$output msg
$   endif
$   if gnv_pcsi_prod_fn .eqs. ""
$   then
$     msg = "GNV_PCSI_PRODUCER_FULL_NAME not defined, can not build a PCSI kit."
$       write sys$output msg
$   endif
$   if stage_root .eqs. ""
$   then
$       write sys$output "STAGE_ROOT not defined, no place to put kits"
$   endif
$   exit
$ endif
$!
$!
$ @[.vms]pcsi_product_'product_name'.com
$!
$exit

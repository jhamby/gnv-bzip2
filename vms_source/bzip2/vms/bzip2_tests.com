$! File: bzip2_tests.com
$!
$! Procedure to test bzip2 on VMS.
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
$!==========================================================================
$!
$ set noon
$ test_count = 0
$ pass_count = 0
$ fail_count = 0
$ skip_count = 0
$ inhibit = %x10000000
$ ss_normal = 1
$ ss_skip = 43
$ ss_abort = 44 + inhibit
$ exit_status = ss_normal
$!
$ arch_type = f$getsyi("ARCH_NAME")
$ arch_name = f$edit(arch_type, "LOWERCASE")
$!
$! Start Junit file
$!-------------------
$ @sys$disk:[.vms]junit_support start test_bzip2
$!
$ write sys$output "Running classic tests from make check"
$! ---------------------------
$ type words1.
$!
$! Test 1
$bzip_1:
$ define/user sys$input sample1.ref
$ define/user sys$output sample1.rb2
$ mcr sys$disk:[]gnv$bzip2 -1  ! < sample1.ref > sample1.rb2
$ call compare_files sample1.bz2 sample1.rb2 test_bzip2 bzip_1 compress
$ severity = '$severity'
$ gosub update_counters
$!
$bzip_2:
$ define/user sys$input sample2.ref
$ define/user sys$output sample2.rb2
$ mcr sys$disk:[]gnv$bzip2 -2  ! < sample2.ref > sample2.rb2
$ call compare_files sample2.bz2 sample2.rb2 test_bzip2 bzip_2 compress
$ severity = '$severity'
$ gosub update_counters
$!
$bzip_3:
$ define/user sys$input sample3.ref
$ define/user sys$output sample3.rb2
$ mcr sys$disk:[]gnv$bzip2 -3  ! < sample3.ref > sample3.rb2
$ call compare_files sample3.bz2 sample3.rb2 test_bzip2 bzip_3 compress
$ severity = '$severity'
$ gosub update_counters
$!
$bunzip_1:
$ define/user sys$input sample1.bz2
$ define/user sys$output sample1.tst
$ mcr sys$disk:[]gnv$bzip2 -d  ! < sample1.bz2 > sample1.tst
$ call compare_files sample1.ref sample1.tst test_bzip2 bunzip_1 decompress
$ severity = '$severity'
$ gosub update_counters
$!
$bunzip_2:
$ define/user sys$input sample2.bz2
$ define/user sys$output sample2.tst
$ mcr sys$disk:[]gnv$bzip2 -d  ! < sample2.bz2 > sample2.tst
$ call compare_files sample2.ref sample2.tst test_bzip2 bunzip_2 decompress
$ severity = '$severity'
$ gosub update_counters
$!
$bunzip_3:
$ define/user sys$input sample3.bz2
$ define/user sys$output sample3.tst
$ mcr sys$disk:[]gnv$bzip2 -d  ! < sample3.bz2 > sample3.tst
$ call compare_files sample3.ref sample3.tst test_bzip2 bunzip_3 decompress
$ severity = '$severity'
$ gosub update_counters
$!
$ type words3.
$!
$ write sys$output ""
$ write sys$output " End of make check tests, start of VMS tests."
$!
$bzip2_help_1:
$ out_file = "bzip2_help.tmp"
$ define/user sys$error 'out_file'
$ mcr sys$disk:[]gnv$bzip2 --help
$ call search_text 'out_file' "usage: bzip2 " -
    test_bzip2 bzip2_help_1 vms
$ severity = $severity
$ gosub update_counters
$ if f$search(out_file) .nes. "" then delete 'out_file';
$!
$bzip2_rcovr_1:
$bzip2_rcovr_2:
$ out_file = "bzip2recover.tmp"
$ define/user sys$error 'out_file'
$ mcr sys$disk:[]gnv$bzip2recover
$!
$ call search_text 'out_file' "usage is `bzip2recover " -
    test_bzip2 bzip2_rcovr_1 vms
$ severity = '$severity'
$ gosub update_counters
$ if arch_name .nes. "vax"
$ then
$   text = "size of recovered file: None"
$ else
$   text = "size of recovered file: 512 MB"
$ endif
$ call search_text 'out_file' "''text'" test_bzip2 bzip2_rcovr_2 vms
$ severity = '$severity'
$ gosub update_counters
$ if f$search(out_file) .nes. "" then delete 'out_file';
$!
$bzip2_environ_1:
$ bzip2 = "--help"
$ out_file = "bzip2_help.tmp"
$ define/user sys$error 'out_file'
$ mcr sys$disk:[]gnv$bzip2 --help
$ call search_text 'out_file' "usage: bzip2 " -
    test_bzip2 bzip2_environ_1 vms
$ severity = $severity
$ gosub update_counters
$ if f$search(out_file) .nes. "" then delete 'out_file';
$!
$bzip_environ_2:
$ bzip2 := $lcl_root:[]gnv$bzip2.exe
$ define/user bzip2 "--help"
$ out_file = "bzip2_help.tmp"
$ define/user sys$error 'out_file'
$ mcr sys$disk:[]gnv$bzip2
$ call search_text 'out_file' "usage: bzip2 " -
    test_bzip2 bzip2_environ_2 vms
$ severity = $severity
$ gosub update_counters
$ if f$search(out_file) .nes. "" then delete 'out_file';
$!
$bzip2_environ_3:
$ bzip2_opts = "--help"
$ out_file = "bzip2_help.tmp"
$ define/user sys$error 'out_file'
$ mcr sys$disk:[]gnv$bzip2
$ call search_text 'out_file' "usage: bzip2 " -
    test_bzip2 bzip2_environ_3 vms
$ severity = $severity
$ gosub update_counters
$ if f$search(out_file) .nes. "" then delete 'out_file';
$!
$!	# need test for bzip/bzip_* environment variables.
$!	# Need test for 32/64 bit shared image link.
$!	# cc /names=(upper,short)/define=(_POSIX_EXIT)-
$!	# /opt=(inline)/pref=all/include=[] [.test]example.c -
$!	# /obj=example_upper.obj
$!
$finish_tests:
$ @sys$disk:[.vms]junit_support finish test_bzip2 'test_count' test_bzip2
$!
$ write sys$output "Total tests = ''test_count'"
$ write sys$output "Pass = ''pass_count'"
$ write sys$output "skip = ''skip_count'"
$ write sys$output "fail = ''fail_count'"
$!
$all_exit:
$ exit 'exit_status'
$!
$!
$update_counters:
$ test_count = test_count + 1
$ if severity .eq. 1
$ then
$   pass_count = pass_count + 1
$ else
$   if severity .eq. 3
$   then
$      skip_count = skip_count + 1
$   else
$      fail_count = fail_count + 1
$      exit_status = ss_abort
$   endif
$ endif
$ return
$!
$!
$search_text: subroutine
$! p1 infile
$! p2 text
$! p3 test_file
$! p4 test_name
$! p5 test_class
$!
$ define/user sys$output nla0:
$ define/user sys$error nla0:
$ search/exact 'p1' "''p2'"
$ severity='$severity'
$ if severity .ne. 1
$ then
$   @sys$disk:[.vms]junit_support fail "''p3'" "''p4'" "''p5'" -
            "Text ''p2' not found in file"
$   exit_status = ss_abort
$ else
$   exit_status = ss_normal
$   @sys$disk:[.vms]junit_support pass "''p3'" "''p4'" "''p5'"
$ endif
$ exit 'exit_status'
$ endsubroutine
$!
$!
$compare_files: subroutine
$!  p1 = oldfile
$!  p2 = newfile
$!  p3 = test_file
$!  p4 = test_name
$!  p5 = test_class
$!
$ if arch_name .nes. "vax"
$ then
$   checksum 'p1'
$   oldsum=checksum$checksum
$   checksum 'p2'
$   if oldsum .nes. checksum$checksum
$   then
$       @sys$disk:[.vms]junit_support fail "''p3'" "''p4'" "''p5'" -
            "Compare of ''p2' failed"
$       show sym oldsum
$       show sym checksum$checksum
$       exit_status = ss_abort
$   else
$       @sys$disk:[.vms]junit_support pass "''p3'" "''p4'" "''p5'"
$       exit_status = ss_normal
$   endif
$ else
$   @sys$disk:[.vms]junit_support skip "''p3'" "''p4'" "''p5'" -
            "currently skipped on VAX"
$   exit_status = ss_skip
$ endif
$ exit 'exit_status'
$ endsubroutine

$! File: junit_support.com
$!
$! Procedure to help create junit files on VMS.
$!
$! Usage:
$!
$!   <name> is the name of the JUnit test file to create/update.
$!   This will create a the result file of sys$disk:[]<name>.xml.
$!
$!   My Jenkins build procedure typically look for "test*.xml" files for
$!   reporting test results.
$!
$!   <test_name> is the name of the test.
$!
$!   <test_class> is the class of test.
$!
$!   <reason> is a string passed to the test to explain the failure
$!   or the skip.
$!
$!   <fail_type> classifies the failure.  Defaults to "failure"
$!
$!   <test_count> is the count of tests that will be attempted.
$!
$! @disk:[.dir]junit_support start <name>
$!
$! @disk:[.dir]junit_support skip <name> <test_name> <test_class> "<reason>"
$!
$! @disk:[.dir]junit_support pass <name> <test_name> <test_class>
$!
$! @disk:[.dir]junit_support fail <name> <test_name> <test_class> -
$!                           "<reason>" [<fail_type>]
$!
$! @disk:[.dir]junit_support finish <name> <count> <suite>
$!
$! This procedure will create the temporary files and attempt to
$! clean them up:
$!
$!    junit_stream_lf.fdl on the VAX platform only.
$!
$!    <name>_body_tmp.xml
$!
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
$!=========================================================================
$!
$ test_file = p2
$ junit_hdr_file = "sys$disk:[]''test_file'.xml"
$ junit_body_file = "sys$disk:[]''test_file'_body_tmp.xml"
$ test_name = p3
$ test_class = p4
$ reason = p5
$ fail_type = p6
$!
$ action = f$edit(p1, "trim,upcase")
$ if action .eqs. "START"
$ then
$   gosub create_junit_test_header
$   exit
$ endif
$!
$ if action .eqs. "FINISH"
$ then
$   junit_count = p3
$   gosub finish_junit_test
$   exit
$ endif
$!
$ if action .eqs. "SKIP"
$ then
$   gosub junit_report_skip
$   exit
$ endif
$!
$ if action .eqs. "PASS"
$ then
$   gosub junit_report_pass
$   exit
$ endif
$!
$ if action .eqs. "FAIL"
$ then
$   if fail_type .eqs. "" then fail_type = "failure"
$   gosub junit_report_fail
$   exit
$ endif
$!
$ write sys$output "Invalid parameters to junit_support.com."
$ exit 44
$!
$!
$create_junit_test_header:
$       temp_fdl = "sys$disk:[]junit_stream_lf.fdl"
$       arch_name = f$edit(f$getsyi("arch_name"),"upcase,trim")
$       arch_code = f$extract(0, 1, arch_name)
$!
$       junit_hdr_file = "sys$disk:[]''test_file'.xml"
$       if f$search(junit_hdr_file) .nes. "" then delete 'junit_hdr_file';*
$!
$       junit_body_file = "sys$disk:[]''test_file'_body_tmp.xml"
$       if f$search(junit_body_file) .nes. "" then delete 'junit_body_file';*
$!!
$       if arch_code .nes. "V"
$       then
$           create 'junit_hdr_file'/fdl="RECORD; FORMAT STREAM_LF;"
$           create 'junit_body_file'/fdl="RECORD; FORMAT STREAM_LF;"
$       else
$           if f$search(temp_fdl) .nes. "" then delete 'temp_fdl';*
$           create 'temp_fdl'
RECORD
        FORMAT          stream_lf
$           continue
$           create 'junit_hdr_file'/fdl='temp_fdl'
$           create 'junit_body_file'/fdl='temp_fdl'
$       endif
$       if f$search(temp_fdl) .nes. "" then delete 'temp_fdl';*
$       return
$!
$finish_junit_test:
$       open/append junit_hdr 'junit_hdr_file'
$       write junit_hdr "<?xml version=""1.0"" encoding=""UTF-8""?>"
$       write junit_hdr "<testsuite name=""''junit_suite'"""
$       write junit_hdr " tests=""''junit_count'"">"
$       close junit_hdr
$       open/append junit 'junit_body_file'
$       write junit "</testsuite>"
$       close junit
$       append 'junit_body_file' 'junit_hdr_file'
$       delete 'junit_body_file';*
$       return
$!
$junit_report_skip:
$       open/append junit 'junit_body_file'
$       write sys$output "Skipping test ''test_name' reason ''reason'."
$       write junit "  <testcase name=""''test_name'"""
$       write junit "   classname=""''test_class'"">"
$       write junit "     <skipped/>"
$       write junit "  </testcase>"
$	close junit
$       return
$!
$junit_report_pass:
$       open/append junit 'junit_body_file'
$       write junit "  <testcase name=""''test_name'"""
$       write junit "   classname=""''test_class'"">"
$       write junit "  </testcase>"
$       close junit
$       return
$!
$junit_report_fail:
$       write sys$output "failing test ''test_name' reason ''reason'."
$       open/append junit 'junit_body_file'
$       write junit "  <testcase name=""''test_name'"""
$       write junit "   classname=""''test_class'"">"
$       write junit -
  "     <failure message=""''reason'"" type=""''fail_type'"" >"
$       write junit "     </failure>"
$       write junit "  </testcase>"
$       close junit
$       return


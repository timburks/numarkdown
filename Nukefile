
;; source files
(set @m_files     (filelist "^objc/.*.m$"))
(set @nu_files 	  (filelist "^nu/.*nu$"))
(set @frameworks  '("Cocoa" "Nu"))

;; framework description
(set @framework 			 "Markdown")
(set @framework_identifier   "nu.programming.markdown")
(set @framework_creator_code "????")
(set @framework_initializer  "MarkdownInit")

(compilation-tasks)
(framework-tasks)

(task "bin/nudown" is
      (SH "gcc objc/nudown.m -o bin/nudown -framework Cocoa -framework Nu"))

(task "test" is
      (SH "nutest test/test_markdown.nu"))

(task "clean" is
      (SH "rm test/SimpleTests/*.html")
      (SH "rm test/MarkdownTests/*.html"))

(task "clobber" => "clean" is
      (system "rm -rf #{@framework_dir}"))

(task "default" => "framework")

(task "install" => "framework" is
      (SH "sudo cp bin/nudown /usr/local/bin/nudown")
      (SH "ditto #{@framework_dir} /Library/Frameworks/#{@framework_dir}"))

;; test_markdown.nu
;;  tests for the Nu Markdown module.
;;
;;  Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.

(load "Markdown")

(class TestMarkdown is NuTestCase
     
     (imethod (id) testSimple is
          (puts "")
          (set tests (filelist "test/SimpleTests/.*\.markdown"))
          (tests each: 
                 (do (testFileName)
                     (puts testFileName)
                     (set input (NSString stringWithContentsOfFile:testFileName encoding:NSUTF8StringEncoding error:nil))
                     (set output (NuMarkdown convert:input))
                     (set goldFileName ((testFileName stringByDeletingPathExtension) stringByAppendingPathExtension:"gold"))
                     (set gold (NSString stringWithContentsOfFile:goldFileName encoding:NSUTF8StringEncoding error:nil))
                     (set outputFileName ((testFileName stringByDeletingPathExtension) stringByAppendingPathExtension:"html"))
                     (output writeToFile:outputFileName atomically:NO encoding:NSUTF8StringEncoding error:nil)
                     (set diff (NSString stringWithShellCommand:"diff '#{goldFileName}' '#{outputFileName}'"))
                     (assert_equal "" diff))))
     
     (imethod (id) testMarkdownTests is       
          (puts "")
          (set tests (filelist "test/MarkdownTests/.*\.markdown"))
          (tests each: 
                 (do (testFileName)
                     (puts testFileName)
                     (set input (NSString stringWithContentsOfFile:testFileName encoding:NSUTF8StringEncoding error:nil))
                     (set output (NuMarkdown convert:input))
                     (set goldFileName ((testFileName stringByDeletingPathExtension) stringByAppendingPathExtension:"gold"))
                     (set gold (NSString stringWithContentsOfFile:goldFileName encoding:NSUTF8StringEncoding error:nil))
                     (set outputFileName ((testFileName stringByDeletingPathExtension) stringByAppendingPathExtension:"html"))
                     (output writeToFile:outputFileName atomically:NO encoding:NSUTF8StringEncoding error:nil)                   
                     (set diff (NSString stringWithShellCommand:"diff '#{goldFileName}' '#{outputFileName}'"))
                     (assert_equal "" diff)))))


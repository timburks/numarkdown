; Nu Markdown
; Copyright (c) 2007 Grayson Hansard
; <http://www.fromconcentratesoftware.com/>
;
; Original Markdown
; Copyright (c) 2004-2006 John Gruber  
; <http://daringfireball.net/projects/markdown/>

(load "Nu:beautify") ; To get the handy `strip` extension to NSString

; New function to do Perl-style regex matching
(function eregex (pattern optionStr)
     (set options 0)
     (if (> (head (tail (optionStr rangeOfString:-"i"))) 0) (set options (+ options 1)))
     (if (> (head (tail (optionStr rangeOfString:-"s"))) 0) (set options (+ options 2)))
     (if (> (head (tail (optionStr rangeOfString:-"x"))) 0) (set options (+ options 4)))
     (if (> (head (tail (optionStr rangeOfString:-"l"))) 0) (set options (+ options 8)))
     (if (> (head (tail (optionStr rangeOfString:-"m"))) 0) (set options (+ options 16)))
     (NuRegex regexWithPattern:pattern options:options))

(class NSString
     ;; Get the last character of a string.
     (imethod (id) lastCharacter is
          (self characterAtIndex:(- (self length) 1)))
     
     (imethod (id) replaceOccurrencesOfString:(id)old withString:(id)new is
          (self replaceOccurrencesOfString:old withString:new options:0 range:(list 0 (self length))))
     
     (imethod (id) chomp is
          (case (self lastCharacter)
                ('\n' (self substringToIndex:(- (self length) 1)))
                (else self)))
     
     ;; Iterate over the characters in a string.
     (imethod (id) each:(id) block is
          (set max (self length))
          (for ((set i 0) (< i max) (set i (+ i 1)))
               (block (self substringWithRange:(list i 1))))))

(function markdown_HashHTMLBlocks (str)
     (set block_tags_a -"p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del")
     (set block_tags_b -"p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math")
     (set str (NSMutableString stringWithString:str))     
     ; First, look for nested blocks, e.g.:
     ; 	<div>
     ; 		<div>
     ; 		tags for inner block must be indented.
     ; 		</div>
     ; 	</div>
     ;
     ; The outermost tags must start at the left margin for this to match, and
     ; the inner nested divs must be indented.
     ; We need to do this before the next, more liberal match, because the next
     ; match will start at the first `<div>` and stop at the first `</div>`.
     (set r (eregex <<-END
		(						# save in $1
			^					# start of line  (with /m)
			<(#{block_tags_a})	# start tag = $2
			\b					# word break
			(.*\n)*?			# any number of lines, minimally matching
			</\2>				# the matching end tag
			[ \t]*				# trailing spaces/tabs
			(?=\n+|\Z)			# followed by a newline or end of document
		)END -"mx"))
     ((r findAllInString:str) each:
      (do (m)
          ($g_html_blocks setObject:(m group) forKey:-"!!#{(m hash)}!!")
          (str replaceOccurrencesOfString:(m group) withString:"\n\n!!#{(m hash)}!!\n\n")))     
     
     (set r (eregex <<-END
		(						# save in $1
			^					# start of line  (with /m)
			<(#{block_tags_b})	# start tag = $2
			\b					# word break
			(.*\n)*?			# any number of lines, minimally matching
			.*</\2>				# the matching end tag
			[ \t]*				# trailing spaces/tabs
			(?=\n+|\Z)	# followed by a newline or end of document
		)END -"mx"))
     ((r findAllInString:str) each:
      (do (m)
          ($g_html_blocks setObject:(m group) forKey:-"!!#{(m hash)}!!")
          (str replaceOccurrencesOfString:(m group) withString:"\n\n!!#{(m hash)}!!\n\n")))
     
     ; Special case just for <hr />. It was easier to make a special case than
     ; to make the other regex more complicated
     (((eregex <<-END
		(?:
			(?<=\n\n)		# Starting after a blank line
			|				# or
			\A\n?			# the beginning of the doc
		)
		(						# save in $1
			[ ]{0,3}
			<(hr)				# start tag = $2
			\b					# word break
			([^<>])*?			# 
			/?>					# the matching end tag
			[ \t]*
			(?=\n{2,}|\Z)		# followed by a blank line or end of document
		)END -"mx") findAllInString:str) each:
      (do (m)		
          ($g_html_blocks setObject:(m group) forKey:-"!!#{(m hash)}!!")
          (str replaceOccurrencesOfString:(m group) withString:"\n\n!!#{(m hash)}!!\n\n")))     
     
     ; Special case for standalone HTML comments
     (((eregex <<-END
		(?:
			(?<=\n\n)		# Starting after a blank line
			|				# or
			\A\n?			# the beginning of the doc
		)
		(						# save in $1
			[ ]{0,3}
			(?s:
				<!
				(--.*?--\s*)+
				>
			)
			[ \t]*
			(?=\n{2,}|\Z)		# followed by a blank line or end of document
		)END -"mx") findAllInString:str) each:(do (m)
       ($g_html_blocks setObject:(m group) forKey:-"!!#{(m hash)}!!")
       (str replaceOccurrencesOfString:(m group) withString:"\n\n!!#{(m hash)}!!\n\n")))  
     str)

(function markdown_EncodeAmpsAndAngles (str)
     (set str ((regex -"&(?!#?[xX]?(?:[0-9a-fA-F]+|\w+);)") replaceWithString:"&amp;" inString:str))
     (set str ((regex -"<(?![a-z/?\$!])") replaceWithString:"&lt;" inString:str))
     str)

(function markdown_StripLinkDefinitions (str)
     (set str (NSMutableString stringWithString:str))
     (((eregex <<-END
		^[ ]{0,3}\[(.+)\]:	# id = $1
		  [ \t]*
		  \n?				# maybe *one* newline
		  [ \t]*
		<?(\S+?)>?			# url = $2
		  [ \t]*
		  \n?				# maybe one newline
		  [ \t]*
		(?:
			(?<=\s)			# lookbehind for whitespace
			["(]
			(.+?)			# title = $3
			[")]
			[ \t]*
		)?	# title is optional
		(?:\n+|\Z)END -"mx") findAllInString:str) each:(do (m)
       ($g_urls setObject:(markdown_EncodeAmpsAndAngles (m groupAtIndex:2)) forKey:(m groupAtIndex:1))
       (if (!= (m groupAtIndex:3) nil)
           ($g_titles setObject:(m groupAtIndex:3) forKey:(m groupAtIndex:1)))
       (str replaceOccurrencesOfString:(m group) withString:-"")))    
     str)

(function markdown_EncodeCode (str)
     (set str ((regex -"&") replaceWithString:-"&amp;" inString:str))
     (set str ((regex -"<") replaceWithString:-"&lt;" inString:str))
     (set str ((regex -">") replaceWithString:-"&gt;" inString:str))     
     (set str ((regex -"\*") replaceWithString:($g_escape_table objectForKey:"*") inString:str))
     (set str ((regex -"_") replaceWithString:($g_escape_table objectForKey:"_") inString:str))
     (set str ((regex -"{") replaceWithString:($g_escape_table objectForKey:"{") inString:str))
     (set str ((regex -"}") replaceWithString:($g_escape_table objectForKey:"}") inString:str))
     (set str ((regex -"\[") replaceWithString:($g_escape_table objectForKey:"[") inString:str))
     (set str ((regex -"\]") replaceWithString:($g_escape_table objectForKey:"]") inString:str))
     (set str ((regex -"\\") replaceWithString:($g_escape_table objectForKey:"\\") inString:str))
     str)

(function markdown_TokenizeHTML (str)
     ;   Parameter:  String containing HTML markup.
     ;   Returns:    Reference to an array of the tokens comprising the input
     ;               string. Each token is either a tag (possibly with nested,
     ;               tags contained therein, such as <a href="<MTFoo>">, or a
     ;               run of text between tags. Each element of the array is a
     ;               two-element array; the first is either 'tag' or 'text';
     ;               the second is the actual value.
     ;
     ;
     ;   Derived from the _tokenize() subroutine from Brad Choate's MTRegex plugin.
     ;       <http://www.bradchoate.com/past/mtregex.php>
     (set len (str length))
     (set $pos 0)
     (set tokens (NSMutableArray array))
     (set depth 6)
     (set nested_tags -"(?:<[a-z/!$](?:[^<>]|(?:<[a-z/!$](?:[^<>]|(?:<[a-z/!$](?:[^<>]|(?:<[a-z/!$](?:[^<>]|(?:<[a-z/!$](?:[^<>]|(?:<[a-z/!$](?:[^<>])*>))*>))*>))*>))*>))*>)")
     (set match (eregex <<-END
		(?s: <! ( -- .*? -- \s* )+ > ) |  # comment
		(?s: <\? .*? \?> ) |              # processing instruction
		#{nested_tags}          
		END -"ix"))
     ((match findAllInString:str) each:
      (do (m)
          (set whole_tag (m groupAtIndex:0))
          (set r (m range))
          (set sec_start (+ (head r) (head (tail r))))
          (set tag_start (- sec_start (whole_tag length)))
          (if (< $pos tag_start)
              (tokens addObject:(list -"text" (str substringWithRange:(list $pos (- tag_start $pos))))))
          (tokens addObject:(list -"tag" (m group)))
          (set $pos sec_start)))
     (if (< $pos len)
         (tokens addObject:(list -"text" (str substringFromIndex:$pos))))     
     (tokens list))

(function markdown_EncodeBackslashEscapes (str)
     (set str (NSMutableString stringWithString:str))
     (str replaceOccurrencesOfString:-"\\" withString:($g_escape_table objectForKey:"\\"))
     (str replaceOccurrencesOfString:-"\`" withString:($g_escape_table objectForKey:-"`"))
     (str replaceOccurrencesOfString:-"\*" withString:($g_escape_table objectForKey:-"*"))
     (str replaceOccurrencesOfString:-"\_" withString:($g_escape_table objectForKey:-"_"))
     (str replaceOccurrencesOfString:-"\{" withString:($g_escape_table objectForKey:-"{"))
     (str replaceOccurrencesOfString:-"\}" withString:($g_escape_table objectForKey:-"}"))
     (str replaceOccurrencesOfString:-"\[" withString:($g_escape_table objectForKey:-"["))
     (str replaceOccurrencesOfString:-"\]" withString:($g_escape_table objectForKey:-"]"))
     (str replaceOccurrencesOfString:-"\(" withString:($g_escape_table objectForKey:-"("))
     (str replaceOccurrencesOfString:-"\)" withString:($g_escape_table objectForKey:-")"))
     (str replaceOccurrencesOfString:-"\>" withString:($g_escape_table objectForKey:-">"))
     (str replaceOccurrencesOfString:-"\#" withString:($g_escape_table objectForKey:-"#"))
     (str replaceOccurrencesOfString:-"\+" withString:($g_escape_table objectForKey:-"+"))
     (str replaceOccurrencesOfString:-"\-" withString:($g_escape_table objectForKey:-"-"))
     (str replaceOccurrencesOfString:-"\." withString:($g_escape_table objectForKey:-"."))
     (str replaceOccurrencesOfString:-"\!" withString:($g_escape_table objectForKey:-"!"))
     str)

(function markdown_EscapeSpecialChars (str)
     (set tokens (markdown_TokenizeHTML str))
     (set ret (NSMutableString string))
     (tokens each:
             (do (token)
                 (set tmp (head (tail token)))
                 (if (== (head token) -"tag")
                     (set tmp ((eregex -"\*" -"gx") replaceWithString:($g_escape_table objectForKey:-"*") inString:tmp))
                     (set tmp ((eregex -"_" -"gx") replaceWithString:($g_escape_table objectForKey:-"_") inString:tmp))
                     (ret appendString:tmp)
                     (else
                          (ret appendString:(markdown_EncodeBackslashEscapes (head (tail token))))))))
     ret)

(function markdown_DoCodeSpans (str)
     (set str (NSMutableString stringWithString:str))
     (((eregex <<-END
		(`+)		# $1 = Opening run of `
		(.+?)		# $2 = The code block
		(?<!`)
		\1			# Matching closer
		(?!`)END -"sx") findAllInString:str) each:
      (do (m)
          (set temp (/^[ \t]*/ replaceWithString:"" inString:(m groupAtIndex:2)))
          (set temp (/[ \t]*$/ replaceWithString:"" inString:temp))
          (str replaceOccurrencesOfString:(m group) withString:-"<code>#{(markdown_EncodeCode temp)}</code>")))
     str)

(function markdown_EncodeItalicsAndBolds (str)
     (set str ((regex -"\*") replaceWithString:($g_escape_table objectForKey:-"*") inString:str))
     (set str ((regex -"_") replaceWithString:($g_escape_table objectForKey:-"_") inString:str))
     str)

(function markdown_EncodeQuotes (str)
     (set str ((regex "\"") replaceWithString:-"&quot;" inString:str))
     str)

(function markdown_DoImages (str)
     (set str (NSMutableString stringWithString:str))	
     ; First, handle reference-style labeled images: ![alt text][id]
     (((eregex <<-END
		(				# wrap whole match in $1
		  !\[
		    (.*?)		# alt text = $2
		  \]

		  [ ]?				# one optional space
		  (?:\n[ ]*)?		# one optional newline followed by spaces

		  \[
		    (.*?)		# id = $3
		  \]

		)END -"xsge") findAllInString:str) each:(do (m)
       (set whole_match (m groupAtIndex:1))
       (set alt_text (m groupAtIndex:2))
       (set link_id (m groupAtIndex:3))
       (set result nil)
       (if (== link_id -"")
           (set link_id alt_text))
       (set alt_text ((regex "\"") replaceWithString:-"&quot;" inString:alt_text))
       (if (!= ($g_urls objectForKey:link_id) nil)
           (set url (markdown_EncodeItalicsAndBolds ($g_urls objectForKey:link_id)))
           (set result "<img src=\"#{url}\" alt=\"#{alt_text}\"")
           (if (!= ($g_titles valueForKey:link_id) nil)
               (then (set title (markdown_EncodeQuotes (markdown_EncodeItalicsAndBolds ($g_titles objectForKey:link_id))))              
                     (set result (result stringByAppendingString:" title=\"#{title}\"")))
               ;; it seems like this else clause should be included
               ;; but it breaks the MarkdownTests regressions
               ;; which I think is a bug in Markdown.pl
               ;;(else (set result (result stringByAppendingString:" title=\"\""))
               )
           (set result (result stringByAppendingString:-" />"))
           (else (set result whole_match)))
       (str replaceOccurrencesOfString:whole_match withString:result)))
     ; Next, handle inline images:  ![alt text](url -"optional title")
     (((eregex <<-END
		(				# wrap whole match in $1
		  !\[
		    (.*?)		# alt text = $2
		  \]
		  \(			# literal paren
		  	[ \t]*
			<?(\S+?)>?	# src url = $3
		  	[ \t]*
			(			# $4
			  (['"])	# quote char = $5
			  (.*?)		# title = $6
			  \5		# matching quote
			  [ \t]*
			)?			# title is optional
		  \)
		)END -"xsge") findAllInString:str) each:(do (m)
       (set whole_match (m groupAtIndex:1))
       (set alt_text (markdown_EncodeQuotes (markdown_EncodeItalicsAndBolds (m groupAtIndex:2))))
       (set url (m groupAtIndex:3))
       (set result "<img src=\"#{url}\" alt=\"#{alt_text}\"")
       (if (!= (m groupAtIndex:6) nil)
           (then (set title (markdown_EncodeQuotes (markdown_EncodeItalicsAndBolds (m groupAtIndex:6))))
                 (set result (result stringByAppendingString:" title=\"#{title}\"")))
           (else (set result (result stringByAppendingString:" title=\"\""))))
       
       (set result (result stringByAppendingString:-" />"))
       (str replaceOccurrencesOfString:whole_match withString:result)))
     str)

(function markdown_DoAnchors (str)
     (set str (NSMutableString stringWithString:str))
     ; First, handle reference-style links: [link text] [id]
     (((eregex <<-END
			(					# wrap whole match in $1
			  \[
			    (#{$g_nested_brackets})	# link text = $2
			  \]

			  [ ]?				# one optional space
			  (?:\n[ ]*)?		# one optional newline followed by spaces

			  \[
			    (.*?)		# id = $3
			  \]
			)END -"xsge") findAllInString:str) each:(do (m)
       (set result nil)
       (set whole_match (m groupAtIndex:1))
       (set link_text (m groupAtIndex:2))
       (set link_id (m groupAtIndex:3))
       (if (== link_id -"") (set link_id link_text))
       (if (!= ($g_urls valueForKey:link_id) nil)
           (set url (markdown_EncodeItalicsAndBolds ($g_urls valueForKey:link_id)))
           (set result "<a href=\"#{url}\"")
           (if (!= ($g_titles valueForKey:link_id) nil)
               (set title (markdown_EncodeQuotes (markdown_EncodeItalicsAndBolds ($g_titles valueForKey:link_id))))
               (set result (result stringByAppendingString:" title=\"#{title}\"")))
           (set result (result stringByAppendingString:-">#{link_text}</a>"))
           (else (set result whole_match)))
       (str replaceOccurrencesOfString:whole_match withString:result)))
     
     ; Next, inline-style links: [link text](url -"optional title")
     (((eregex <<-END
		(				# wrap whole match in $1
		  \[
		    (#{$g_nested_brackets})	# link text = $2
		  \]
		  \(			# literal paren
		  	[ \t]*
			<?(.*?)>?	# href = $3
		  	[ \t]*
			(			# $4
			  (['"])	# quote char = $5
			  (.*?)		# Title = $6
			  \5		# matching quote
			)?			# title is optional
		  \)
		)END -"xsge") findAllInString:str) each:(do (m)
       (set whole_match (m groupAtIndex:1))
       (set link_text (m groupAtIndex:2))
       (set url (markdown_EncodeItalicsAndBolds (m groupAtIndex:3)))
       (set title (m groupAtIndex:6))
       (set result "<a href=\"#{url}\"")
       (if (!= title nil)
           (set title (markdown_EncodeQuotes (markdown_EncodeItalicsAndBolds (title))))
           (set result (result stringByAppendingString:" title=\"#{title}\"")))
       (set result (result stringByAppendingString:-">#{link_text}</a>"))
       (str replaceOccurrencesOfString:whole_match withString:result)))
     str)

(function markdown_UnescapeSpecialChars (str)
     (set str (NSMutableString stringWithString:str))
     (($g_escape_table allKeys) each:
      (do (char)
          (set hash ($g_escape_table valueForKey:char))
          (str replaceOccurrencesOfString:hash withString:char)))
     str)

(function markdown_DoAutoLinks (str)
     (set str ((regex "<((https?|ftp):[^'\">\\s]+)>") replaceWithString:"<a href=\"$1\">$1</a>" inString:str))
     (set str ((regex -"<(?:mailto:)?([-.\w]+\@[-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+)>") replaceWithString:(markdown_UnescapeSpecialChars -"$1") inString:str))
     ; This does not encode email addresses!
     str)

(function markdown_DoItalicsAndBold (str)
     ; <strong> must go first:
     (set str ((regex -"(\*\*|__)(?=\S)(.+[*_]*)(?<=\S)\1") replaceWithString:-"<strong>$2</strong>" inString:str))
     (set str ((regex -"(\*|_)(?=\S)(.+?)(?<=\S)\1") replaceWithString:-"<em>$2</em>" inString:str))
     str)

(function markdown_RunSpanGamut (str)
     (set str (markdown_DoCodeSpans str))
     (set str (markdown_EscapeSpecialChars str))
     (set str (markdown_DoImages str))
     (set str (markdown_DoAnchors str))
     (set str (markdown_DoAutoLinks str))
     (set str (markdown_EncodeAmpsAndAngles str))
     (set str (markdown_DoItalicsAndBold str))
     (set str ((regex -" {2,n}\n") replaceWithString:"<br />\n" inString:str))
     str)

(function markdown_DoHeaders (str)
     (set str (NSMutableString stringWithString:str))
     ; Setext-style headers:
     ;	  Header 1
     ;	  ========
     ;  
     ;	  Header 2
     ;	  --------     
     (((eregex -"^(.+)[ \t]*\n=+[ \t]*\n+" -"mx") findAllInString:str) each:
      (do (m) ; Note the multi-line hack below.  -"\n\n" is not turned into new lines.
          (str replaceOccurrencesOfString:(m group) withString:"<h1>#{(markdown_RunSpanGamut (m groupAtIndex:1))}</h1>\n\n")))
     (((eregex -"^(.+)[ \t]*\n-+[ \t]*\n+" -"mx") findAllInString:str) each:
      (do (m)
          (str replaceOccurrencesOfString:(m group) withString:"<h2>#{(markdown_RunSpanGamut (m groupAtIndex:1))}</h2>\n\n")))
     
     ; atx-style headers:
     ;	# Header 1
     ;	## Header 2
     ;	## Header 2 with closing hashes ##
     ;	...
     ;	###### Header 6
     (set hack -"\#") ; Having a literal -"#" in the string makes Nu think that it should be evaluating something.
     (((eregex <<-END
		^(#{hack}{1,6})	# $1 = string of #'s
		[ \t]*
		(.+?)			# $2 = Header text
		[ \t]*
		\#*				# optional closing #'s (not counted)
		\n+END -"mx") findAllInString:str) each:(do (m)
       (str replaceOccurrencesOfString:(m group) 
            withString:"<h#{((m groupAtIndex:1) length)}>#{(markdown_RunSpanGamut (m groupAtIndex:2))}</h#{((m groupAtIndex:1) length)}>\n\n"
            )))
     str)

(function markdown_Outdent (item)
     (/^(\t|[ ]{1,4})/m replaceWithString:"" inString:item))

(function markdown_ProcessListItems (list_str marker_any)
     (set $g_list_level (+ $g_list_level 1))
     (set list_str (NSMutableString stringWithString:list_str))
     (set list_str ((regex -"\n{2,}\z") replaceWithString:"\n" inString:list_str))
     (((eregex <<-END
		(\n)?							# leading line = $1
		(^[ \t]*)						# leading whitespace = $2
		(#{marker_any}) [ \t]+			# list marker = $3
		((?s:.+?)						# list item text   = $4
		(\n{1,2}))
		(?= \n* (\z | \2 (#{marker_any}) [ \t]+))END -"mx") findAllInString:list_str) each:
      (do (m)
          (set item (m groupAtIndex:4))
          (set leading_line (m groupAtIndex:1))
          (set leading_space (m groupAtIndex:2))
          
          (if (or leading_line ((regex -"\n{2,}") findInString:item)) 
              (then (set item (markdown_RunBlockGamut (markdown_Outdent item))))
              (else (set item (markdown_RunSpanGamut ((markdown_DoLists (markdown_Outdent item)) chomp)))))
          (list_str replaceOccurrencesOfString:(m group) withString:"<li>#{item}</li>\n" options:0 range:(list 0 (list_str length)))))
     (set $g_list_level (- $g_list_level 1))
     list_str)

(function markdown_DoLists (str)
     (set marker_ul -"[*+-]")
     (set marker_ol -"\d+[.]")
     (set marker_any -"(?:#{marker_ul}|#{marker_ol})")
     (set whole_list -"(([ ]{0,3}(#{marker_any})[ \t]+)(?s:.+?)(\z|\n{2,}(?=\S)(?![ \t]*#{marker_any}[ \t]+)))")
     (set result str) ;; default
     (if (> $g_list_level 0)
         (then (((eregex -"^#{whole_list}" -"mx") findAllInString:str) each:
                (do (m)
                    (set m_list (m groupAtIndex:1))
                    (if ((regex marker_ul) findInString:(m groupAtIndex:3)) (then (set list_type -"ul")) (else (set list_type -"ol")))
                    ; Turn double returns into triple returns, so that we can make a
                    ; paragraph for the last item in a list, if necessary:
                    (set m_list ((regex -"\n{2,}") replaceWithString:"\n\n\n" inString:m_list))
                    (set formattedList (markdown_ProcessListItems m_list marker_any))
                    (set formattedList "<#{list_type}>\n#{formattedList}</#{list_type}>\n")
                    (result replaceOccurrencesOfString:(m group) withString:formattedList options:0 range:(list 0 (result length))))))
         (else 
               (((eregex -"(?:(?<=\n\n)|\A\n?)#{whole_list}" -"mx") findAllInString:str) each:
                (do (m)
                    (set m_list (m groupAtIndex:1))
                    (if ((regex marker_ul) findInString:(m groupAtIndex:3)) (then (set list_type -"ul")) (else (set list_type -"ol")))
                    ; Turn double returns into triple returns, so that we can make a
                    ; paragraph for the last item in a list, if necessary:
                    (set m_list ((regex -"\n{2,}") replaceWithString:"\n\n\n" inString:m_list))
                    (set formattedList (markdown_ProcessListItems m_list marker_any))
                    (set formattedList "<#{list_type}>\n#{formattedList}</#{list_type}>\n")
                    (result replaceOccurrencesOfString:(m group) withString:formattedList options:0 range:(list 0 (result length)))))
               ))
     result)

(function markdown_Detab (str)
     ((/(.*?)\t/ findAllInString:str) each: 
      (do (m)
          (str replaceOccurrencesOfString:(m group) 
               withString:"#{(m groupAtIndex:1)}#{(NSString spaces:(- 4 (NuMath integerMod:((m groupAtIndex:1) length) by:4)))}")))
     str)

(function markdown_DoCodeBlocks (str)
     (set str (NSMutableString stringWithString:str))
     (((eregex <<-END
		(?:\n\n|\A)
		(	            # $1 = the code block -- one or more lines, starting with a space/tab
		  (?:
		    (?:[ ]{4} | \t)  # Lines must start with a tab or a tab-width of spaces
		    .*\n+
		  )+
		)
		((?=^[ ]{0,4}\S)|\Z)	# Lookahead for non-space at line-start, or end of doc
		END -"mx") findAllInString:str) each:
      (do (m)
          (set codeblock (m groupAtIndex:1))
          (set codeblock (markdown_Detab (markdown_EncodeCode (markdown_Outdent codeblock))))
          (set codeblock ((regex -"(\A\n+)|(\s+\z)") replaceWithString:-"" inString:codeblock))
          (str replaceOccurrencesOfString:(m group) withString:"\n<pre><code>#{codeblock}\n</code></pre>\n\n")))
     str)

(function markdown_DoBlockQuotes (str)
     (set str (NSMutableString stringWithString:str))
     ((/(								# Wrap whole match in $1
			(
			  ^[ \t]*>[ \t]?			# '>' at the start of a line
			    .+\n					# rest of the first line
			  (.+\n)*					# subsequent consecutive lines
			  \n*						# blanks
			)+
		)/mx findAllInString:str) each:
      (do (m)
          (set bq (m groupAtIndex:1))
          (set bq (/^[ \t]*>[ \t]?/m replaceWithString:"" inString:bq)) ;; trim one level of quoting
          (set bq (/^[ \t]+$/m replaceWithString:"" inString:bq))       ;; trim whitespace-only lines
          (set bq (markdown_RunBlockGamut bq))
          (set bq (/^/m replaceWithString:"  " inString:bq))
          ; These leading spaces screw with <pre> content, so we need to fix that:
          (((eregex -"(\s*<pre>.+?</pre>)" -"egsx") findAllInString:bq) each:
           (do (m2) 
               (bq replaceOccurrencesOfString:(m2 group) withString:((eregex -"^  " -"mg") replaceWithString:-"" inString:(m2 groupAtIndex:1)))))
          (str replaceOccurrencesOfString:(m group) withString:"<blockquote>\n#{bq}\n</blockquote>\n\n")))
     str)

(function markdown_FormParagraphs (str)
     (set str (/(\A\n+)|(\n+\z)/ replaceWithString:"" inString:str))
     (set paragraphs (/\n{2,}/ splitString:str))     
     ; Wrap <p> tags
     (set paragraphs (paragraphs map:(do (paragraph)
                                         (unless ($g_html_blocks valueForKey:paragraph)
                                                 
                                                 (set paragraph (/^([ \t]*)/ replaceWithString:"<p>" inString:(markdown_RunSpanGamut paragraph)))
                                                 (paragraph appendString:"</p>"))
                                         paragraph)))     
     ; Unhashify HTML blocks
     (set paragraphs (paragraphs map:(do (paragraph)
                                         (if ($g_html_blocks valueForKey:paragraph) (set paragraph ($g_html_blocks valueForKey:paragraph)))
                                         paragraph)))
     (paragraphs componentsJoinedByString:"\n\n"))

(function markdown_RunBlockGamut (str)
     (set str (markdown_DoHeaders str))
     (set str (/^[ ]{0,2}([ ]?(\*| [-_])[ ]?){3,}[ \t]*$/mx replaceWithString:"\n<hr />\n" inString:str))
     (set str (markdown_DoLists str))
     (set str (markdown_DoCodeBlocks str))
     (set str (markdown_DoBlockQuotes str))     
     ; We already ran _HashHTMLBlocks() before, in Markdown(), but that
     ; was to escape raw HTML in the original Markdown source. This time,
     ; we're escaping the markup we've just created, so that we don't wrap
     ; <p> tags around block-level tags.
     (set str (markdown_HashHTMLBlocks str))
     (set str (markdown_FormParagraphs str))
     str)

(function Markdown (str)
     (set $g_urls (NSMutableDictionary dictionary))
     (set $g_titles (NSMutableDictionary dictionary))
     (set $g_html_blocks (NSMutableDictionary dictionary))
     (set $g_escape_table (NSMutableDictionary dictionary))
     (-"\`*_{}[]()>#+-.!" each: (do (c) ($g_escape_table setObject:"!!#{(c hash)}!!" forKey:c)))
     
     (set $g_nested_brackets -"(?>[^\[\]]+|\[(?>[^\[\]]+|\[(?>[^\[\]]+|\[(?>[^\[\]]+|\[(?>[^\[\]]+|\[(?>[^\[\]]+|\[\])*\])*\])*\])*\])*\])*") 
     ;; From running from Markdown.php
     (set $g_list_level 0)
     
     ;; Standardize line endings
     (set str (/\r\n/ replaceWithString:"\n" inString:str)) ; Convert DOS to Unix
     (set str (/\r/ replaceWithString:"\n" inString:str)) ; Convert Mac to Unix
     ;; Make sure text ends with a couple of newlines
     (str appendString:"\n\n") 
     ;; Convert tabs into 4 spaces
     (set str (markdown_Detab str))
     ;; Strip any lines consisting only of spaces and tabs.
     (set str (/^[ \t]+$/m replaceWithString:"" inString:str)) 
     ;; Turn block-level HTML blocks into hash entries
     (set str (markdown_HashHTMLBlocks str))       
     ;; Strip link definitions, store in hashes.
     (set str (markdown_StripLinkDefinitions str)) 
     
     (set str (markdown_RunBlockGamut str))
     
     (set str (markdown_UnescapeSpecialChars str))
     
     (str appendCharacter:'\n')
     str)

(class NuMarkdown is NSObject
     (cmethod (id) convert:(id) text is (Markdown text)))
